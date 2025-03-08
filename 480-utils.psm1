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
