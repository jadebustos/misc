#!/usr/bin/bash

# Copyright 2026 (c) José Ángel de Bustos Pérez 
#   Author: José Ángel de Bustos Pérez <abustosp@redhat.com>
#
# This script is free software: you can redistribute it and/or modify it under the terms of 
# the GNU General Public License v3 as published by the Free Software Foundation.
# This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
# See the GNU General Public License v3 for more details.

# You should have received a copy of the GNU General Public License v3 along with the IdM workshop. 
# If not, see https://www.gnu.org/licenses/gpl-3.0.en.html.

#
# Back up KVM / libvirt virtual machines into a destination directory:
#
#   <dest>/qcow2/  Disk images copied preserving the source directory
#                  structure. qcow2 images are rewritten with
#                  `qemu-img convert -f qcow2 -O qcow2`; anything else is
#                  copied verbatim.
#   <dest>/kvm/    `virsh dumpxml` for every domain and `virsh net-dumpxml`
#                  for every virtual network.
#   <dest>/isos/   Contents of /opt/isos synchronized with rsync.
#
# Usage:
#   kvm-backup.sh -o|--output DEST_DIR [-i|--input VM_DIR]
#
#   -i, --input  VM_DIR   Directory holding the VM disk images.
#                         Optional; defaults to /var/lib/libvirt/images.
#   -o, --output DEST_DIR Destination directory for the backup (required).
#
# Examples:
#   kvm-backup.sh -o /backup/kvm-$(date +%F)
#   kvm-backup.sh -i /var/lib/libvirt/images -o /mnt/backup
#
# Notes:
#   * Run as root (or a user with full libvirt + image access) so that every
#     system VM, network and image is visible.
#   * For a consistent copy, shut down / pause the VMs first: running
#     `qemu-img convert` against a live, changing disk can yield an
#     inconsistent image.

set -uo pipefail

# 
# Configuration
# 
DEFAULT_VM_DIR="/var/lib/libvirt/images"
ISO_SRC="/opt/isos"

# Time when the backup starts.
START_EPOCH="$(date +%s)"
RUN_DATE="$(date '+%F')"          # YYYY-MM-DD, also the manifest filename date
START_TIME="$(date '+%F %T')"     # YYYY-MM-DD HH:MM:SS

WARNINGS=0

#
# Helpers
# 
LOGFILE=""    # set to <dest>/backup-vms.log once the output directory exists

# Append a line to the log file.
_record() { [[ -n "$LOGFILE" ]] && printf '%s\n' "$1" >> "$LOGFILE" 2>/dev/null; return 0; }

log()  { local m; m="$(date '+%F %T')  $*";          printf '%s\n' "$m";     _record "$m"; }
warn() { local m; m="$(date '+%F %T')  WARNING: $*"; printf '%s\n' "$m" >&2; _record "$m"; WARNINGS=$((WARNINGS + 1)); }
die()  { local m; m="$(date '+%F %T')  ERROR: $*";   printf '%s\n' "$m" >&2; _record "$m"; exit 1; }

# Map a VM disk's source path to its location at <dest>/qcow2/:
#   * under the input dir -> mirror the path relative to the input dir
#   * anywhere else       -> mirror the full absolute path 
disk_output_path() {
    local src=$1 rel
    rel="${src#"$VM_DIR"/}"
    if [[ "$rel" != "$src" ]]; then
        printf '%s/%s' "$QCOW2_DIR" "$rel"
    else
        printf '%s/%s' "$QCOW2_DIR" "${src#/}"
    fi
}

# Get "target<TAB>source" for every qcow2 disk of a domain, taken from the VM definition (virsh).
vm_qcow2_disks() {
    local vm=$1 tgt src fmt
    while IFS=$'\t' read -r tgt src; do
        [[ -n "$src" && "$src" != "-" ]] || continue
        fmt="$(qemu-img info "$src" 2>/dev/null \
                | awk -F': ' '/^file format:/ {print $2; exit}')"
        [[ "$fmt" == "qcow2" ]] || continue
        printf '%s\t%s\n' "$tgt" "$src"
    done < <(virsh domblklist "$vm" --details 2>/dev/null \
                | awk 'NR>2 && $2=="disk" { t=$3; $1=$2=$3=""; sub(/^ +/,""); print t "\t" $0 }')
}

usage() {
    cat <<EOF
Usage: ${0##*/} -o|--output DEST_DIR [-i|--input VM_DIR]

  -i, --input  VM_DIR    Directory where the VM disk images are stored.
                         Optional; defaults to: $DEFAULT_VM_DIR
  -o, --output DEST_DIR  Destination directory for the backup (required).
  -h, --help             Show this help and exit.

The destination will contain:
  qcow2/  disk images (qcow2 rewritten with qemu-img convert)
  kvm/    VM and virtual-network XML definitions
  isos/   contents of $ISO_SRC (rsync)
EOF
}

# 
# Parse arguments
#   -i / --input   optional, defaults to $DEFAULT_VM_DIR
#   -o / --output  mandatory
# 
VM_DIR="$DEFAULT_VM_DIR"
DEST=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input)
            [[ $# -ge 2 ]] || die "Option $1 requires an argument."
            VM_DIR="$2"; shift 2 ;;
        --input=*)   VM_DIR="${1#*=}"; shift ;;
        -o|--output)
            [[ $# -ge 2 ]] || die "Option $1 requires an argument."
            DEST="$2"; shift 2 ;;
        --output=*)  DEST="${1#*=}"; shift ;;
        -h|--help)   usage; exit 0 ;;
        --)          shift; break ;;
        -*)          usage >&2; die "Unknown option: $1" ;;
        *)           usage >&2; die "Unexpected argument: $1" ;;
    esac
done

[[ -n "$DEST" ]] || { usage >&2; die "The output directory (-o/--output) is required."; }

# Normalise
VM_DIR="${VM_DIR%/}"
DEST="${DEST%/}"

# 
# Pre-flight checks
# 
for cmd in virsh qemu-img rsync find; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

[[ -n "$VM_DIR" && -d "$VM_DIR" ]] || die "VM directory does not exist: ${VM_DIR:-<empty>}"
[[ -n "$DEST" ]] || die "Destination directory not specified."

# Refuse to write the backup inside the source tree (it would recurse).
if command -v realpath >/dev/null 2>&1; then
    _vm="$(realpath -m -- "$VM_DIR")"
    _dest="$(realpath -m -- "$DEST")"
    if [[ "$_dest/" == "$_vm/"* ]]; then
        die "Destination ($DEST) is inside the VM directory ($VM_DIR); choose another location."
    fi
fi

QCOW2_DIR="$DEST/qcow2"
KVM_DIR="$DEST/kvm"
ISOS_DIR="$DEST/isos"

mkdir -p "$QCOW2_DIR" "$KVM_DIR" "$ISOS_DIR" \
    || die "Could not create destination directories under: $DEST"

# Open the log file now that the output directory exists. Everything logged from here <dest>/backup-vms.log.
_logfile="$DEST/backup-vms.log"
if : > "$_logfile" 2>/dev/null; then
    LOGFILE="$_logfile"
else
    warn "Could not open log file: $_logfile (continuing without a file log)."
fi

log "Backup started"
log "  source images : $VM_DIR"
log "  destination   : $DEST"
[[ -n "$LOGFILE" ]] && log "  log file      : $LOGFILE"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    warn "Not running as root - some VMs, networks or images may be inaccessible."
fi

# Enumerate domains and networks once; reused by the steps below.
mapfile -t VMS  < <(virsh list --all --name     2>/dev/null | sed '/^[[:space:]]*$/d')
mapfile -t NETS < <(virsh net-list --all --name 2>/dev/null | sed '/^[[:space:]]*$/d')

# 
# Disk images  ->  <dest>/qcow2/
# 
log "Copying disk images -> $QCOW2_DIR"

# Recreate the directory structure first.
while IFS= read -r -d '' dir; do
    rel="${dir#"$VM_DIR"}"; rel="${rel#/}"
    mkdir -p "$QCOW2_DIR/$rel" || warn "Could not create directory: $QCOW2_DIR/$rel"
done < <(find "$VM_DIR" -mindepth 1 -type d -print0)

# Copy every regular file; convert qcow2 images with qemu-img.
while IFS= read -r -d '' file; do
    rel="${file#"$VM_DIR"}"; rel="${rel#/}"
    dest="$QCOW2_DIR/$rel"
    mkdir -p "$(dirname -- "$dest")"

    fmt="$(qemu-img info "$file" 2>/dev/null \
            | awk -F': ' '/^file format:/ {print $2; exit}')"

    if [[ "$fmt" == "qcow2" ]]; then
        log "  convert  $rel"
        qemu-img convert -f qcow2 -O qcow2 "$file" "$dest" \
            || warn "qemu-img convert failed: $file"
    else
        log "  copy     $rel"
        cp -a -- "$file" "$dest" \
            || warn "copy failed: $file"
    fi
done < <(find "$VM_DIR" -mindepth 1 -type f -print0)

# 
# VM qcow2 disks stored OUTSIDE the input directory
# The directory walk above only sees files under $VM_DIR. Some VMs keep
# their disks elsewhere (per the domain definition), so copy those too,
# mirroring their absolute path under <dest>/qcow2/.
# 
declare -A COPIED_EXTERNAL=()
if [[ ${#VMS[@]} -gt 0 ]]; then
    log "Copying VM disks stored outside the input directory ..."
    for vm in "${VMS[@]}"; do
        while IFS=$'\t' read -r tgt src; do
            rel="${src#"$VM_DIR"/}"
            [[ "$rel" != "$src" ]] && continue          # under input dir: already copied
            [[ -n "${COPIED_EXTERNAL[$src]:-}" ]] && continue
            out="$(disk_output_path "$src")"
            log "  external ($vm): $src"
            mkdir -p "$(dirname -- "$out")"
            if qemu-img convert -f qcow2 -O qcow2 "$src" "$out"; then
                COPIED_EXTERNAL[$src]=1
            else
                warn "qemu-img convert failed for external disk: $src"
            fi
        done < <(vm_qcow2_disks "$vm")
    done
fi

# 
# VM & network definitions  ->  <dest>/kvm/
# 
log "Exporting VM definitions -> $KVM_DIR"
if [[ ${#VMS[@]} -eq 0 ]]; then
    warn "No virtual machines found (or libvirt not reachable)."
else
    for vm in "${VMS[@]}"; do
        log "  VM   $vm"
        if ! virsh dumpxml "$vm" > "$KVM_DIR/${vm}.xml" 2>/dev/null; then
            warn "virsh dumpxml failed: $vm"
            rm -f "$KVM_DIR/${vm}.xml"
        fi
    done
fi

log "Exporting virtual-network definitions -> $KVM_DIR"
if [[ ${#NETS[@]} -eq 0 ]]; then
    warn "No virtual networks found (or libvirt not reachable)."
else
    for net in "${NETS[@]}"; do
        log "  NET  $net"
        # Prefixed with "network-" so a network never overwrites a VM of the
        # same name (both live in the kvm/ directory as requested).
        if ! virsh net-dumpxml "$net" > "$KVM_DIR/network-${net}.xml" 2>/dev/null; then
            warn "virsh net-dumpxml failed: $net"
            rm -f "$KVM_DIR/network-${net}.xml"
        fi
    done
fi

# 
# 3. ISO images  ->  <dest>/isos/
# 
if [[ -d "$ISO_SRC" ]]; then
    log "Synchronizing ISOs: $ISO_SRC/  ->  $ISOS_DIR/"
    rsync -a --delete -- "$ISO_SRC/" "$ISOS_DIR/" \
        || warn "rsync reported errors while copying ISOs."
else
    warn "ISO source directory not found, skipping: $ISO_SRC"
fi

# 
# Backup manifest  ->  <dest>/vm-backup-YYYY-MM-DD.yaml
#
# A per-VM index that a future restore script can consume.
# 
MANIFEST="$DEST/vm-backup-${RUN_DATE}.yaml"
log "Writing backup manifest -> $MANIFEST"

# Timing fields (finish time and elapsed duration).
END_EPOCH="$(date +%s)"
END_DATETIME="$(date '+%F %T')"                 # date and time
ELAPSED=$(( END_EPOCH - START_EPOCH ))
(( ELAPSED < 0 )) && ELAPSED=0
DURATION="$(printf '%02d:%02d:%02d' "$((ELAPSED / 3600))" "$(((ELAPSED % 3600) / 60))" "$((ELAPSED % 60))")"

# Quote and escape a string as a YAML double-quoted scalar.
yesc() { local s=$1; s=${s//\\/\\\\}; s=${s//\"/\\\"}; printf '"%s"' "$s"; }

{
    printf 'backup_date: %s\n'      "$(yesc "$RUN_DATE")"
    printf 'backup_start: %s\n'     "$(yesc "$START_TIME")"     # YYYY-MM-DD HH:MM:SS
    printf 'backup_end: %s\n'       "$(yesc "$END_DATETIME")"   # YYYY-MM-DD HH:MM:SS
    printf 'backup_duration: %s\n'  "$(yesc "$DURATION")"       # HH:MM:SS
    printf 'input_dir: %s\n'   "$(yesc "$VM_DIR")"
    printf 'output_dir: %s\n'  "$(yesc "$DEST")"
    printf 'vms:'

    if [[ ${#VMS[@]} -eq 0 ]]; then
        printf ' []\n'
    else
        printf '\n'
        for vm in "${VMS[@]}"; do
            printf '  - name: %s\n' "$(yesc "$vm")"
            printf '    definition:\n'
            printf '      output: %s\n' "$(yesc "$KVM_DIR/${vm}.xml")"

            # ---- qcow2 disks: input path + copied output path ----
            disks_out=""
            while IFS=$'\t' read -r tgt src; do
                out="$(disk_output_path "$src")"
                disks_out+="      - target: $(yesc "$tgt")"$'\n'
                disks_out+="        input: $(yesc "$src")"$'\n'
                disks_out+="        output: $(yesc "$out")"$'\n'
            done < <(vm_qcow2_disks "$vm")

            if [[ -n "$disks_out" ]]; then
                printf '    disks:\n%s' "$disks_out"
            else
                printf '    disks: []\n'
            fi

            # ---- libvirt networks the VM attaches to ----
            nets_out=""
            while IFS= read -r net; do
                [[ -n "$net" ]] || continue
                nets_out+="      - name: $(yesc "$net")"$'\n'
                nets_out+="        output: $(yesc "$KVM_DIR/network-${net}.xml")"$'\n'
            done < <(virsh domiflist "$vm" 2>/dev/null \
                        | awk 'NR>2 && $2=="network" {print $3}' | sort -u)

            if [[ -n "$nets_out" ]]; then
                printf '    networks:\n%s' "$nets_out"
            else
                printf '    networks: []\n'
            fi
        done
    fi
} > "$MANIFEST" || warn "Failed to write manifest: $MANIFEST"

#
# Summary
#
if [[ "$WARNINGS" -eq 0 ]]; then
    log "Backup finished successfully -> $DEST"
    exit 0
else
    log "Backup finished with $WARNINGS warning(s) -> $DEST"
    exit 2
fi
