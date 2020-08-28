#!/bin/bash

# very simple backup script
# (c) 2014, Jose Angel de Bustos Perez <jadebustos@gmail.com> 
#     Distributed under GNU GPL v2 License                    
#     See COPYING.txt for more details   

# You will need to set up:
#   * BACKUP_VM with the user and hostname of the linux machine where you want to
#               store the backup using rsync. Public key authentication is a must.
#   * BACKUP_DST is the directory in the machine configured in BACKUP_VM where the
#                backup is going to be stored using the user configured in BACKUP_VM.
#                Write permissions are needed for this directory.
#   * local2.info log facility

# This script has to be executed with one argument, a file describing what files to backup
# and where. For instance:
# [user@hostname ~]$ cat targets.bck
# /etc/*	/etc
# /var/named/* /var/named
# [user@hostname ~]$ bash backup.sh targets.bck
# where targets.bck syntax:
# /etc/* -> backup /etc/* in local machine
# /etc -> store local /etc/* in remote location BACKUP_DST/etc

HOSTNAME=`hostname | sed -e 's/\..*//g'`
BACKUP_VM="user@hostname"
BACKUP_DST="/mnt/backup/linux/"$HOSTNAME
RSYNC_OPTS="-a"

while read line
do
  SRC="$(echo "$line" | sed -e 's/[[:blank:]].*//g')"
  TGT="$(echo "$line" | awk '{print $2}')"
  SSH_CMD="ssh -f "$BACKUP_VM" mkdir -p $BACKUP_DST$TGT"
  eval $SSH_CMD
  RSYNC_CMD="rsync $RSYNC_OPTS $SRC $BACKUP_VM"":$BACKUP_DST$TGT"
  eval $RSYNC_CMD
  rc=$?
  if [ $rc -eq 0 ]
  then
    logger -p local2.info "Successful execution: $RSYNC_CMD"
  else
    logger -p local2.info "Unsuccessful execution: $RSYNC_CMD"
  fi
done < $1
