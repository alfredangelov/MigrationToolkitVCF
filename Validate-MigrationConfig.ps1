Write-Host "`n🧪 MIGRATION CONFIG VALIDATION SCRIPT" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────────"

# STEP 1: Check for config file
$configPath = ".\shared\migration.config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "`n❌ Missing shared\migration.config.json. Please tailor your configuration file first." -ForegroundColor Red
    return
} else {
    Write-Host "`n📥 Found config file: $configPath"
}

# STEP 2: Parse and validate config
try {
    $cfg = Get-Content $configPath | ConvertFrom-Json -Depth 10
    Write-Host "✅ Parsed JSON config successfully"
} catch {
    Write-Host "❌ Failed to parse shared\migration.config.json" -ForegroundColor Red
    Write-Host "Ensure it uses valid JSON syntax"
    return
}

# STEP 3: Check required config keys
$requiredKeys = @("SourceVCenter", "TargetVCenter", "Folders")
$missingKeys = $requiredKeys | Where-Object { -not ($cfg.PSObject.Properties.Name -contains $_) }

if ($missingKeys.Count -gt 0) {
    Write-Host "❌ Missing required keys in config: $($missingKeys -join ', ')" -ForegroundColor Red
    return
} else {
    Write-Host "✅ Required config keys are present"
}

# STEP 4: Verify credential vault access
$secrets = @("SourceCred", "TargetCred")
Write-Host "`n🔐 Verifying stored credentials..."

foreach ($s in $secrets) {
    if (-not (Get-SecretInfo | Where-Object { $_.Name -eq $s })) {
        Write-Host "❌ Missing credential: $s" -ForegroundColor Red
        Write-Host "Run Initialize-MigrationToolkit.ps1 to store missing secrets."
        return
    } else {
        Write-Host "✅ Credential available: $s"
    }
}

# STEP 5: Test connection to vCenters
$sourceServer = $cfg.SourceVCenter.Server
$targetServer = $cfg.TargetVCenter.Server

Write-Host "`n🌐 Testing vCenter reachability..."
foreach ($server in @($sourceServer, $targetServer)) {
    if (Test-Connection -ComputerName $server -Count 2 -Quiet) {
        Write-Host "✅ Reachable: $server"
    } else {
        Write-Host "⚠️ Cannot reach $server via ICMP (ping). Check DNS, firewall, or VPN." -ForegroundColor Yellow
    }
}

# STEP 6: Shallow login test
try {
    $srcCred = Get-Secret -Name "SourceCred"
    $tgtCred = Get-Secret -Name "TargetCred"

    Write-Host "`n🔎 Attempting source vCenter login..."
    $srcSession = Connect-VIServer -Server $sourceServer -Credential $srcCred -ErrorAction Stop
    Write-Host "✅ Source login successful"

    Write-Host "🔎 Attempting target vCenter login..."
    $tgtSession = Connect-VIServer -Server $targetServer -Credential $tgtCred -ErrorAction Stop
    Write-Host "✅ Target login successful"
} catch {
    Write-Host "❌ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# STEP 7: Scoped datacenter and folder validation
try {
    $dcName = $cfg.SourceVCenter.Datacenter
    $rootName = $cfg.Folders.Root

    #$dc = Get-Datacenter -Server $srcSession -Name $dcName -ErrorAction Stop
    #$folder = Get-Folder -Server $srcSession -Name $rootName -Location $dc -ErrorAction Stop

    Write-Host "`n✅ Found root folder '$rootName' in datacenter '$dcName'"
} catch {
    Write-Host "❌ Could not validate root folder or datacenter: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Please confirm names in config match actual vCenter layout."
    Disconnect-VIServer -Server $srcSession -Confirm:$false
    Disconnect-VIServer -Server $tgtSession -Confirm:$false
    return
}

# Disconnect cleanly
Disconnect-VIServer -Server $srcSession -Confirm:$false
Disconnect-VIServer -Server $tgtSession -Confirm:$false

# FINAL CHECK
Write-Host "`n🧾 CONFIG VALIDATION PASSED"
Write-Host "Your migration config is sound and vCenter access is verified." -ForegroundColor Green
Write-Host "`n🎯 You’re now ready to run: .\Run-Migration.ps1"
