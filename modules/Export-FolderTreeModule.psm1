function Export-FolderTree {
    [CmdletBinding()]
    param (
        [string]$ConfigPath = ".\shared\migration.config.json",
        [switch]$VerboseOutput
    )

    Write-Host "`n📥 Loading source export config: $ConfigPath"

    if (-not (Test-Path $ConfigPath)) {
        Write-Error "❌ Config file not found: $ConfigPath"
        return
    }

    $cfg        = Get-Content $ConfigPath | ConvertFrom-Json
    $server     = $cfg.SourceVCenter.Server
    $datacenter = $cfg.SourceVCenter.Datacenter
    $secret     = $cfg.SourceVCenter.CredentialProfile
    $rootFolder = $cfg.Folders.Root
    $outputPath = $cfg.Folders.OutputJson
    $jsonDepth  = $cfg.Folders.JsonDepth
    $DryRun     = $cfg.DryRun
    $jsonLimit  = if ($jsonDepth -gt 100) { 100 } else { $jsonDepth }

    try {
        Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction SilentlyContinue
        $Credential = Get-Secret -Name $secret
        Write-Host "🔐 Retrieved source credential from SecretVault"
    } catch {
        Write-Warning "⚠️ Secret retrieval failed — prompting manually..."
        $Credential = Get-Credential -Message "Enter vCenter credentials"
    }

    Connect-VIServer -Server $server -Credential $Credential -ErrorAction Stop | Out-Null

    $dc   = Get-Datacenter -Name $datacenter
    $root = Get-Folder -Name $rootFolder -Location $dc

    Write-Host "`n📤 Exporting folder tree from $server ($datacenter) ➜ root folder: '$rootFolder'"

    function Get-FolderTree {
        param ([object]$node)

        $children = @()
        $childObjects = Get-Inventory -Location $node -NoRecursion

        foreach ($child in $childObjects) {
            $typeName = $child.PSObject.TypeNames -join ','

            if ($child -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]) {
                $children += Get-FolderTree -node $child
            } elseif ($typeName -like "*VirtualMachineImpl*") {
                $children += [PSCustomObject]@{
                    Name     = $child.Name
                    Type     = "VirtualMachine"
                    Children = @()
                }
            }
        }

        return [PSCustomObject]@{
            Name     = $node.Name
            Type     = "Folder"
            Children = $children
        }
    }

    $tree = Get-FolderTree -node $root

    Disconnect-VIServer -Confirm:$false | Out-Null

    $metaWrapped = [PSCustomObject]@{
        DryRun      = $DryRun
        GeneratedAt = Get-Date
        Tree        = $tree
    }

    $metaWrapped | ConvertTo-Json -Depth $jsonLimit | Set-Content -Path $outputPath

    Write-Host "`n📄 Folder tree (dry-run wrapped) written to: $outputPath"

    return $tree | Out-Null
}
