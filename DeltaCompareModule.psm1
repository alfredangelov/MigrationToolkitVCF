function Compare-FolderStructures {
    param (
        [string]$Before,
        [string]$After,
        [int]$JsonDepth = 256,
        [switch]$VerboseOutput
    )

    if (-not (Test-Path $Before)) {
        Write-Warning "❌ Missing input file: $Before"
        return
    }
    if (-not (Test-Path $After)) {
        Write-Warning "❌ Missing input file: $After"
        return
    }

    function Build-VMIndex {
        param ($Tree)

        $Index = @{}

        function Walk ($Node, $Stack) {
            $name = $Node.Name
            if (-not $name) { return }

            $path = ($Stack + $name) -join "\"

            $vms = @()
            if ($Node.VMs -is [System.Collections.IEnumerable]) {
                $vms = $Node.VMs | Where-Object { $_.UUID }
            }

            foreach ($vm in $vms) {
                $uuid = $vm.UUID
                if (-not $Index.ContainsKey($uuid)) {
                    $Index[$uuid] = @{
                        Name  = $vm.Name
                        Paths = @($path)
                    }
                } else {
                    $Index[$uuid].Paths += $path
                }
            }

            $children = @()
            if ($Node.Children -is [System.Collections.IEnumerable]) {
                $children = $Node.Children | Where-Object { $_ -is [object] }
            }

            foreach ($child in $children) {
                Walk $child ($Stack + $name)
            }
        }

        if ($Tree -is [System.Collections.IEnumerable]) {
            foreach ($n in $Tree) { Walk $n @() }
        } else {
            Walk $Tree @()
        }

        return $Index
    }

    # Load trees
    $beforeTree = Get-Content $Before | ConvertFrom-Json -Depth $JsonDepth
    $afterTree  = Get-Content $After  | ConvertFrom-Json -Depth $JsonDepth

    $indexBefore = Build-VMIndex $beforeTree
    $indexAfter  = Build-VMIndex $afterTree

    $uuidsBefore = $indexBefore.Keys
    $uuidsAfter  = $indexAfter.Keys

    $missing = $uuidsBefore | Where-Object { -not $uuidsAfter -contains $_ }
    $added   = $uuidsAfter  | Where-Object { -not $uuidsBefore -contains $_ }

    $moved   = @()
    foreach ($uuid in ($uuidsBefore | Where-Object { $uuidsAfter -contains $_ })) {
        $pathsBefore = ($indexBefore[$uuid].Paths | Sort-Object)
        $pathsAfter  = ($indexAfter[$uuid].Paths  | Sort-Object)

        if (-not ($pathsBefore -join ',') -eq ($pathsAfter -join ',')) {
            $moved += @{
                UUID        = $uuid
                Name        = $indexAfter[$uuid].Name
                OldPaths    = $pathsBefore
                NewPaths    = $pathsAfter
            }
        }
    }

    if ($VerboseOutput) {
        Write-Host "`n--- 📦 VMs Added ---"
        foreach ($uuid in $added) {
            $info = $indexAfter[$uuid]
            Write-Host "🟢 [$uuid] $($info.Name) in: $($info.Paths -join ', ')"
        }

        Write-Host "`n--- 🗑 VMs Missing ---"
        foreach ($uuid in $missing) {
            $info = $indexBefore[$uuid]
            Write-Host "🔴 [$uuid] $($info.Name) formerly in: $($info.Paths -join ', ')"
        }

        Write-Host "`n--- 🚚 VMs Moved ---"
        foreach ($vm in $moved) {
            Write-Host "🔁 [$($vm.UUID)] $($vm.Name)"
            Write-Host "  Old: $($vm.OldPaths -join ', ')"
            Write-Host "  New: $($vm.NewPaths -join ', ')"
        }
    }

    return [PSCustomObject]@{
        VMCountBefore = $uuidsBefore.Count
        VMCountAfter  = $uuidsAfter.Count
        MissingVMs    = $missing
        AddedVMs      = $added
        MovedVMs      = $moved
    }
}
