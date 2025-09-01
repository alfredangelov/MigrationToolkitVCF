function Convert-VMsToTemplates {
    [CmdletBinding()]
    param (
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$ConfigPath = ".\shared\migration.config.json",
        [switch]$VerboseOutput
    )

    # Import configuration helper
    Import-Module $PSScriptRoot\ConfigurationModule.psm1 -Force

    try {
        $cfg = Get-MigrationConfig -ConfigPath $ConfigPath
        $server = $cfg.TargetVCenter.Server
        $datacenter = $cfg.TargetVCenter.Datacenter
        $DryRun = $cfg.DryRun
        $credential = Get-VCenterCredential -CredentialProfile $cfg.TargetVCenter.CredentialProfile -AllowPrompt
    } catch {
        Write-Error "❌ Configuration error: $($_.Exception.Message)"
        return
    }

    if (-not (Test-Path "export\template-list.json")) {
        Write-Error "❌ Missing export\template-list.json file"
        return
    }

    $templateMap = Get-Content "export\template-list.json" | ConvertFrom-Json

    Connect-VIServer -Server $server -Credential $credential -ErrorAction Stop | Out-Null

    $templateCount = $templateMap.Keys.Count
    $restoredCount = 0
    $missingVms = @()

    foreach ($uuid in $templateMap.Keys) {
        $entry = $templateMap[$uuid]
        $vmName = $entry.Name

        $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
        if (-not $vm) {
            Write-Warning "⚠️ VM not found: $vmName"
            $missingVms += $vmName
            continue
        }

        if ($DryRun) {
            Write-Host "🧪 [DryRun] Would convert VM '$vmName' back to Template"
        } else {
            Write-Host "🎁 Converting VM '$vmName' back to Template"
            Set-VM -VM $vm -ToTemplate | Out-Null
            $restoredCount++
        }
    }

    Disconnect-VIServer -Confirm:$false | Out-Null

    $summary = [PSCustomObject]@{
        DryRun          = $DryRun.IsPresent
        TotalTemplates  = $templateCount
        Restored        = $restoredCount
        MissingVMs      = $missingVms
        CompletedAt     = Get-Date
    }
    $summary | ConvertTo-Json -Depth 4 | Set-Content "export\template-restore-summary.json"

    Write-Host "`n✅ Template restoration completed. Summary written to: export\template-restore-summary.json"
}
