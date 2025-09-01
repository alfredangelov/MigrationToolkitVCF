function Move-VMsToFolders {
    [CmdletBinding()]
    param (
        [string]$ConfigPath = ".\migration.config.json",
        [switch]$VerboseOutput
    )

    Write-Host "`n🚚 Starting VM relocation using config: $ConfigPath"

    if (-not (Test-Path $ConfigPath)) {
        Write-Error "❌ Config file not found: $ConfigPath"
        return
    }

    $config      = Get-Content $ConfigPath | ConvertFrom-Json
    $server      = $config.TargetVCenter.Server
    #$datacenter  = $config.TargetVCenter.Datacenter
    $secretName  = $config.TargetVCenter.CredentialProfile
    $mappingPath = $config.Folders.VMMappingJson
    $DryRun      = $config.DryRun
    $jsonDepth   = $config.Folders.JsonDepth

    try {
        Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction SilentlyContinue
        $Credential = Get-Secret -Name $secretName
        Write-Host "🔐 Retrieved credential from SecretVault"
    } catch {
        Write-Warning "⚠️ Secret retrieval failed — prompting manually..."
        $Credential = Get-Credential -Message "Enter vCenter credentials"
    }

    Connect-VIServer -Server $server -Credential $Credential -ErrorAction Stop | Out-Null

    if (-not (Test-Path $mappingPath)) {
        Write-Error "❌ VM mapping file not found: $mappingPath"
        Disconnect-VIServer -Confirm:$false | Out-Null
        return
    }

    $content = Get-Content $mappingPath | ConvertFrom-Json -Depth $jsonDepth
    $vmMap = if ($content.PSObject.Properties.Name -contains "Tree") {
        $content.Tree
    } else {
        $content
    }

    $movedVMs = @()
    $missingVMs = @()
    $missingFolders = @()

    foreach ($uuid in $vmMap.Keys) {
        $entry = $vmMap[$uuid]
        $vmName = $entry.Name
        $targetPaths = $entry.Paths
        $targetFolderName = $targetPaths[-1]

        $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
        if (-not $vm) {
            Write-Warning "⚠️ VM not found: $vmName"
            $missingVMs += $vmName
            continue
        }

        $folder = Get-Folder -Name $targetFolderName -ErrorAction SilentlyContinue
        if (-not $folder) {
            Write-Warning "⚠️ Target folder '$targetFolderName' not found"
            $missingFolders += $targetFolderName
            continue
        }

        if ($DryRun) {
            Write-Host "🧪 [DryRun] Would move VM '$vmName' to folder '$($folder.Name)'"
        } else {
            Write-Host "🚚 Moving VM '$vmName' to folder '$($folder.Name)'"
            Move-VM -VM $vm -Destination $folder
        }
        $movedVMs += $vmName
    }

    $summary = [PSCustomObject]@{
    DryRun        = $DryRun
    MovedVMs      = $movedVMs
    MissingVMs    = $missingVMs
    MissingFolders = $missingFolders
    CompletedAt   = Get-Date
    TargetServer  = $server
}
    $summary | ConvertTo-Json -Depth 4 | Set-Content -Path "vm-relocation-summary.json"

    Write-Host "`n📝 Relocation summary written to: vm-relocation-summary.json"

    Disconnect-VIServer -Confirm:$false | Out-Null
    $mode = if ($DryRun) { "DryRun" } else { "Live" }
    Write-Host "`n✅ VM relocation complete. Mode: $mode"
}
