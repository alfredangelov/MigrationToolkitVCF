# MigrationToolkitVCF

A PowerShell toolkit for automating the migration of VM inventory and folder structures between vCenter environments, with VCF-compatible layout and detailed auditing.

---

## Quick Start

1. **Clone the repository**

   ```powershell
   git clone https://github.com/alfredangelov/MigrationToolkitVCF.git
   cd MigrationToolkitVCF
   ```

2. **Initialize the Toolkit Environment**

   Run the setup script to verify your PowerShell version, check for required files, install necessary modules, and securely store vCenter credentials using the SecretManagement vault.

   ```powershell
   .\Initialize-MigrationToolkit.ps1
   ```

   - Checks for PowerShell 7.5+.
   - Verifies all required module and config files are present.
   - Installs PowerCLI and supporting modules if missing.
   - Registers a secure vault (`VCenterVault`) for credentials.
   - Prompts you to store source and target vCenter credentials securely.

3. **Prepare Your Migration Configuration**

   Use the provided template in the `shared/` folder as a starting point for your configuration.  
   Copy it to the shared directory and rename it to `migration.config.json`:

   ```powershell
   Copy-Item .\shared\migration.config.json.template .\shared\migration.config.json
   # Edit shared\migration.config.json with your settings
   ```

4. **Validate Your Configuration**

   Before running a migration, validate your `shared\migration.config.json` for completeness and correctness:

   ```powershell
   .\Validate-MigrationConfig.ps1
   ```

   - Checks for required fields and correct formatting in your config file.
   - Alerts you to any missing or invalid settings.

5. **Run the Migration**

   Once your environment and configuration are ready, execute the migration:

   ```powershell
   .\Run-Migration.ps1
   ```

6. **Review Output**

   - Migration and audit summaries are generated as JSON files in the `export/` folder (e.g., `export/export_metadata.json`, `export/migration-summary.json`).

---

## Project Structure

```text
MigrationToolkitVCF/
├── modules/                     # PowerShell modules
│   ├── ConfigurationModule.psm1        # Centralized config & credential handling
│   ├── AuditFolderModule.psm1
│   ├── ConvertTemplatesToVMModule.psm1
│   ├── ConvertVMsToTemplateModule.psm1
│   ├── DeltaCompareModule.psm1
│   ├── Export-FolderTreeModule.psm1
│   ├── ImportFolderTreeModule.psm1
│   └── MoveVMsModule.psm1
├── shared/                      # Configuration templates and shared files
│   ├── config-schema.json              # JSON schema for validation
│   ├── migration.config.json.template
│   └── migration.config.json    # Your actual config (not in git)
├── export/                      # All output artifacts and reports
│   ├── export_metadata.json
│   ├── folder-import-summary.json
│   ├── migration-summary.json
│   └── ...other output files
├── Initialize-MigrationToolkit.ps1
├── Run-Migration.ps1
└── Validate-MigrationConfig.ps1
```

---

## Features

- **Enhanced Configuration Management**: Centralized configuration with JSON schema validation
- **Secure Credential Handling**: Uses PowerShell SecretManagement for credential storage
- **Environment-Specific Configs**: Support for dev, staging, and production configurations
- **Robust Error Handling**: Comprehensive validation and error reporting
- Converts VM templates to VMs for migration
- Exports and audits folder trees from source vCenter
- Imports folder trees into target vCenter
- Relocates VMs to correct folders
- Converts migrated VMs back to templates
- Generates detailed migration and audit summaries in JSON format

## Configuration Features

### JSON Schema Validation

Your configuration file supports IntelliSense and validation in VS Code through the included JSON schema (`shared/config-schema.json`).

### Environment-Specific Configurations

You can maintain separate configuration files for different environments:

```powershell
# Development environment
Copy-Item .\shared\migration.config.json.template .\shared\migration.config.dev.json

# Production environment  
Copy-Item .\shared\migration.config.json.template .\shared\migration.config.prod.json

# Run with specific environment
.\Run-Migration.ps1 -ConfigPath ".\shared\migration.config.dev.json"
```

### Centralized Configuration Module

The `ConfigurationModule.psm1` provides:

- `Get-MigrationConfig`: Robust configuration loading with validation
- `Get-VCenterCredential`: Secure credential retrieval with fallback prompts
- `Test-VCenterConnection`: Connection validation utilities

## Prerequisites

- PowerShell 7.5 or later
- VMware PowerCLI modules installed
- Access to source and target vCenter environments
- A `shared\migration.config.json` file with credentials and environment details (not included in repo, use the template provided)

## Example `migration.config.json`

See `shared/migration.config.json.template` in the repository for the latest example and required fields.

```json
{
  "DryRun": true,
  "SourceVCenter": {
    "Server": "source.server.com",
    "Datacenter": "SourceDC",
    "CredentialProfile": "SourceCred"
  },
  "TargetVCenter": {
    "Server": "destination.server.com",
    "Datacenter": "DestinationDC",
    "CredentialProfile": "TargetCred"
  },
  "Folders": {
    "Root": "vm",
    "OutputJson": "folder-structure.json",
    "ReferenceJson": "reference-folder-tree.json",
    "VMMappingJson": "folder-structure.json",
    "JsonDepth": 100
  },
  "Metadata": {
    "Author": "Alfred Angelov",
    "MigrationNote": "Migrating VM inventory and folder structures from Source to Destination using VCF-compatible layout"
  },
  "ToolkitVersion": "2025.09.01"
}
```

> **Note:**  
> Do not commit your `shared\migration.config.json` or any sensitive JSON files. The `.gitignore` is configured to prevent this.

## Output Files

All output files are now organized in the `export/` folder:

- `export/export_metadata.json` — Audit and export metadata
- `export/folder-import-summary.json` — Folder import results
- `export/vm-relocation-summary.json` — VM relocation results
- `export/template-restore-summary.json` — Template restoration results
- `export/migration-summary.json` — Final migration summary

## Authors

- Alfred Angelov

---

**This toolkit is provided as-is. Test thoroughly before using, use the dryrun
