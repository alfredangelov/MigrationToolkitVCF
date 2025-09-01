function Test-FolderStructure {
    [CmdletBinding()]
    param (
        [string]$JsonPath,
        [string]$ConfigPath,
        [switch]$VerboseOutput
    )

    if ($ConfigPath) {
        Write-Host "`n📥 Loading audit config: $ConfigPath"
        $cfg        = Get-Content $ConfigPath | ConvertFrom-Json
        $JsonPath   = $cfg.Folders.OutputJson
        #$jsonDepth  = $cfg.Folders.JsonDepth
    }

    if (-not (Test-Path $JsonPath)) {
        Write-Error "❌ Folder structure file not found: $JsonPath"
        return
    }

    $content = Get-Content $JsonPath | ConvertFrom-Json -Depth 100
    $tree = if ($content.PSObject.Properties.Name -contains "Tree") {
        $content.Tree
    } else {
        $content
    }

    # Declare counters with script scope so nested function can update them
    $script:folderCount  = 0
    $script:vmCount      = 0
    $script:emptyFolders = @()

    function Traverse {
        param ([object]$Node)

        if ($Node.Type -eq "Folder") {
            $script:folderCount++

            if (-not $Node.Children -or $Node.Children.Count -eq 0) {
                $script:emptyFolders += $Node.Name
            }

            foreach ($child in $Node.Children) {
                Traverse -Node $child
            }
        } elseif ($Node.Type -eq "VirtualMachine") {
            $script:vmCount++
        }

        if ($VerboseOutput) {
            Write-Host "🔎 Traversed node: $($Node.Name) [$($Node.Type)]"
        }
    }

    Traverse -Node $tree

    $result = [PSCustomObject]@{
        FolderCount  = $script:folderCount
        VMCount      = $script:vmCount
        EmptyFolders = $script:emptyFolders
    }

    if ($VerboseOutput) {
        Write-Host "`n📊 Audit Summary:"
        Write-Host "Total folders: $($result.FolderCount)"
        Write-Host "Total VMs:     $($result.VMCount)"
        Write-Host "Empty folders: $($result.EmptyFolders.Count)"
    }

    return $result
}
