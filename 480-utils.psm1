function 480Banner() {
    $banner = "Welcome to 480 Utils"
    Write-Host $banner
}

function 480Connect([string] $server) {
    $conn = $global:DefaultVIServer
    # Are we already connected?
    if ($conn) {
        $msg = "Already Connected to: {0}" -f $conn
        Write-Host -ForegroundColor Green $msg
    } else {
        $conn = Connect-VIServer -Server $server
        # If this fails, let Connect-VIServer handle the exception
    }
}

function Get-480Config([string] $config_path) {
    Write-host "Reading " $config_path
    $conf = $null
    if (Test-Path $config_path) {
        $conf = Get-Content -Raw -Path $config_path | ConvertFrom-Json
        $msg = "Using Configuration at {0}" -f $config_path
        Write-Host -ForegroundColor "Green" $msg
    } else {
        Write-Host -ForegroundColor "Yellow" "No Configuration"
    }
    return $conf
}

function Select-VM([string] $folder) {
    $selected_vm = $null
    try {
        $vms = Get-VM -Location $folder
        $index = 1
        foreach ($vm in $vms) {
            Write-Host "[$index] $($vm.Name)"
            $index += 1
        }

        while ($true) {
            $pick_index = Read-Host "Enter the index number of the VM you wish to pick"

            # Check if input is a valid number and falls within the valid index range
            if ($pick_index -match "^\d+$") {
                if ($pick_index -ge 1 -and $pick_index -le $vms.Count) {
                    $selected_vm = $vms[$pick_index - 1]
                    Write-Host "You picked: $($selected_vm.Name)"
                    break # Exit the loop when a valid selection is made
                }
            }

            # If selection is invalid, prompt again
            Write-Host "Invalid selection. Please enter a valid index between 1 and $($vms.Count)." -ForegroundColor Yellow
        }

        return $selected_vm
    } catch {
        Write-Host "Error retrieving VM list or Invalid Folder: $folder" -ForegroundColor Red
    }
}

function Select-DB() {
    $selected_datastore = $null
    try {
        $datastores = Get-Datastore
        $index = 1
        foreach ($ds in $datastores) {
            Write-Host "[$index] $($ds.Name)"
            $index += 1
        }

        while ($true) {
            $pick_index = Read-Host "Enter the index of the datastore"

            if ($pick_index -match "^\d+$") {
                if ($pick_index -ge 1 -and $pick_index -le $datastores.Count) {
                    $selected_datastore = $datastores[$pick_index - 1]
                    Write-Host "You selected: $($selected_datastore.Name)"
                    break # Exiting the loop
                }
            }
            Write-Host "Invalid selection. Please enter a valid index." -ForegroundColor Yellow
        }
        return $selected_datastore
    } catch {
        Write-Host "Error retrieving datastore list." -ForegroundColor Red
    }
}

function FullClone([Parameter(Mandatory = $true)] $selected_vm, [Parameter(Mandatory = $true)] $selected_datastore) {
    if ($null -eq $selected_vm -or $null -eq $selected_datastore) {
        Write-Host "Either VM or Datastore is null. Exiting." -ForegroundColor "Red"
        return
    }

    # Get snapshot from base VM
    $snapshot = Get-Snapshot -VM $selected_vm | Sort-Object -Property Created -Descending | Select-Object -First 1
    if (!$snapshot) {
        Write-Host "No snapshot found for VM $($selected_vm.Name)!" -ForegroundColor Red
        return
    }

    # Generate a temporary linked clone name
    $tempCloneName = "$($selected_vm.Name)-temp"
    Write-Host "Creating temporary linked clone: $tempCloneName..." -ForegroundColor Yellow

    # Create the linked clone
    try {
        New-VM -Name $tempCloneName -VM $selected_vm -LinkedClone -ReferenceSnapshot $snapshot -VMHost $selected_vm.VMHost -Datastore $selected_datastore
    } catch {
        Write-Host "Error creating linked clone: $_" -ForegroundColor Red
        return
    }

    # Ask user for final full clone name
    $finalCloneName = Read-Host "Enter the name for the full clone"

    # Create full clone from the linked clone
    Write-Host "Creating full clone: $finalCloneName..." -ForegroundColor Yellow
    try {
        New-VM -Name $finalCloneName -VM $tempCloneName -VMHost $selected_vm.VMHost -Datastore $selected_datastore
    } catch {
        Write-Host "Error creating full clone: $_" -ForegroundColor Red
        return
    }

    # Remove the temporary linked clone
    Write-Host "Removing temporary linked clone: $tempCloneName..." -ForegroundColor Yellow
    try {
        Remove-VM -VM $tempCloneName -DeletePermanently -Confirm:$false
        Write-Host "Temporary clone removed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error removing temporary clone: $_" -ForegroundColor Red
    }

    Write-Host "Full Clone $finalCloneName created successfully!" -ForegroundColor Green
}


function New-Network {
    param(
        [string]$SwitchName,
        [string]$PortGroupName
    )

    $vmhost = Get-VMHost
    New-VirtualSwitch -VMHost $vmhost -Name $SwitchName -NumPorts 128
    New-VirtualPortGroup -VirtualSwitch (Get-VirtualSwitch -Name $SwitchName) -Name $PortGroupName
    Write-Host "Created Virtual Switch '$SwitchName' and Port Group '$PortGroupName'."
}

function Get-IP {
    param(
        [string]$VMName
    )

    $vm = Get-VM -Name $VMName
    $ip = $vm.Guest.IPAddress[0]
    $mac = (Get-NetworkAdapter -VM $vm)[0].MacAddress

    Write-Host "VM: $VMName"
    Write-Host "IP Address: $ip"
    Write-Host "MAC Address: $mac"
}


function Start-MyVM {
    param(
        [string]$VMName
    )
    Start-VM -VM (Get-VM -Name $VMName) | Out-Null
    Write-Host "Started VM: $VMName"
}

function Stop-MyVM {
    param(
        [string]$VMName
    )
    Stop-VM -VM (Get-VM -Name $VMName) -Confirm:$false | Out-Null
    Write-Host "Stopped VM: $VMName"
}

function Set-Network {
    param(
        [string]$VMName,
        [string]$AdapterName,
        [string]$NewNetworkName
    )

    $adapter = Get-NetworkAdapter -VM (Get-VM -Name $VMName) | Where-Object { $_.Name -eq $AdapterName }
    
    if ($adapter) {
        Set-NetworkAdapter -NetworkAdapter $adapter -NetworkName $NewNetworkName -Confirm:$false
        Write-Host "Changed $AdapterName on $VMName to $NewNetworkName."
    }
    else {
        Write-Host "Error: Adapter $AdapterName not found on $VMName."
    }
}

function New-LinkedClone {
    param(
        [string]$BaseVMName,
        [string]$NewVMName,
        [string]$DatastoreName,
        [string]$NetworkName
    )

    $baseVM = Get-VM -Name $BaseVMName
    $snapshot = Get-Snapshot -VM $baseVM | Sort-Object -Property Created -Descending | Select-Object -First 1
    $vmhost = $baseVM.VMHost
    $datastore = Get-Datastore -Name $DatastoreName

    if (!$snapshot) {
        Write-Host "No snapshot found on $BaseVMName!" -ForegroundColor Red
        return
    }

    $newVM = New-VM -Name $NewVMName -VM $baseVM -LinkedClone -ReferenceSnapshot $snapshot -VMHost $vmhost -Datastore $datastore -Confirm:$false

    # Set network
    Get-NetworkAdapter -VM $newVM | Set-NetworkAdapter -NetworkName $NetworkName -Confirm:$false

    Write-Host "Linked clone $NewVMName created and connected to $NetworkName!" -ForegroundColor Green
}

function SetWindowsIP {
    param (
        [string]$VM,
        [string]$eth,
        [string]$IP,
        [string]$mask,
        [string]$gate4,
        [string]$nameserver
    )

    $config = Get-480Config -config_path "$HOME/Documents/Github/SYS480/480.json"
    480Connect -server $config.vcenter_server

    $vm = Get-VM -Name $VM
    $Cred = Get-Credential -Message "Enter username and password for guest VM $VM"

    $script = "netsh interface ipv4 set address name=""$eth"" static $IP $mask $gate4 && netsh interface ipv4 set dnsservers name=""$eth"" static $nameserver primary"

    Invoke-VMScript -VM $vm -GuestCredential $Cred -ScriptText $script -ScriptType bat

    Write-Host "Static IP, gateway, and DNS configured for $VM on interface $eth"
}
