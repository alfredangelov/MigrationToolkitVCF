function Import-FolderTree {
    [CmdletBinding()]
    param (
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$ConfigPath = ".\shared\migration.config.json",
        [switch]$VerboseOutput
    )

    # Import configuration helper
    Import-Module $PSScriptRoot\ConfigurationModule.psm1 -Force

    Write-Host "`n🔧 Importing folder tree using config: $ConfigPath"

    try {
        $cfg = Get-MigrationConfig -ConfigPath $ConfigPath
        $server = $cfg.TargetVCenter.Server
        $datacenter = $cfg.TargetVCenter.Datacenter
        $jsonPath = $cfg.Folders.OutputJson
        $DryRun = $cfg.DryRun
        $jsonDepth = $cfg.Folders.JsonDepth
        $credential = Get-VCenterCredential -CredentialProfile $cfg.TargetVCenter.CredentialProfile -AllowPrompt
        Write-Host "🔐 Retrieved target credential from SecretVault"
    } catch {
        Write-Error "❌ Configuration error: $($_.Exception.Message)"
        return
    }

    Connect-VIServer -Server $server -Credential $credential -ErrorAction Stop | Out-Null

    if (-not (Test-Path $jsonPath)) {
        Write-Error "❌ Folder structure file not found: $jsonPath"
        Disconnect-VIServer -Confirm:$false | Out-Null
        return
    }

    $content = Get-Content $jsonPath | ConvertFrom-Json -Depth $jsonDepth
    $tree = if ($content.PSObject.Properties.Name -contains "Tree") {
        $content.Tree
    } else {
        $content
    }

    $dc     = Get-Datacenter -Name $datacenter
    $parent = Get-Folder -Name $tree.Name -Location $dc

    function Import-Tree {
        param ([object]$Node, [object]$Parent)

        if ($Node.Type -ne "Folder") {
            return
        }

        $existing = Get-Folder -Name $Node.Name -Location $Parent -ErrorAction SilentlyContinue
        if (-not $existing) {
            if ($DryRun) {
                Write-Host "🧪 [DryRun] Would create folder: '$($Node.Name)' under $($Parent.Name)"
            } else {
                New-Folder -Name $Node.Name -Location $Parent | Out-Null
                Write-Host "📁 Created folder: '$($Node.Name)' under $($Parent.Name)"
            }
        } elseif ($VerboseOutput) {
            Write-Host "✅ Folder exists: '$($Node.Name)' under $($Parent.Name)"
        }

        foreach ($child in $Node.Children | Where-Object { $_.Type -eq "Folder" }) {
            Import-Tree -Node $child -Parent $existing
        }
    }

    Import-Tree -Node $tree -Parent $parent

    $summary = [PSCustomObject]@{
        DryRun       = $DryRun
        ImportedAt   = Get-Date
        TargetServer = $server
        Datacenter   = $datacenter
        SourceJson   = $jsonPath
        RootFolder   = $tree.Name
    }

    $summary | ConvertTo-Json -Depth 3 | Set-Content -Path "export\folder-import-summary.json"
    Write-Host "`n📝 Import summary written to: export\folder-import-summary.json"

    Disconnect-VIServer -Confirm:$false | Out-Null
    $mode = if ($DryRun) { "DryRun" } else { "Live" }
    Write-Host "`n✅ Folder import complete. Mode: $mode"
}
