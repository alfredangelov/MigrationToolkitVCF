function Convert-TemplatesToVM {
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
        $server = $cfg.SourceVCenter.Server
        $datacenter = $cfg.SourceVCenter.Datacenter
        $DryRun = $cfg.DryRun
        $credential = Get-VCenterCredential -CredentialProfile $cfg.SourceVCenter.CredentialProfile -AllowPrompt
    } catch {
        Write-Error "❌ Configuration error: $($_.Exception.Message)"
        return
    }

    Connect-VIServer -Server $server -Credential $credential -ErrorAction Stop | Out-Null

    $templates = Get-Template

    $templateList = @{}

    foreach ($template in $templates) {
        $vmRef = $template.ExtensionData.Config.InstanceUuid
        $vmName = $template.Name
        $folderPath = $template.Folder.Name

        $templateList[$vmRef] = @{
            Name  = $vmName
            Folder = $folderPath
        }

        if ($DryRun) {
            Write-Host "🧪 [DryRun] Would convert template '$vmName' to VM"
        } else {
            Write-Host "📦 Converting template '$vmName' to VM"
            Set-Template -Template $template -ToVM | Out-Null
        }
    }

    $templateSummary = [PSCustomObject]@{
    DryRun      = $DryRun.IsPresent
    GeneratedAt = Get-Date
    TemplateCount = $templateList.Count
    Templates   = $templateList
    }

    $templateSummary | ConvertTo-Json -Depth 4 | Set-Content -Path "export\template-list.json"

    if ($VerboseOutput) {
        Write-Host "`n📄 Template metadata written to: template-list.json"
        Write-Host "🧬 Total templates found: $($templateList.Count)"
    }

    Disconnect-VIServer -Confirm:$false | Out-Null
    Write-Host "`n✅ Conversion complete. Output: template-list.json"
}
