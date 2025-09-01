Write-Host "`n🛠️ MIGRATION TOOLKIT SETUP SCRIPT" -ForegroundColor Cyan
Write-Host "───────────────────────────────────────"

# Minimum PowerShell version required
$minPSVersion = [Version]"7.5"

# Check PowerShell version
Write-Host "`n🔎 Checking PowerShell version..."
if ($PSVersionTable.PSVersion -lt $minPSVersion) {
    Write-Host "❌ PowerShell version $($PSVersionTable.PSVersion) is below required $minPSVersion" -ForegroundColor Red
    Write-Host "Please install PowerShell 7.5+ from https://github.com/PowerShell/PowerShell"
    return
} else {
    Write-Host "✅ PowerShell version OK: $($PSVersionTable.PSVersion)"
}

# Check required files
$requiredFiles = @(
    "modules\ConvertTemplatesToVMModule.psm1",
    "modules\Export-FolderTreeModule.psm1",
    "modules\AuditFolderModule.psm1",
    "modules\DeltaCompareModule.psm1",
    "modules\ImportFolderTreeModule.psm1",
    "modules\MoveVMsModule.psm1",
    "modules\ConvertVMsToTemplateModule.psm1",
    "shared\migration.config.json"
)

Write-Host "`n📂 Verifying toolkit files..."
$missing = $requiredFiles | Where-Object { -not (Test-Path $_) }
if ($missing.Count -gt 0) {
    Write-Host "❌ Missing files: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "Please clone or restore these from the toolkit repo."
    return
} else {
    Write-Host "✅ All core files present."
}

# Required modules
$modules = @(
    "VMware.PowerCLI",
    "VCF.PowerCLI",
    "Microsoft.PowerShell.SecretManagement",
    "Microsoft.PowerShell.SecretStore"
)

Write-Host "`n📦 Checking required PowerShell modules..."
foreach ($m in $modules) {
    if (-not (Get-Module -ListAvailable -Name $m)) {
        Write-Host "📦 Installing: $m"
        Install-Module $m -Scope CurrentUser -SkipPublisherCheck -AllowClobber
    } else {
        Write-Host "✅ Module already installed: $m"
    }
}

# Register Vault (if missing)
Write-Host "`n🔐 Checking secret vault registration..."
if (-not (Get-SecretVault | Where-Object { $_.Name -eq "VCenterVault" })) {
    Write-Host "🔧 Registering vault: VCenterVault"
    Register-SecretVault -Name VCenterVault -ModuleName Microsoft.PowerShell.SecretStore
} else {
    Write-Host "✅ Secret vault already registered: VCenterVault"
}

# Store credentials if missing
function Test-Credential {
    param (
        [string]$Name,
        [string]$Prompt
    )
    if (-not (Get-SecretInfo | Where-Object { $_.Name -eq $Name })) {
        Write-Host "🔐 Storing credential: $Name"
        $cred = Get-Credential -Message $Prompt
        Set-Secret -Name $Name -Secret $cred
    } else {
        Write-Host "✅ Credential already stored: $Name"
    }
}

Test-Credential -Name "SourceCred" -Prompt "Enter source vCenter credentials"
Test-Credential -Name "TargetCred" -Prompt "Enter target vCenter credentials"

Write-Host "`n🧾 Verifying stored secrets..."
Get-SecretInfo | Where-Object { $_.Name -in @("SourceCred", "TargetCred") } | Format-Table Name, VaultName, LastAccessTime

Write-Host "`n🎯 Toolkit environment ready."
Write-Host "You're now set to tailor the shared\migration.config.json configuration file." -ForegroundColor Green
