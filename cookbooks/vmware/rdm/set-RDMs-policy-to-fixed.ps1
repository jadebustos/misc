#
# (c) 2013, Jose Angel de Bustos Perez <jadebustos@gmail.com>
#
# Distributed under GNU GPL v2 License
# See COPYING.txt for more details

# This script will set RDMs policy to fixed
#
# Arguments:
#  1st - vCenter
#  2nd - vCenter user
#  3rd - User password
#  4th - vm

# This script was developed to work with ESX and ESXi versions 4.0 and 4.1.

$argv=$args.count
$vCenter=$args[0]
$user=$args[1]
$pass=$args[2]
$vm=$args[3]

if ($argv -lt 4) {
	write-host "El numero de argumentos debe ser minimo 3: VCenter, username and password"
	exit(1)
}

#Connect to server
Connect-VIServer -Server $vCenter -User $user -Password $pass

#Control of errors:
#$erroractionpreference = "SilentlyContinue"

# Get the list of all the VMs in the Vcenter Inventory
$vm = Get-VM $vm

   # Iterate over each hard-disk of each VM that is a virtual or Physical RDM
   foreach ($hd in ($vm | Get-HardDisk -DiskType "RawPhysical","RawVirtual" )){
	$lun = Get-SCSILun $hd.ScsiCanonicalName -VMHost (Get-VM $VM).VMHost -LunType disk
        write-host "-------------------------------------------------"
        # Print out VM Name
        write-host "VM: " $hd.Parent.Name
        # Print Hard Disk Name
        write-host "HD Name: " $hd.Name
        # Print Hard Disk Type
        write-host "Tipo: " $hd.DiskType
        # Print NAA Device ID
        write-host "Canonical name: " $hd.ScsiCanonicalName
        # Print out the VML Device ID
        write-host "Device name: " $hd.DeviceName      

	write-host "Filename: " $hd.FileName
	write-host "Lun: " $lun.RuntimeName.Substring($Lun.RuntimeName.LastIndexof(“L”)+1)
	write-host "Capacity: " $lun.CapacityMB
	$policy = $lun.MultipathPolicy
	write-host "Multipath Policy: " $policy

	#$lunpath = Get-ScsiLunPath -scsilun $lun | where-object {$_.ExtensionData.Adapter -like "*$prefPathHBA"}
	#Get-SCSILun $targetName -VMHost $esxi1 | Set-ScsiLun -MultipathPolicy "Fixed" PreferredPath $lunpath -confirm:$false

	if ( $policy -ne "Fixed" ) {
	
		$lunpath = Get-ScsiLunPath -scsilun $lun | where-object {$_ -like "*Active"}
		Set-ScsiLun -scsilun $lun -MultipathPolicy "Fixed" -PreferredPath $lunpath.Name
		#Get-SCSILun $hd.ScsiCanonicalName -VMHost (Get-VM $VM).VMHost | Set-ScsiLun -MultipathPolicy "Fixed"
		write-host "Multipath Policy changed to Fixed."
	}

   }
