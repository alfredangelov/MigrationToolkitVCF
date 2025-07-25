function Convert-VMsToTemplates {
    [CmdletBinding()]
    param (
        [string]$ConfigPath = ".\migration.config.json",
        [switch]$VerboseOutput
    )

    $cfg = Get-Content $ConfigPath | ConvertFrom-Json
    $server   = $cfg.TargetVCenter.Server
    $datacenter = $cfg.TargetVCenter.Datacenter
    $secret  = $cfg.TargetVCenter.CredentialProfile
    $DryRun  = $cfg.DryRun

    if (-not (Test-Path "template-list.json")) {
        Write-Error "❌ Missing template-list.json file"
        return
    }

    $templateMap = Get-Content "template-list.json" | ConvertFrom-Json

    Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction SilentlyContinue
    $Credential = try { Get-Secret -Name $secret } catch { Get-Credential }

    Connect-VIServer -Server $server -Credential $Credential -ErrorAction Stop | Out-Null

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
    $summary | ConvertTo-Json -Depth 4 | Set-Content "template-restore-summary.json"

    Write-Host "`n✅ Template restoration completed. Summary written to: template-restore-summary.json"

}
