function Convert-TemplatesToVM {
    [CmdletBinding()]
    param (
        [string]$ConfigPath = ".\shared\migration.config.json",
        [switch]$VerboseOutput
    )

    $cfg = Get-Content $ConfigPath | ConvertFrom-Json
    $server   = $cfg.SourceVCenter.Server
    $datacenter = $cfg.SourceVCenter.Datacenter
    $secret  = $cfg.SourceVCenter.CredentialProfile
    $DryRun  = $cfg.DryRun

    Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction SilentlyContinue
    $Credential = try { Get-Secret -Name $secret } catch { Get-Credential }

    Connect-VIServer -Server $server -Credential $Credential -ErrorAction Stop | Out-Null

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
