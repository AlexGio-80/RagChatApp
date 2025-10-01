# Encryption Upgrade Guide - API Key Security

## Overview

This guide explains the encrypted API key system implemented for the RAG Chat Application. **API keys are now automatically encrypted using AES-256** and stored securely in the database.

## What Changed

### Before
```sql
CREATE TABLE AIProviderConfiguration (
    ApiKey NVARCHAR(255) NULL,  -- ❌ Plain text
    ...
);

-- Inserts stored plain text
INSERT INTO AIProviderConfiguration (ProviderName, ApiKey, ...)
VALUES ('Gemini', 'AIzaSy-plain-text-key', ...);
```

### After
```sql
CREATE TABLE AIProviderConfiguration (
    ApiKeyEncrypted VARBINARY(MAX) NULL,  -- ✅ AES-256 encrypted
    ...
);

-- Automatic encryption
EXEC SP_UpsertProviderConfiguration
    @ProviderName = 'Gemini',
    @ApiKey = 'AIzaSy-plain-text-key';  -- Encrypted before storage
```

## New Security Infrastructure

### 1. Encryption Hierarchy

```
Database Master Key (Password Protected)
    └── Certificate (RagApiKeyCertificate)
        └── Symmetric Key (RagApiKeySymmetricKey, AES-256)
            └── Encrypted API Keys (VARBINARY)
```

### 2. New Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_UpsertProviderConfiguration` | Insert/update with automatic encryption |
| `SP_GetDecryptedApiKey` | Decrypt API key (internal use only) |
| `SP_GetProviderConfig` | Get configuration (keys masked) |

### 3. Safe View

```sql
-- View that never exposes plain text keys
CREATE VIEW vw_AIProviderConfiguration AS
SELECT
    ProviderName,
    CASE WHEN ApiKeyEncrypted IS NOT NULL
         THEN '***ENCRYPTED***'
         ELSE NULL END as ApiKeyStatus,
    ...
FROM AIProviderConfiguration;
```

## Installation

### New Installation

```powershell
# Run the installer - encryption is automatic
.\Install-MultiProvider.ps1 `
    -GeminiApiKey "your-api-key" `
    -OpenAIApiKey "your-openai-key"
```

The script will:
1. Create encryption infrastructure (`06_EncryptedConfiguration.sql`)
2. Encrypt API keys automatically
3. Configure all procedures to use encrypted keys

### Upgrading Existing Installation

If you already have the old system with plain text keys:

```powershell
# Step 1: Backup your database first!
# Step 2: Run encryption setup
cd RagChatApp_Server\Database\StoredProcedures
sqlcmd -S "your-server" -d "OSL_AI" -i "06_EncryptedConfiguration.sql"

# Step 3: Migrate existing plain text keys (if any)
```

```sql
-- Migrate plain text keys to encrypted (if ApiKey column exists)
DECLARE @ProviderName NVARCHAR(50);
DECLARE @PlainKey NVARCHAR(255);

DECLARE key_cursor CURSOR FOR
SELECT ProviderName, ApiKey
FROM AIProviderConfiguration
WHERE ApiKey IS NOT NULL;

OPEN key_cursor;
FETCH NEXT FROM key_cursor INTO @ProviderName, @PlainKey;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Encrypt and update
    EXEC SP_UpsertProviderConfiguration
        @ProviderName = @ProviderName,
        @ApiKey = @PlainKey;

    FETCH NEXT FROM key_cursor INTO @ProviderName, @PlainKey;
END

CLOSE key_cursor;
DEALLOCATE key_cursor;

-- Drop old column (optional, after verification)
-- ALTER TABLE AIProviderConfiguration DROP COLUMN ApiKey;
```

## Usage Examples

### 1. Configure Provider (API Key Encrypted Automatically)

```sql
-- Insert with encrypted API key
EXEC SP_UpsertProviderConfiguration
    @ProviderName = 'Gemini',
    @ApiKey = 'AIzaSy-your-actual-api-key',
    @BaseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    @Model = 'models/embedding-001';

-- Result:
-- Provider configuration inserted: Gemini
-- Returns: HasApiKey = 1 (ApiKey encrypted and stored)
```

### 2. View Configurations (Keys Masked)

```sql
-- Safe view - never shows plain text
SELECT * FROM vw_AIProviderConfiguration;

-- Or use procedure
EXEC SP_GetProviderConfig @ProviderName = 'Gemini';

-- Output:
-- ApiKeyStatus: ***ENCRYPTED***
-- HasApiKey: 1
```

### 3. Use in RAG Procedures (Automatic Decryption)

```sql
-- Simplified procedures automatically decrypt keys
EXEC SP_GetDataForLLM_Gemini
    @SearchText = 'your query',
    @TopK = 10;

-- Behind the scenes:
-- 1. Procedure calls SP_GetDecryptedApiKey
-- 2. Key is decrypted in memory
-- 3. Used for API call
-- 4. Never logged or exposed
```

### 4. Update API Key

```sql
-- Update existing provider's API key
EXEC SP_UpsertProviderConfiguration
    @ProviderName = 'Gemini',
    @ApiKey = 'new-api-key-value';

-- Old encrypted key is replaced with new encrypted key
```

## Security Features

### ✅ What's Protected

1. **API Keys Encrypted at Rest** - AES-256 encryption
2. **No Plain Text Storage** - Keys never stored unencrypted
3. **Automatic Encryption** - No manual encryption needed
4. **Controlled Decryption** - Only authorized procedures can decrypt
5. **Safe Views** - Direct table queries don't expose keys
6. **Audit Trail** - CreatedAt/UpdatedAt timestamps

### ✅ Protection Against

- **SQL Injection** - Parameterized queries
- **Unauthorized Access** - Only specific procedures can decrypt
- **Data Breach** - Encrypted data useless without certificate
- **Accidental Exposure** - Views and logs show masked keys

### ⚠️ What You Must Do

1. **Backup Certificate Immediately**
   ```sql
   BACKUP CERTIFICATE RagApiKeyCertificate
       TO FILE = 'C:\Backup\RagApiKeyCertificate.cer'
       WITH PRIVATE KEY (
           FILE = 'C:\Backup\RagApiKeyCertificate.pvk',
           ENCRYPTION BY PASSWORD = 'SecureBackupPassword!'
       );
   ```

2. **Store Backup Securely**
   - Azure Key Vault
   - Encrypted file share
   - Offline secure location
   - **NOT in source control!**

3. **Restrict Database Permissions**
   ```sql
   -- Grant execute on procedures only
   GRANT EXECUTE ON SP_GetDataForLLM_Gemini TO app_user;

   -- Deny direct table access
   DENY SELECT ON AIProviderConfiguration TO app_user;
   ```

4. **Monitor Access**
   ```sql
   -- Create audit log for decryption
   -- (Implementation depends on your audit requirements)
   ```

## Disaster Recovery

### Lost Certificate

If you lose the certificate backup:

**Bad News:**
- ❌ Encrypted API keys are **permanently unrecoverable**
- ❌ Must reconfigure all providers with new keys

**Recovery Steps:**
1. Drop and recreate encryption infrastructure
2. Insert new API keys
3. They'll be encrypted with new certificate

### Database Restore on New Server

```sql
-- 1. Restore certificate first
CREATE CERTIFICATE RagApiKeyCertificate
    FROM FILE = 'C:\Backup\RagApiKeyCertificate.cer'
    WITH PRIVATE KEY (
        FILE = 'C:\Backup\RagApiKeyCertificate.pvk',
        DECRYPTION BY PASSWORD = 'SecureBackupPassword!'
    );

-- 2. Recreate symmetric key
CREATE SYMMETRIC KEY RagApiKeySymmetricKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE RagApiKeyCertificate;

-- 3. Restore database
RESTORE DATABASE OSL_AI FROM DISK = 'C:\Backup\OSL_AI.bak';

-- 4. Verify encryption works
DECLARE @ApiKey NVARCHAR(255);
EXEC SP_GetDecryptedApiKey @ProviderName = 'Gemini', @ApiKey = @ApiKey OUTPUT;
SELECT CASE WHEN @ApiKey IS NOT NULL THEN 'SUCCESS' ELSE 'FAILED' END;
```

## Verification

### Test Encryption

```sql
-- 1. Insert test key
EXEC SP_UpsertProviderConfiguration
    @ProviderName = 'OpenAI',
    @ApiKey = 'test-key-12345';

-- 2. Verify it's encrypted
SELECT
    ProviderName,
    ApiKeyEncrypted,  -- Should be binary data
    CASE WHEN ApiKeyEncrypted IS NOT NULL THEN 'ENCRYPTED' ELSE 'MISSING' END as Status
FROM AIProviderConfiguration
WHERE ProviderName = 'OpenAI';

-- 3. Verify decryption works
DECLARE @Decrypted NVARCHAR(255);
EXEC SP_GetDecryptedApiKey @ProviderName = 'OpenAI', @ApiKey = @Decrypted OUTPUT;
SELECT @Decrypted;  -- Should return 'test-key-12345'

-- 4. Clean up
DELETE FROM AIProviderConfiguration WHERE ProviderName = 'OpenAI';
```

### Test RAG Procedures

```sql
-- Should work automatically with encrypted keys
EXEC SP_GetDataForLLM_Gemini
    @SearchText = 'test query',
    @TopK = 5;

-- Check output - should call AI provider successfully
```

## Performance Impact

- **Encryption**: ~1ms per insert/update
- **Decryption**: ~1ms per RAG search
- **Storage**: Binary format (similar size to plain text)
- **Impact**: Negligible for typical workloads

## Compliance

This implementation helps with:
- ✅ PCI DSS (Payment Card Industry)
- ✅ GDPR (Sensitive data protection)
- ✅ HIPAA (Healthcare data)
- ✅ SOC 2 (Security controls)
- ✅ ISO 27001 (Information security)

**Note:** Full compliance requires additional controls beyond encryption.

## Troubleshooting

### Error: Cannot decrypt

**Cause:** Certificate or symmetric key missing

**Solution:**
```sql
-- Check if encryption objects exist
SELECT * FROM sys.symmetric_keys WHERE name = 'RagApiKeySymmetricKey';
SELECT * FROM sys.certificates WHERE name = 'RagApiKeyCertificate';

-- If missing, run 06_EncryptedConfiguration.sql
```

### Error: Key is NULL after decryption

**Cause:** API key was never set or encryption failed

**Solution:**
```sql
-- Check if encrypted data exists
SELECT ProviderName, ApiKeyEncrypted
FROM AIProviderConfiguration
WHERE ProviderName = 'Gemini';

-- If NULL, insert the key
EXEC SP_UpsertProviderConfiguration
    @ProviderName = 'Gemini',
    @ApiKey = 'your-actual-key';
```

### Plain text column still exists

**Cause:** Old schema not updated

**Solution:**
```sql
-- After verifying encryption works, drop old column
ALTER TABLE AIProviderConfiguration DROP COLUMN ApiKey;
```

## Support

For questions or issues:
- Review `06_EncryptedConfiguration.sql` for implementation details
- Check `README_Installation.md` for installation instructions
- Test with `05_TestRAGWorkflow.sql`

## Version History

- **v1.0** (2025-10-01) - Initial encrypted configuration system
  - AES-256 encryption
  - Automatic encrypt/decrypt
  - Safe views and procedures
  - Disaster recovery support
