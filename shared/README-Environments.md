# Environment-Specific Configuration Examples

## Development Environment

Copy-Item .\shared\migration.config.json.template .\shared\migration.config.dev.json

# Edit for dev environment

## Staging Environment  
Copy-Item .\shared\migration.config.json.template .\shared\migration.config.staging.json

# Edit for staging environment

## Production Environment
Copy-Item .\shared\migration.config.json.template .\shared\migration.config.prod.json

# Edit for production environment

## Usage:
# .\Run-Migration.ps1 -ConfigPath ".\shared\migration.config.dev.json"
# .\Run-Migration.ps1 -ConfigPath ".\shared\migration.config.prod.json"
