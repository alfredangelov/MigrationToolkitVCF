function Get-MigrationConfig {
    [CmdletBinding()]
    param (
        [string]$ConfigPath = ".\shared\migration.config.json",
        [switch]$ValidateSchema
    )

    Write-Verbose "Loading migration config from: $ConfigPath"

    if (-not (Test-Path $ConfigPath)) {
        throw "❌ Config file not found: $ConfigPath"
    }

    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -Depth 10
    } catch {
        throw "❌ Failed to parse JSON config: $($_.Exception.Message)"
    }

    # Basic validation
    $requiredProps = @('SourceVCenter', 'TargetVCenter', 'Folders')
    $missing = $requiredProps | Where-Object { -not ($config.PSObject.Properties.Name -contains $_) }
    if ($missing) {
        throw "❌ Missing required config sections: $($missing -join ', ')"
    }

    # Validate vCenter configs
    foreach ($vcType in @('SourceVCenter', 'TargetVCenter')) {
        $vc = $config.$vcType
        $requiredVcProps = @('Server', 'Datacenter', 'CredentialProfile')
        $missingVc = $requiredVcProps | Where-Object { -not ($vc.PSObject.Properties.Name -contains $_) }
        if ($missingVc) {
            throw "❌ Missing $vcType properties: $($missingVc -join ', ')"
        }
    }

    # Validate folder config
    if (-not $config.Folders.Root) {
        throw "❌ Folders.Root is required"
    }

    # Set defaults
    if (-not $config.Folders.OutputJson) {
        $config.Folders.OutputJson = "export\folder-structure.json"
    }
    if (-not $config.Folders.JsonDepth) {
        $config.Folders.JsonDepth = 100
    }

    Write-Verbose "✅ Configuration loaded and validated successfully"
    return $config
}

function Get-VCenterCredential {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$CredentialProfile,
        
        [switch]$AllowPrompt
    )

    try {
        Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
        $credential = Get-Secret -Name $CredentialProfile -ErrorAction Stop
        Write-Verbose "✅ Retrieved credential for profile: $CredentialProfile"
        return $credential
    } catch {
        if ($AllowPrompt) {
            Write-Warning "⚠️ Could not retrieve credential '$CredentialProfile' from vault, prompting for manual entry"
            return Get-Credential -Message "Enter credentials for $CredentialProfile"
        } else {
            throw "❌ Failed to retrieve credential '$CredentialProfile': $($_.Exception.Message)"
        }
    }
}

function Test-VCenterConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Server,
        
        [Parameter(Mandatory)]
        [pscredential]$Credential,
        
        [int]$TimeoutSeconds = 30
    )

    try {
        Write-Verbose "Testing connection to vCenter: $Server"
        $session = Connect-VIServer -Server $Server -Credential $Credential -ErrorAction Stop
        Write-Verbose "✅ Successfully connected to $Server"
        Disconnect-VIServer -Server $session -Confirm:$false -ErrorAction SilentlyContinue
        return $true
    } catch {
        Write-Warning "❌ Failed to connect to $Server : $($_.Exception.Message)"
        return $false
    }
}

Export-ModuleMember -Function Get-MigrationConfig, Get-VCenterCredential, Test-VCenterConnection
