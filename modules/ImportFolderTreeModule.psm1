function Import-FolderTree {
    [CmdletBinding()]
    param (
        [string]$ConfigPath = ".\shared\migration.config.json",
        [switch]$VerboseOutput
    )

    Write-Host "`n🔧 Importing folder tree using config: $ConfigPath"

    if (-not (Test-Path $ConfigPath)) {
        Write-Error "❌ Config file not found: $ConfigPath"
        return
    }

    $cfg        = Get-Content $ConfigPath | ConvertFrom-Json
    $server     = $cfg.TargetVCenter.Server
    $datacenter = $cfg.TargetVCenter.Datacenter
    $secret     = $cfg.TargetVCenter.CredentialProfile
    $jsonPath   = $cfg.Folders.OutputJson
    $DryRun     = $cfg.DryRun
    $jsonDepth  = $cfg.Folders.JsonDepth

    try {
        Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction SilentlyContinue
        $Credential = Get-Secret -Name $secret
        Write-Host "🔐 Retrieved target credential from SecretVault"
    } catch {
        Write-Warning "⚠️ Secret retrieval failed — prompting manually..."
        $Credential = Get-Credential -Message "Enter vCenter credentials"
    }

    Connect-VIServer -Server $server -Credential $Credential -ErrorAction Stop | Out-Null

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
