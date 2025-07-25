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

   Use the provided `migration.config.json.template` as a starting point for your configuration.  
   Copy and rename it to `migration.config.json` and fill in your environment details:

   ```powershell
   Copy-Item .\migration.config.json.template .\migration.config.json
   # Edit migration.config.json with your settings
   ```

4. **Validate Your Configuration**

   Before running a migration, validate your `migration.config.json` for completeness and correctness:

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

   - Migration and audit summaries are generated as JSON files (e.g., `export_metadata.json`, `migration-summary.json`).

---

## Features

- Converts VM templates to VMs for migration
- Exports and audits folder trees from source vCenter
- Imports folder trees into target vCenter
- Relocates VMs to correct folders
- Converts migrated VMs back to templates
- Generates detailed migration and audit summaries in JSON format

## Prerequisites

- PowerShell 7.5 or later
- VMware PowerCLI modules installed
- Access to source and target vCenter environments
- A `migration.config.json` file with credentials and environment details (not included in repo, use the template provided)

## Example `migration.config.json`

See `migration.config.json.template` in the repository for the latest example and required fields.

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
  "ToolkitVersion": "2025.07.24"
}
```

> **Note:**  
> Do not commit your `migration.config.json` or any sensitive JSON files. The `.gitignore` is configured to prevent this.

## Output Files

- `export_metadata.json` — Audit and export metadata
- `folder-import-summary.json` — Folder import results
- `vm-relocation-summary.json` — VM relocation results
- `template-restore-summary.json` — Template restoration results
- `migration-summary.json` — Final migration summary

## Authors

- Alfred Angelov

---

**This toolkit is provided as-is. Test thoroughly before using, use the dryrun
