# Configuration Module Reference

## Functions

### Get-MigrationConfig

Loads and validates the migration configuration file.

```powershell
$config = Get-MigrationConfig -ConfigPath ".\shared\migration.config.json"
```

**Parameters:**

- `ConfigPath`: Path to the JSON configuration file
- `ValidateSchema`: (Optional) Perform JSON schema validation

**Returns:** Configuration object with validated structure

### Get-VCenterCredential

Retrieves vCenter credentials from the SecretManagement vault.

```powershell
$cred = Get-VCenterCredential -CredentialProfile "SourceCred" -AllowPrompt
```

**Parameters:**

- `CredentialProfile`: Name of the credential stored in the vault
- `AllowPrompt`: Allow manual credential prompt if vault retrieval fails

**Returns:** PSCredential object

### Test-VCenterConnection

Tests connectivity to a vCenter server.

```powershell
$isConnected = Test-VCenterConnection -Server "vcenter.domain.com" -Credential $cred
```

**Parameters:**

- `Server`: vCenter server FQDN or IP
- `Credential`: PSCredential object
- `TimeoutSeconds`: Connection timeout (default: 30)

**Returns:** Boolean indicating connection success

## Usage Examples

### Basic Configuration Loading

```powershell
Import-Module .\modules\ConfigurationModule.psm1

try {
    $config = Get-MigrationConfig -ConfigPath ".\shared\migration.config.json"
    $sourceCred = Get-VCenterCredential -CredentialProfile $config.SourceVCenter.CredentialProfile
    
    if (Test-VCenterConnection -Server $config.SourceVCenter.Server -Credential $sourceCred) {
        Write-Host "✅ Source vCenter connection verified"
    }
} catch {
    Write-Error "Configuration error: $($_.Exception.Message)"
}
```

### Environment-Specific Configuration

```powershell
# Load development configuration
$devConfig = Get-MigrationConfig -ConfigPath ".\shared\migration.config.dev.json"

# Load production configuration  
$prodConfig = Get-MigrationConfig -ConfigPath ".\shared\migration.config.prod.json"
```

## Error Handling

The configuration module provides comprehensive error handling:

- **File not found**: Clear error message with file path
- **JSON parsing errors**: Detailed parsing error information
- **Missing required properties**: Lists all missing required fields
- **Credential retrieval failures**: Automatic fallback to manual prompt (when AllowPrompt is used)
- **Connection failures**: Detailed connection error information

## Benefits

1. **Centralized Logic**: All configuration and credential handling in one place
2. **Consistent Error Handling**: Standardized error messages and handling
3. **Validation**: Automatic validation of required configuration properties
4. **Security**: Secure credential handling with vault integration
5. **Flexibility**: Support for multiple environments and manual fallbacks
