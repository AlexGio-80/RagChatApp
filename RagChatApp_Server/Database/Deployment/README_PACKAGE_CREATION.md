# Creating Deployment Packages

This guide explains how to create deployment packages for distribution to customers or production environments.

## Quick Start

```powershell
# Full package with everything (recommended)
.\Create-DeploymentPackage.ps1

# This creates:
# - Complete application binaries (compiled)
# - Database schema SQL script
# - Stored procedures (optional SQL interface)
# - Windows Service installer
# - Complete documentation
# - Deployment checklist
```

## Script Parameters

### `-OutputPath` (default: `.\DeploymentPackage`)
Where to create the package directory.

```powershell
.\Create-DeploymentPackage.ps1 -OutputPath "C:\Releases\RagChatApp_v1.0"
```

### `-IncludeApplication` (default: `$true`)
Whether to compile and include application binaries.

```powershell
# Include binaries (default - creates full package)
.\Create-DeploymentPackage.ps1 -IncludeApplication

# Skip binaries (database-only package)
.\Create-DeploymentPackage.ps1 -IncludeApplication:$false
```

### `-IncludeStoredProcedures` (default: `$true`)
Whether to include stored procedures for SQL interface.

```powershell
# Include stored procedures (default)
.\Create-DeploymentPackage.ps1 -IncludeStoredProcedures

# Skip stored procedures (REST API only)
.\Create-DeploymentPackage.ps1 -IncludeStoredProcedures:$false
```

### `-SkipBuild` (default: `$false`)
Use existing compiled binaries instead of rebuilding.

```powershell
# Rebuild application (default - ensures latest code)
.\Create-DeploymentPackage.ps1

# Use existing binaries (faster, but may be outdated)
.\Create-DeploymentPackage.ps1 -SkipBuild
```

## Common Scenarios

### Scenario 1: Full Production Package (Recommended)

**Use case**: Creating a complete package for production deployment.

```powershell
# Build everything fresh
.\Create-DeploymentPackage.ps1

# Output includes:
# - Compiled application binaries (Release build)
# - Database schema + stored procedures
# - Windows Service installer
# - Complete documentation
```

**Package size**: ~15-25 MB (depends on dependencies)

### Scenario 2: Database-Only Package

**Use case**: Customer only needs database setup, application is already deployed.

```powershell
.\Create-DeploymentPackage.ps1 -IncludeApplication:$false

# Output includes:
# - Database schema script
# - Stored procedures
# - Database documentation
```

**Package size**: ~500 KB

### Scenario 3: REST API Only Package

**Use case**: Customer doesn't need SQL interface, will use REST API exclusively.

```powershell
.\Create-DeploymentPackage.ps1 -IncludeStoredProcedures:$false

# Output includes:
# - Compiled application binaries
# - Database schema (without stored procedures)
# - Windows Service installer
# - Documentation
```

**Package size**: ~10-15 MB

### Scenario 4: Quick Package (Using Existing Build)

**Use case**: Already compiled, just need to package files quickly.

```powershell
.\Create-DeploymentPackage.ps1 -SkipBuild

# Uses existing files from:
# RagChatApp_Server\bin\Release\net9.0\publish
```

**Prerequisite**:
```powershell
cd ..\..\  # Navigate to RagChatApp_Server
dotnet publish --configuration Release
cd Database\Deployment
.\Create-DeploymentPackage.ps1 -SkipBuild
```

### Scenario 5: Custom Output Location

**Use case**: Create package in specific location (e.g., shared drive, release folder).

```powershell
.\Create-DeploymentPackage.ps1 -OutputPath "\\fileserver\releases\RagChatApp\v1.3.1"
```

## Package Structure

After running the script, you'll get:

```
DeploymentPackage/
├── 00_PRODUCTION_SETUP_GUIDE.md           # Main installation guide
├── Install-WindowsService.ps1             # Service installer
├── README.txt                             # Quick start instructions
├── DEPLOYMENT_CHECKLIST.txt               # Verification checklist
│
├── Application/                           # Application binaries
│   ├── RagChatApp_Server.exe
│   ├── RagChatApp_Server.dll
│   ├── appsettings.json                   # Template (no credentials)
│   └── ... (70+ dependency DLLs)
│
├── Database/
│   ├── 01_DatabaseSchema.sql              # Idempotent schema script
│   ├── README_DEPLOYMENT.md
│   ├── StoredProcedures/
│   │   ├── Install-MultiProvider-Fixed.ps1
│   │   ├── 00_InstallAllStoredProcedures.sql
│   │   └── ... (individual .sql files)
│   └── Encryption/
│       └── ... (encryption setup scripts)
│
└── Documentation/
    ├── rag-database-schema.md
    └── setup-configuration-guide.md
```

**Plus a ZIP file**:
```
RagChatApp_DeploymentPackage_YYYYMMDD_HHMMSS.zip
```

## Build Process Details

When `-IncludeApplication` is used (default):

1. **Clean**: Removes previous Release build
   ```powershell
   dotnet clean --configuration Release
   ```

2. **Publish**: Creates production-ready binaries
   ```powershell
   dotnet publish --configuration Release --output bin\Release\net9.0\publish
   ```

   This produces:
   - Self-contained executable (RagChatApp_Server.exe)
   - All dependencies
   - Optimized Release build
   - appsettings.json template (credentials removed)

3. **Copy**: Copies published files to package

4. **Sanitize**: Removes sensitive data
   - Replaces appsettings.json with template
   - Removes appsettings.Development.json

## Security Considerations

### Credentials Removed

The script **automatically removes** all credentials from `appsettings.json`:

**Original** (dev environment):
```json
{
  "AIProvider": {
    "Gemini": {
      "ApiKey": "AIzaSy-your-actual-dev-key"
    }
  }
}
```

**Packaged** (production template):
```json
{
  "AIProvider": {
    "Gemini": {
      "ApiKey": "YOUR-GEMINI-API-KEY-HERE"
    }
  }
}
```

### What to Check Before Distribution

1. ✅ **No credentials in appsettings.json** (script does this automatically)
2. ✅ **No `.Development.json` files** (script removes these)
3. ✅ **No encryption certificates** (`.cer`, `.pvk` files should NOT be in package)
4. ✅ **No database backups** (`.bak` files)
5. ✅ **No personal data** in test documents

## Versioning

### Recommended Naming Convention

```powershell
# Version in file name
.\Create-DeploymentPackage.ps1 -OutputPath ".\Release_v1.3.1"

# Or use date
.\Create-DeploymentPackage.ps1 -OutputPath ".\Release_2025-10-01"
```

### Version Information

Update version in:
- `RagChatApp_Server.csproj` - `<Version>1.3.1</Version>`
- Application will report version via `/api/info` endpoint

## Troubleshooting

### Error: "Application build failed"

**Cause**: Compilation errors in source code.

**Solution**:
1. Test build manually first:
   ```powershell
   cd ..\..\
   dotnet build --configuration Release
   ```
2. Fix any errors
3. Retry package creation

### Error: "Published application not found"

**Cause**: No existing build when using `-SkipBuild`.

**Solution**:
```powershell
# Either remove -SkipBuild to trigger build
.\Create-DeploymentPackage.ps1

# Or publish manually first
cd ..\..\
dotnet publish --configuration Release
cd Database\Deployment
.\Create-DeploymentPackage.ps1 -SkipBuild
```

### Package is very large (>50 MB)

**Normal size**: 15-25 MB for full package

**If larger**:
- Check for test files in Application folder
- Check for unnecessary dependencies
- Use `-IncludeStoredProcedures:$false` if not needed

## Automation

### CI/CD Integration

```powershell
# In build pipeline
param(
    [string]$Version = "1.0.0",
    [string]$OutputDir = "\\fileserver\releases"
)

cd RagChatApp_Server\Database\Deployment

# Create package
.\Create-DeploymentPackage.ps1 -OutputPath "$OutputDir\RagChatApp_v$Version"

# Rename ZIP with version
$zipFile = Get-ChildItem "RagChatApp_DeploymentPackage_*.zip" | Select-Object -First 1
Rename-Item $zipFile "RagChatApp_v$Version.zip"

Write-Host "Package created: $OutputDir\RagChatApp_v$Version.zip"
```

### Scheduled Builds

```powershell
# Weekly release build (e.g., Friday 6 PM)
# Task Scheduler: Run PowerShell script

$today = Get-Date -Format "yyyy-MM-dd"
cd C:\Source\RagChatApp\RagChatApp_Server\Database\Deployment
.\Create-DeploymentPackage.ps1 -OutputPath "C:\Releases\Weekly_$today"
```

## Post-Package Steps

After creating package:

1. ✅ **Test the package** on a clean VM
   - Extract ZIP
   - Follow `00_PRODUCTION_SETUP_GUIDE.md`
   - Verify all features work

2. ✅ **Document release notes**
   - What's new
   - Bug fixes
   - Breaking changes
   - Database schema changes

3. ✅ **Create installation instructions**
   - Already included in package
   - Customize if needed for specific customer

4. ✅ **Archive old versions**
   - Keep previous 3-5 versions
   - Document which customers use which version

## Support

For issues with package creation:
- Check build errors: `dotnet build --configuration Release`
- Verify file permissions
- Ensure adequate disk space (~1 GB for build process)
- Check PowerShell execution policy: `Get-ExecutionPolicy`

---

**Last Updated**: October 1, 2025
**Script Version**: 2.0
