# Connect to vCenter Server
$vcenterip = Read-Host -Prompt "Enter your vCenter Server Address: "
Connect-VIServer -Server $vcenterip
# List all available VMs and ask the user to select one
Write-Host "Available VMs in vCenter:"
Get-VM | ForEach-Object { Write-Host "$($_.Name)" }
$vmname = Read-Host -Prompt "For which VM do you want to make a Linked Clone: "
$vm = Get-VM -Name $vmname
#Snapshot
$snapshotName = "Base"
$snapshot = Get-Snapshot -VM $vm -Name $snapshotName
# VM Host
$hostsname = Read-Host -Prompt "Enter the address of your VM Host Server: "
$vmhost = Get-VMHost -Name $hostsname
# List all available Datastores and ask the user to select one
Write-Host "Available Datastores in vCenter: "
Get-Datastore | ForEach-Object { Write-Host "$($_.Name)" }
$dsname = Read-Host -Prompt "Enter the name of the Datastore you want to use: "
$ds = Get-Datastore -Name $dsname
# Create Linked Clone
$linkedName = "{0}.linked" -f $vm.name
Write-Host "Creating Linked Clone: $linkedName"
$linkedvm = New-VM -LinkedClone -Name $linkedName -VM $vm -ReferenceSnapshot $snapshot -VMHost $vmhost -Datastore $ds
Write-Host "Linked Clone created: $linkedName"
# Create Full VM
$newvmname = Read-Host -Prompt "Enter the name for your new full VM: "
$newvm = New-VM -Name $newvmname -VM $linkedvm -VMHost $vmhost -Datastore $ds
Write-Host "Full Clone created: $newvmname"
# Create Snapshot on Full Clone
$newvm | New-Snapshot -Name "Base"
Write-Host "Snapshot 'Base' taken on the full clone."
# Cleanup: Remove the Linked Clone
$linkedvm | Remove-VM 
Write-Host "Linked Clone $linkedName removed."
