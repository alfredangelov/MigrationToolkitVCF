function Move-VMsToFolders {
    [CmdletBinding()]
    param (
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$ConfigPath = ".\shared\migration.config.json",
        [switch]$VerboseOutput
    )

    # Import configuration helper
    Import-Module $PSScriptRoot\ConfigurationModule.psm1 -Force

    Write-Host "`n🚚 Starting VM relocation using config: $ConfigPath"

    try {
        $config = Get-MigrationConfig -ConfigPath $ConfigPath
        $server = $config.TargetVCenter.Server
        $mappingPath = $config.Folders.VMMappingJson
        $DryRun = $config.DryRun
        $jsonDepth = $config.Folders.JsonDepth
        $credential = Get-VCenterCredential -CredentialProfile $config.TargetVCenter.CredentialProfile -AllowPrompt
        Write-Host "🔐 Retrieved credential from SecretVault"
    } catch {
        Write-Error "❌ Configuration error: $($_.Exception.Message)"
        return
    }

    Connect-VIServer -Server $server -Credential $credential -ErrorAction Stop | Out-Null

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
    $summary | ConvertTo-Json -Depth 4 | Set-Content -Path "export\vm-relocation-summary.json"

    Write-Host "`n📝 Relocation summary written to: export\vm-relocation-summary.json"

    Disconnect-VIServer -Confirm:$false | Out-Null
    $mode = if ($DryRun) { "DryRun" } else { "Live" }
    Write-Host "`n✅ VM relocation complete. Mode: $mode"
}
