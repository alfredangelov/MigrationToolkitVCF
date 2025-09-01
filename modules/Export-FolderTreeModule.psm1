function Export-FolderTree {
    [CmdletBinding()]
    param (
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$ConfigPath = ".\shared\migration.config.json",
        [switch]$VerboseOutput
    )

    # Import configuration helper
    Import-Module $PSScriptRoot\ConfigurationModule.psm1 -Force

    Write-Host "`n📥 Loading source export config: $ConfigPath"

    try {
        $cfg = Get-MigrationConfig -ConfigPath $ConfigPath
        $server     = $cfg.SourceVCenter.Server
        $datacenter = $cfg.SourceVCenter.Datacenter
        $rootFolder = $cfg.Folders.Root
        $outputPath = $cfg.Folders.OutputJson
        $jsonDepth  = $cfg.Folders.JsonDepth
        $DryRun     = $cfg.DryRun
        $jsonLimit  = if ($jsonDepth -gt 100) { 100 } else { $jsonDepth }
        
        $credential = Get-VCenterCredential -CredentialProfile $cfg.SourceVCenter.CredentialProfile -AllowPrompt
    } catch {
        Write-Error "❌ Configuration error: $($_.Exception.Message)"
        return
    }

    Write-Host "🔐 Retrieved source credential from SecretVault"

    Connect-VIServer -Server $server -Credential $credential -ErrorAction Stop | Out-Null

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
