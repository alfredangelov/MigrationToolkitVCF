# Refresh modules
"ConfigurationModule",
"ConvertTemplatesToVMModule",
"Export-FolderTreeModule",
"AuditFolderModule",
"DeltaCompareModule",
"ImportFolderTreeModule",
"MoveVMsModule",
"ConvertVMsToTemplateModule" | ForEach-Object {
    Remove-Module $_ -ErrorAction SilentlyContinue
}

Import-Module .\modules\ConfigurationModule.psm1
Import-Module .\modules\ConvertTemplatesToVMModule.psm1
Import-Module .\modules\Export-FolderTreeModule.psm1
Import-Module .\modules\AuditFolderModule.psm1
Import-Module .\modules\DeltaCompareModule.psm1
Import-Module .\modules\ImportFolderTreeModule.psm1
Import-Module .\modules\MoveVMsModule.psm1
Import-Module .\modules\ConvertVMsToTemplateModule.psm1

# STEP 1: Convert templates to VMs
Convert-TemplatesToVM -ConfigPath ".\shared\migration.config.json"

# STEP 2: Export folder tree from source vCenter
Export-FolderTree -ConfigPath ".\shared\migration.config.json"

# STEP 3: Audit folder tree and count contents
$audit = Test-FolderStructure -ConfigPath ".\shared\migration.config.json" -VerboseOutput

# STEP 4: Update export_metadata.json with audit results + author info
if (Test-Path ".\export\export_metadata.json") {
    $meta = Get-Content ".\export\export_metadata.json" | ConvertFrom-Json
} else {
    # Create with default structure if missing
    $meta = [PSCustomObject]@{
        VMCount        = 0
        FolderCount    = 0
        EmptyCount     = 0
        ToolkitVersion = "2025.07.20"
        Author         = "Alfred Angelov"
        Note           = "Migrating VM inventory and folder structures from Source to Destination using VCF-compatible layout"
    }
}
$meta.VMCount        = $audit.VMCount
$meta.FolderCount    = $audit.FolderCount
$meta.EmptyCount     = $audit.EmptyFolders.Count
$meta.ToolkitVersion = "2025.07.24"
$meta.Author         = "Alfred Angelov"
$meta.Note           = "Migrating VM inventory and folder structures from Source to Destination using VCF-compatible layout"
$meta | ConvertTo-Json -Depth 5 | Set-Content ".\export\export_metadata.json"
Write-Host "`n📦 Updated export_metadata.json with audit results"

# STEP 5: Import folder tree into target vCenter
Import-FolderTree -ConfigPath ".\shared\migration.config.json"

# STEP 6: Relocate VMs
Move-VMsToFolders -ConfigPath ".\shared\migration.config.json"

# STEP 7: Convert migrated VMs back to templates
Convert-VMsToTemplates -ConfigPath ".\shared\migration.config.json"

# STEP 8: Compose final migration summary
$migrationSummary = [PSCustomObject]@{
    DryRun              = $meta.DryRun
    SourceVCenter       = $meta.SourceVCenter
    TargetVCenter       = $meta.TargetVCenter
    Datacenter          = $meta.Datacenter
    ExportMetadata      = $meta
    FolderImport        = (Get-Content ".\export\folder-import-summary.json" | ConvertFrom-Json)
    VMRelocation        = (Get-Content ".\export\vm-relocation-summary.json" | ConvertFrom-Json)
    TemplateRestoration = (Get-Content ".\export\template-restore-summary.json" | ConvertFrom-Json)
    CompletedAt         = Get-Date
    ToolkitVersion      = $meta.ToolkitVersion
    Author              = $meta.Author
}
$migrationSummary | ConvertTo-Json -Depth 6 | Set-Content ".\export\migration-summary.json"
Write-Host "`n📝 Migration summary written to: export\migration-summary.json"

# STEP 9: Final summary block
Write-Host "`n📊 FINAL POSTFLIGHT SUMMARY"
Write-Host "VMs:     $($audit.VMCount)"
Write-Host "Folders: $($audit.FolderCount)"
Write-Host "Empty:   $($audit.EmptyFolders.Count)"
Write-Host "`n🎯 Migration complete"

$null = [void]$audit
$null = $null