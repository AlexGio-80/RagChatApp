# Deployment Configuration Guide

## ⚠️ Important: Configuration Files

### Development vs Production

**`appsettings.json`** - **Production/Deployment Configuration**
- ✅ Included in published output
- ✅ Should contain generic placeholders (no real credentials)
- ✅ Environment-agnostic connection strings
- ✅ This is what gets deployed

**`appsettings.Development.json`** - **Local Development Only**
- ❌ **Excluded from published output** (configured in `.csproj`)
- ✅ Contains your local development settings
- ✅ Personal API keys, local database connections
- ✅ Ignored by Git (for security)
- ⚠️ **Never deployed** - development only

**`appsettings.Production.json`** - **Production Overrides**
- ✅ Created during deployment
- ✅ Contains production-specific settings
- ✅ Overrides values from `appsettings.json`

## Configuration Hierarchy

```
appsettings.json                    (Base - always included)
    ↓
appsettings.{Environment}.json      (Environment-specific overrides)
    ↓
Environment Variables               (Runtime overrides)
    ↓
Command Line Arguments              (Highest priority)
```

## Setup for Different Environments

### 1. Local Development

Edit `appsettings.Development.json`:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost\\SQLEXPRESS;Database=OSL_AI;Integrated Security=true;TrustServerCertificate=true"
  },
  "AIProvider": {
    "DefaultProvider": "Gemini",
    "Gemini": {
      "ApiKey": "AIzaSy-your-actual-development-key"
    }
  },
  "MockMode": {
    "Enabled": false
  }
}
```

### 2. Production/Testing Installation

Edit `appsettings.json` (or create `appsettings.Production.json`):
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=PROD_SERVER\\INSTANCE;Database=OSL_AI;Integrated Security=true;TrustServerCertificate=true"
  },
  "AIProvider": {
    "DefaultProvider": "Gemini",
    "UseEncryptedConfiguration": true
  },
  "MockMode": {
    "Enabled": false
  }
}
```

**Note**: In production, use encrypted database storage for API keys:
```powershell
cd Database/StoredProcedures
.\Install-MultiProvider-Fixed.ps1 `
    -ServerName "PROD_SERVER\INSTANCE" `
    -DatabaseName "OSL_AI" `
    -GeminiApiKey "your-production-key"
```

### 3. Publishing the Application

```powershell
# Build for production
dotnet publish -c Release -o ./publish

# Verify appsettings.Development.json is NOT included
ls ./publish/*.json
# Should only show: appsettings.json (NOT appsettings.Development.json)
```

### 4. Deployment Checklist

Before deploying:
- [ ] Verify `appsettings.json` contains only placeholders
- [ ] Verify `appsettings.Development.json` is excluded from publish
- [ ] Create `appsettings.Production.json` with production settings
- [ ] Store API keys in encrypted database (not in config files)
- [ ] Test connection string with target environment
- [ ] Set `ASPNETCORE_ENVIRONMENT=Production`

### 5. Environment Variables (Alternative)

Instead of `appsettings.Production.json`, you can use environment variables:

**Windows:**
```powershell
$env:ConnectionStrings__DefaultConnection="Server=PROD_SERVER;Database=OSL_AI;..."
$env:AIProvider__DefaultProvider="Gemini"
$env:ASPNETCORE_ENVIRONMENT="Production"
dotnet RagChatApp_Server.dll
```

**Linux/Docker:**
```bash
export ConnectionStrings__DefaultConnection="Server=PROD_SERVER;Database=OSL_AI;..."
export AIProvider__DefaultProvider="Gemini"
export ASPNETCORE_ENVIRONMENT="Production"
dotnet RagChatApp_Server.dll
```

## Security Best Practices

### ❌ Never Do This
```json
// appsettings.json (BAD - committed to Git)
{
  "AIProvider": {
    "Gemini": {
      "ApiKey": "AIzaSy-real-production-key-123456"  // ❌ NEVER!
    }
  }
}
```

### ✅ Instead Do This

**Option 1: Encrypted Database Storage (Recommended)**
```json
// appsettings.json (GOOD)
{
  "AIProvider": {
    "DefaultProvider": "Gemini",
    "UseEncryptedConfiguration": true  // ✅ Keys stored in database
  }
}
```

**Option 2: Environment Variables**
```json
// appsettings.json (GOOD)
{
  "AIProvider": {
    "Gemini": {
      "ApiKey": "placeholder-will-be-overridden"  // ✅ Placeholder only
    }
  }
}
```
```bash
# Set at runtime
export AIProvider__Gemini__ApiKey="AIzaSy-real-production-key"
```

**Option 3: Azure Key Vault / AWS Secrets Manager**
```json
{
  "KeyVault": {
    "Url": "https://your-vault.vault.azure.net/"
  }
}
```

## Common Issues

### Issue: "appsettings.Development.json appears in publish folder"

**Cause**: `.csproj` not configured to exclude Development settings

**Fix**: Add to `RagChatApp_Server.csproj`:
```xml
<ItemGroup>
  <Content Update="appsettings.Development.json" CopyToPublishDirectory="Never" />
</ItemGroup>
```

### Issue: "Connection string not found in production"

**Cause**: `appsettings.json` has placeholders, no Production config provided

**Fix**: Create `appsettings.Production.json` or use environment variables

### Issue: "Using development database in production"

**Cause**: Production config still pointing to dev database

**Fix**: Double-check `appsettings.Production.json` connection string

## Verification

After deployment, verify configuration:
```powershell
# Check which config files exist
ls *.json

# Check effective configuration (via endpoint if you add one)
curl https://your-app/api/config/verify

# Check environment
dotnet --list-runtimes
echo $ASPNETCORE_ENVIRONMENT
```

---

**Last Updated**: October 1, 2025
**Version**: 1.0.0
