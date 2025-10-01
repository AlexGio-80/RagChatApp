# Multi-Provider Installation Guide

## Quick Start

### Basic Installation (No API Keys)
```powershell
cd C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\StoredProcedures
.\Install-MultiProvider.ps1
```

This will:
- Install all core multi-provider stored procedures
- Install simplified RAG procedures
- Create configuration table
- Use default values (mock mode for testing)

### Installation with Gemini API Key
```powershell
.\Install-MultiProvider.ps1 `
    -GeminiApiKey "AIzaSyDUe74NImCUqMazYXgGdMA30e80QIvZENk" `
    -TestAfterInstall
```

This will:
- Install all procedures
- Configure Gemini with your API key
- Run tests to verify installation

### Full Installation with All Providers
```powershell
.\Install-MultiProvider.ps1 `
    -OpenAIApiKey "sk-your-openai-key" `
    -GeminiApiKey "AIzaSy-your-gemini-key" `
    -AzureOpenAIApiKey "your-azure-key" `
    -AzureOpenAIEndpoint "https://your-resource.openai.azure.com" `
    -AzureOpenAIDeployment "text-embedding-ada-002" `
    -TestAfterInstall
```

## Script Parameters

### Connection Parameters
- `ServerName` (default: "DEV-ALEX\MSSQLSERVER01") - SQL Server instance
- `DatabaseName` (default: "OSL_AI") - Target database
- `AuthenticationType` (default: "Integrated") - "Integrated" or "SqlAuth"
- `Username` - SQL authentication username (if using SqlAuth)
- `Password` - SQL authentication password (if using SqlAuth)

### AI Provider Configuration
- `OpenAIApiKey` - OpenAI API key
- `OpenAIBaseUrl` (default: "https://api.openai.com/v1") - OpenAI endpoint
- `OpenAIModel` (default: "text-embedding-3-small") - OpenAI model

- `GeminiApiKey` - Google Gemini API key
- `GeminiBaseUrl` (default: "https://generativelanguage.googleapis.com/v1beta") - Gemini endpoint
- `GeminiModel` (default: "models/embedding-001") - Gemini model

- `AzureOpenAIApiKey` - Azure OpenAI API key
- `AzureOpenAIEndpoint` - Azure OpenAI endpoint URL
- `AzureOpenAIDeployment` (default: "text-embedding-ada-002") - Deployment name

### Installation Options
- `InstallSimplifiedProcedures` (default: $true) - Install simplified RAG procedures
- `InstallApiKeyProcedures` (default: $true) - Install API key procedures
- `SkipConfiguration` (default: $false) - Skip creating configuration table
- `TestAfterInstall` (switch) - Run tests after installation

## Usage Examples

### Example 1: Different Server/Database
```powershell
.\Install-MultiProvider.ps1 `
    -ServerName "PROD-SQL\INSTANCE01" `
    -DatabaseName "Production_RAG" `
    -GeminiApiKey "your-key"
```

### Example 2: SQL Authentication
```powershell
.\Install-MultiProvider.ps1 `
    -ServerName "remote-server" `
    -DatabaseName "RAG_DB" `
    -AuthenticationType "SqlAuth" `
    -Username "rag_admin" `
    -Password "secure_password" `
    -GeminiApiKey "your-key"
```

### Example 3: Skip Configuration (Manual Setup Later)
```powershell
.\Install-MultiProvider.ps1 `
    -SkipConfiguration
```

Then manually configure later:
```sql
-- Insert API keys manually
INSERT INTO AIProviderConfiguration (ProviderName, ApiKey, BaseUrl, Model, IsActive)
VALUES ('Gemini', 'your-api-key', 'https://generativelanguage.googleapis.com/v1beta', 'models/embedding-001', 1);
```

### Example 4: Only Core Procedures (No Simplified)
```powershell
.\Install-MultiProvider.ps1 `
    -InstallSimplifiedProcedures:$false `
    -InstallApiKeyProcedures:$false
```

## What Gets Installed

### Core Multi-Provider Procedures
1. **SP_GenerateEmbedding_MultiProvider** - Generate embeddings with any provider
2. **SP_GenerateMockEmbedding** - Mock embeddings for testing
3. **SP_GetProviderConfiguration** - Get provider configurations
4. **SP_TestAllProviders** - Test all configured providers
5. **SP_RAGSearch_MultiProvider** - Enhanced RAG search

### Simplified RAG Procedures (Use Encrypted Configuration)
6. **SP_GetDataForLLM_OpenAI** - Simple RAG search (reads encrypted API key)
7. **SP_GetDataForLLM_Gemini** - Simple RAG search (reads encrypted API key)
8. **SP_GetDataForLLM_AzureOpenAI** - Simple RAG search (reads encrypted API key)

### Simplified RAG Procedures (With API Key Parameter)
9. **SP_GetDataForLLM_OpenAI_WithKey** - RAG search with API key parameter
10. **SP_GetDataForLLM_Gemini_WithKey** - RAG search with API key parameter
11. **SP_GetDataForLLM_AzureOpenAI_WithKey** - RAG search with full configuration

### Encrypted Configuration System
12. **AIProviderConfiguration** Table - Stores encrypted API keys (ApiKeyEncrypted)
13. **SP_UpsertProviderConfiguration** - Insert/update with automatic encryption
14. **SP_GetDecryptedApiKey** - Decrypt API key (internal use)
15. **SP_GetProviderConfig** - Get configuration (API keys masked)
16. **vw_AIProviderConfiguration** View - Safe view with masked keys
17. **Database Master Key** - AES-256 encryption
18. **Certificate & Symmetric Key** - Encryption infrastructure

## Post-Installation

### Verify Installation
```sql
-- Check installed procedures
SELECT ROUTINE_NAME
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE'
  AND (ROUTINE_NAME LIKE '%MultiProvider%' OR ROUTINE_NAME LIKE 'SP_GetDataForLLM%')
ORDER BY ROUTINE_NAME;

-- Check configuration
SELECT * FROM AIProviderConfiguration;
```

### Test with Gemini
```sql
EXEC SP_GetDataForLLM_Gemini_WithKey
    @SearchText = 'test query',
    @ApiKey = 'your-gemini-api-key',
    @TopK = 5;
```

### Update Configuration Later
```sql
-- Update API key
UPDATE AIProviderConfiguration
SET ApiKey = 'new-api-key', UpdatedAt = GETUTCDATE()
WHERE ProviderName = 'Gemini';

-- Enable/disable provider
UPDATE AIProviderConfiguration
SET IsActive = 0
WHERE ProviderName = 'OpenAI';
```

## Troubleshooting

### Issue: Permission Denied
**Solution:** Run PowerShell as Administrator or grant appropriate SQL permissions
```powershell
# Run as Administrator
Start-Process powershell -Verb runAs
```

### Issue: Script Execution Policy
**Solution:** Allow script execution
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: Connection Failed
**Solution:** Verify server name and authentication
```powershell
# Test connection manually
sqlcmd -S "DEV-ALEX\MSSQLSERVER01" -d "OSL_AI" -Q "SELECT DB_NAME()"
```

### Issue: Table Already Exists
**Solution:** This is normal if reinstalling. The script will update existing configurations.

### Issue: API Key Not Working
**Solution:** Verify API key and test manually
```sql
DECLARE @Embedding VARBINARY(MAX);
EXEC SP_GenerateEmbedding_MultiProvider
    @Text = 'test',
    @Provider = 'Gemini',
    @ApiKey = 'your-key',
    @Model = 'models/embedding-001',
    @Embedding = @Embedding OUTPUT;
SELECT @Embedding;
```

## Security - Encrypted API Keys (Built-in)

**✅ API keys are automatically encrypted!** The installation script (`06_EncryptedConfiguration.sql`) creates:

1. **Database Master Key** - Protects the encryption hierarchy
2. **Certificate** - Used for key encryption
3. **Symmetric Key** (AES-256) - Encrypts API keys
4. **Stored Procedures** - Manage encrypted keys transparently

### How It Works

When you insert or update a provider configuration:
```sql
EXEC SP_UpsertProviderConfiguration
    @ProviderName = 'Gemini',
    @ApiKey = 'AIzaSy-your-api-key',  -- Plain text input
    @BaseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    @Model = 'models/embedding-001';
```

The API key is:
1. **Encrypted** using AES-256 before storage
2. **Stored** as `ApiKeyEncrypted` (VARBINARY)
3. **Never stored** in plain text
4. **Decrypted** only when needed by authorized procedures

### View Configurations Safely

```sql
-- View with masked API keys
SELECT * FROM vw_AIProviderConfiguration;

-- Or use the safe procedure
EXEC SP_GetProviderConfig @ProviderName = 'Gemini';
```

Output shows:
```
ApiKeyStatus: ***ENCRYPTED***
HasApiKey: 1
```

### Decrypt API Key (Internal Use Only)

Only authorized stored procedures can decrypt:
```sql
DECLARE @ApiKey NVARCHAR(255);
EXEC SP_GetDecryptedApiKey @ProviderName = 'Gemini', @ApiKey = @ApiKey OUTPUT;
-- Used internally by RAG procedures
```

### Backup Certificate (CRITICAL!)

**⚠️ IMPORTANT:** Backup the encryption certificate immediately after installation!

```sql
-- Backup certificate and private key
BACKUP CERTIFICATE RagApiKeyCertificate
    TO FILE = 'C:\Backup\RagApiKeyCertificate.cer'
    WITH PRIVATE KEY (
        FILE = 'C:\Backup\RagApiKeyCertificate.pvk',
        ENCRYPTION BY PASSWORD = 'YourSecureBackupPassword123!'
    );
```

**Why?** If you lose the certificate:
- ❌ All encrypted API keys become permanently unrecoverable
- ❌ You'll need to reconfigure all providers
- ❌ Disaster recovery impossible

**Store backups:**
- Secure file share
- Azure Key Vault
- Encrypted USB drive
- Offline secure location

### Restore Certificate (Disaster Recovery)

If you need to restore on a different server:

```sql
-- Restore master key (if needed)
RESTORE MASTER KEY FROM FILE = 'C:\Backup\MasterKey.key'
DECRYPTION BY PASSWORD = 'OldPassword'
ENCRYPTION BY PASSWORD = 'NewPassword';

-- Restore certificate
CREATE CERTIFICATE RagApiKeyCertificate
    FROM FILE = 'C:\Backup\RagApiKeyCertificate.cer'
    WITH PRIVATE KEY (
        FILE = 'C:\Backup\RagApiKeyCertificate.pvk',
        DECRYPTION BY PASSWORD = 'YourSecureBackupPassword123!'
    );

-- Recreate symmetric key
CREATE SYMMETRIC KEY RagApiKeySymmetricKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE RagApiKeyCertificate;
```

### Use Azure Key Vault (Production Alternative)
Instead of storing keys in database, retrieve from Azure Key Vault at runtime.

### 3. Restrict Access
```sql
-- Create role for RAG procedures
CREATE ROLE RagProcedureExecutor;

-- Grant execute permissions
GRANT EXECUTE ON SP_GetDataForLLM_Gemini_WithKey TO RagProcedureExecutor;
GRANT EXECUTE ON SP_GetDataForLLM_OpenAI_WithKey TO RagProcedureExecutor;

-- Deny direct access to configuration table
DENY SELECT ON AIProviderConfiguration TO RagProcedureExecutor;

-- Add users to role
ALTER ROLE RagProcedureExecutor ADD MEMBER [your_app_user];
```

### 4. Audit API Usage
```sql
-- Create audit table
CREATE TABLE AIProviderAuditLog (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ProviderName NVARCHAR(50),
    SearchText NVARCHAR(MAX),
    UserId NVARCHAR(255),
    ExecutedAt DATETIME2 DEFAULT GETUTCDATE(),
    Success BIT,
    ErrorMessage NVARCHAR(MAX)
);

-- Modify procedures to log usage (example)
```

## Uninstallation

To remove all installed procedures:

```sql
-- Drop simplified procedures
DROP PROCEDURE IF EXISTS SP_GetDataForLLM_OpenAI;
DROP PROCEDURE IF EXISTS SP_GetDataForLLM_Gemini;
DROP PROCEDURE IF EXISTS SP_GetDataForLLM_AzureOpenAI;
DROP PROCEDURE IF EXISTS SP_GetDataForLLM_OpenAI_WithKey;
DROP PROCEDURE IF EXISTS SP_GetDataForLLM_Gemini_WithKey;
DROP PROCEDURE IF EXISTS SP_GetDataForLLM_AzureOpenAI_WithKey;

-- Drop core procedures
DROP PROCEDURE IF EXISTS SP_GenerateEmbedding_MultiProvider;
DROP PROCEDURE IF EXISTS SP_GenerateMockEmbedding;
DROP PROCEDURE IF EXISTS SP_GetProviderConfiguration;
DROP PROCEDURE IF EXISTS SP_TestAllProviders;
DROP PROCEDURE IF EXISTS SP_RAGSearch_MultiProvider;

-- Drop configuration table (optional - preserves data)
-- DROP TABLE IF EXISTS AIProviderConfiguration;
```

## Support

For issues or questions:
- Review the main README: `README_SimplifiedRAG.md`
- Check test script: `05_TestRAGWorkflow.sql`
- Examine procedure code for implementation details
- Review CLAUDE.md for project documentation

## Version History

- **v1.0** (2025-10-01) - Initial release with multi-provider support
  - Core multi-provider procedures
  - Simplified RAG procedures
  - Configuration table
  - PowerShell installation script
  - Comprehensive testing
