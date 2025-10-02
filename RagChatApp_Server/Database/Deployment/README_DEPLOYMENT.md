# Database Deployment Guide - Production Environment

This guide is for **deploying the database in production** where the .NET development environment is **not available**.

## 📦 Package Contents

The deployment package includes all necessary SQL scripts:

```
Database/Deployment/
├── README_DEPLOYMENT.md          # This file
├── 01_DatabaseSchema.sql         # Complete database schema (auto-generated from migrations)
├── 02_StoredProcedures.sql       # (Optional) All stored procedures
└── 03_EncryptionSetup.sql        # (Optional) AES-256 API key encryption
```

## 🎯 Deployment Options

Choose the setup that matches your requirements:

### Option 1: Basic Setup (REST API Only)
- ✅ Database schema
- ✅ Application works via REST API
- ❌ No SQL stored procedures
- ❌ No encrypted API keys

### Option 2: Full SQL Interface (Recommended)
- ✅ Database schema
- ✅ REST API + SQL stored procedures
- ✅ AES-256 encrypted API keys
- ✅ External system integration via SQL

## 📋 Prerequisites

- SQL Server 2019 or later
- SQL Server Management Studio (SSMS) or Azure Data Studio
- Database with appropriate permissions:
  - `CREATE TABLE`
  - `CREATE PROCEDURE`
  - `CREATE CERTIFICATE` (for encryption option)
  - `CREATE SYMMETRIC KEY` (for encryption option)

## 🚀 Installation Steps

### Step 1: Create Database

```sql
-- Option A: Create new database
CREATE DATABASE RagChatAppDB;
GO

-- Option B: Use existing database
USE YourExistingDatabase;
GO
```

### Step 2: Run Database Schema Script

**IMPORTANT**: This script is **idempotent** - it can be run multiple times safely.

```sql
-- In SSMS or Azure Data Studio:
-- 1. Open: 01_DatabaseSchema.sql
-- 2. Ensure correct database is selected
-- 3. Execute (F5)
```

This creates:
- ✅ `Documents` table
- ✅ `DocumentChunks` table
- ✅ `DocumentChunkContentEmbeddings` table
- ✅ `DocumentChunkHeaderContextEmbeddings` table
- ✅ `DocumentChunkNotesEmbeddings` table
- ✅ `DocumentChunkDetailsEmbeddings` table
- ✅ `SemanticCache` table
- ✅ `AIProviderConfiguration` table
- ✅ All indexes and foreign keys
- ✅ `__EFMigrationsHistory` table (tracks schema version)

**Verification**:
```sql
-- Check tables created
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- Should return:
-- AIProviderConfiguration
-- DocumentChunkContentEmbeddings
-- DocumentChunkDetailsEmbeddings
-- DocumentChunkHeaderContextEmbeddings
-- DocumentChunkNotesEmbeddings
-- DocumentChunks
-- Documents
-- SemanticCache
-- __EFMigrationsHistory
```

### Step 3 (Optional): Install Stored Procedures

**Only if you need SQL interface for external systems**

```powershell
# Run PowerShell installer (includes encryption setup)
cd Database/StoredProcedures

.\Install-MultiProvider-Fixed.ps1 `
    -GeminiApiKey "your-gemini-api-key" `
    -OpenAIApiKey "your-openai-api-key" `
    -TestAfterInstall
```

This installs:
- ✅ AES-256 encryption infrastructure
- ✅ All CRUD stored procedures
- ✅ Multi-provider RAG procedures
- ✅ Encrypted API key storage
- ✅ Runs verification tests

**Manual Installation** (if PowerShell not available):
```sql
-- 1. Install encryption (required for API keys)
:r "Database/StoredProcedures/Encryption/01_CreateEncryption.sql"
GO

-- 2. Install all stored procedures
:r "Database/StoredProcedures/00_InstallAllStoredProcedures.sql"
GO

-- 3. Configure API providers
EXEC SP_UpsertProviderConfiguration
    @ProviderName = 'Gemini',
    @ApiKey = 'your-gemini-api-key',
    @BaseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    @Model = 'models/embedding-001';
```

### Step 4: Configure Application Connection String

Update the **production** `appsettings.json` (not Development):

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=YOUR_SERVER;Database=RagChatAppDB;Trusted_Connection=True;TrustServerCertificate=True;"
  }
}
```

**Connection String Examples**:

```json
// Windows Authentication
"DefaultConnection": "Server=localhost;Database=RagChatAppDB;Trusted_Connection=True;TrustServerCertificate=True;"

// SQL Server Authentication
"DefaultConnection": "Server=localhost;Database=RagChatAppDB;User Id=sa;Password=YourPassword;TrustServerCertificate=True;"

// Azure SQL Database
"DefaultConnection": "Server=tcp:yourserver.database.windows.net,1433;Database=RagChatAppDB;User Id=yourusername;Password=yourpassword;Encrypt=True;TrustServerCertificate=False;"
```

### Step 5: Verify Installation

**Application Startup**:
```bash
# The application will:
# 1. Check database schema version (__EFMigrationsHistory)
# 2. Apply any pending migrations automatically
# 3. Start API server

dotnet RagChatApp_Server.dll
```

**Database Verification**:
```sql
-- Check migration status
SELECT * FROM __EFMigrationsHistory
ORDER BY MigrationId;

-- Should show:
-- 20250916082934_InitialCreate
-- 20250929104126_ImplementMultipleEmbeddingTables
-- 20250930065546_AddMultiProviderSupport

-- Check stored procedures (if installed)
SELECT ROUTINE_NAME
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE' AND ROUTINE_NAME LIKE 'SP_%'
ORDER BY ROUTINE_NAME;

-- Check encrypted API keys (if installed)
SELECT * FROM vw_AIProviderConfiguration;
-- ApiKeyStatus should show: '***ENCRYPTED***'
```

## 🔄 Updating Existing Database

If the database already exists from a previous version:

```sql
-- 1. Backup first!
BACKUP DATABASE RagChatAppDB
TO DISK = 'C:\Backup\RagChatAppDB_BeforeUpdate.bak';

-- 2. Run the schema script (idempotent - safe to rerun)
:r "01_DatabaseSchema.sql"
GO

-- 3. Verify migrations applied
SELECT * FROM __EFMigrationsHistory ORDER BY MigrationId;
```

The application will also auto-update on startup if configured correctly.

## 🔐 Security Considerations

### API Key Encryption (Production Recommendation)

**CRITICAL**: Backup encryption certificate immediately after installation!

```sql
-- Backup certificate (MUST DO!)
BACKUP CERTIFICATE RagApiKeyCertificate
    TO FILE = 'C:\SecureBackup\RagApiKeyCertificate.cer'
    WITH PRIVATE KEY (
        FILE = 'C:\SecureBackup\RagApiKeyCertificate.pvk',
        ENCRYPTION BY PASSWORD = 'YourSecureBackupPassword123!'
    );
```

**Store backups in**:
- ✅ Azure Key Vault (recommended)
- ✅ Encrypted secure file share
- ✅ Offline secure location
- ❌ **NEVER** in source control

**Without certificate backup**: All encrypted API keys become **permanently unrecoverable** if certificate is lost.

### Connection String Security

**Production Deployment**:
```bash
# Use environment variables (recommended)
export ConnectionStrings__DefaultConnection="Server=...;Database=...;..."

# Or Azure App Service Configuration
# Settings → Configuration → Application Settings
# Add: ConnectionStrings__DefaultConnection
```

**Never commit** connection strings with credentials to source control.

## 📊 Monitoring & Maintenance

### Database Size Monitoring
```sql
-- Check database size
EXEC sp_spaceused;

-- Check table sizes
EXEC sp_MSforeachtable 'EXEC sp_spaceused ''?''';
```

### Cache Cleanup
```sql
-- Clean old cache entries (run periodically)
EXEC SP_CleanSemanticCache @MaxAgeHours = 1;

-- Get cache statistics
EXEC SP_GetSemanticCacheStats;
```

### Performance Monitoring
```sql
-- Check index usage
SELECT * FROM sys.dm_db_index_usage_stats
WHERE database_id = DB_ID('RagChatAppDB');

-- Check query performance
SELECT TOP 10
    total_elapsed_time / execution_count AS avg_time,
    text
FROM sys.dm_exec_query_stats
CROSS APPLY sys.dm_exec_sql_text(sql_handle)
ORDER BY avg_time DESC;
```

## 🆘 Troubleshooting

### Issue: Migration Already Applied Error

**Solution**: The script is idempotent - safe to rerun. If error persists:
```sql
-- Check what's applied
SELECT * FROM __EFMigrationsHistory;

-- If corrupted, rebuild:
DROP TABLE __EFMigrationsHistory;
-- Then rerun 01_DatabaseSchema.sql
```

### Issue: Permission Denied

**Solution**: Ensure user has proper permissions:
```sql
-- Grant required permissions
USE RagChatAppDB;
GO
GRANT CREATE TABLE TO [YourUser];
GRANT CREATE PROCEDURE TO [YourUser];
GRANT ALTER TO [YourUser];
```

### Issue: Encryption Setup Failed

**Solution**: Check SQL Server version and permissions:
```sql
-- Check version (need 2016+)
SELECT @@VERSION;

-- Check permissions
SELECT HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'CREATE CERTIFICATE');
```

## 📞 Support

- **Documentation**: `/Documentation/DatabaseSchemas/rag-database-schema.md`
- **Stored Procedures**: `/Database/StoredProcedures/README.md`
- **Encryption Guide**: `/Database/StoredProcedures/ENCRYPTION_UPGRADE_GUIDE.md`

## 🏷️ Version Information

- **Schema Version**: 3 migrations (InitialCreate → MultipleEmbeddings → MultiProvider)
- **Generated**: 2025-10-01
- **Compatible With**: .NET 9.0, SQL Server 2019+, Azure SQL Database
- **Last Updated**: October 1, 2025
