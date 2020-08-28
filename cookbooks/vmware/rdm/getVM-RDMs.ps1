#
# (c) 2013, Jose Angel de Bustos Perez <jadebustos@gmail.com>
#
# Distributed under GNU GPL v2 License
# See COPYING.txt for more details

#
# This scripts will generate a csv file with all the RDMs in the specified VM registered at the vCenter with all
# its RDM disks (virtual and physical)
#
# Arguments:
#  1st - vCenter
#  2nd - vCenter user
#  3rd - User password
#  4th - vm name

# This script was developed to work with ESX and ESXi versions 4.0 and 4.1.

$vCenter=$args[0]
$user=$args[1]
$pass=$args[2]
$vm=$args[3]

#if ($args.Count -lt 4) {
#	write-host "El numero de argumentos debe ser mínimo 3: VCenter, username and password"	
#	exit(1)
#}

#Connect to server
Connect-VIServer -Server $vCenter -User $user -Password $pass

#Control of errors:
#$erroractionpreference = "SilentlyContinue"

$rdmReport = @()
$row="VM;HD Name;Type;Canonical Name;Filename;LUN ID;Capacity (GB);MultipathPolicy"
$rdmReport += $row
$reportFileName = $vm+".csv"

# Get the list of all the VMs in the Vcenter Inventory
$myvm = Get-VM $vm

   # Iterate over each hard-disk of each VM that is a virtual or Physical RDM
   foreach ($hd in ($myvm | Get-HardDisk -DiskType "RawPhysical","RawVirtual" )){
	$lun = Get-SCSILun $hd.ScsiCanonicalName -VMHost (Get-VM $VM).VMHost
	$lunid=$lun.RuntimeName.Substring($Lun.RuntimeName.LastIndexof(“L”)+1)
	$lunsize=$lun.CapacityMB	
	$row = $vm+";"+$hd.Name+";"+$hd.DiskType+";"+$hd.ScsiCanonicalName+";"+$hd.FileName+";"+$lunid+";"+$lunsize+";"+$lun.MultipathPolicy
	$rdmReport += $row	
        #write-host "-------------------------------------------------"
        # Print out VM Name
        #write-host "VM: " $hd.Parent.Name
        # Print Hard Disk Name
        #write-host "HD Name: " $hd.Name
        # Print Hard Disk Type
        #write-host "Tipo: " $hd.DiskType
        # Print NAA Device ID
        #write-host "Canonical name: " $hd.ScsiCanonicalName
        # Print out the VML Device ID
        #write-host "Device name: " $hd.DeviceName      

	#write-host "Filename: " $hd.FileName
	#write-host "Lun: " $lun.RuntimeName.Substring($Lun.RuntimeName.LastIndexof(“L”)+1)
	#write-host "Capacity: " $lun.CapacityMB
	#write-host "MultipathPolicy: " $lun.MultipathPolicy
   }
   Write-Host $rdmReport
   $rdmReport | export-csv $reportFileName 
