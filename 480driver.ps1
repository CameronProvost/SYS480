# Call the Banner Function
480Banner

# Load the JSON Configuration
$conf = Get-480Config -config_path "/home/cameron/Documents/Github/SYS480/480.json"
Write-Host "Config Loaded: $conf"

# Connect to VCenter
480Connect -server $conf.vcenter_server

# Select a VM
Write-Host "Selecting your VM"
$selectedVM = Select-VM -folder $conf.vm_folder
Write-Host "VM Selected: $($selectedVM.Name)"

# Select a Datastore
Write-Host "Selecting your Datastore"
$selectedDatastore = Select-DB
Write-Host "Datastore Selected: $($selectedDatastore.Name)"

# Create a Full Clone VM with selected VM and Datastore
FullClone -selected_vm $selectedVM -selected_datastore $selectedDatastore
Write-Host 'Full Clone Created.'
