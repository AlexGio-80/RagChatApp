-- =============================================
-- Encrypted AI Provider Configuration System
-- =============================================
-- This script creates a secure configuration system with encrypted API keys
-- using SQL Server's built-in encryption features

USE [OSL_AI] -- Replace with your actual database name
GO

PRINT '=============================================';
PRINT 'Installing Encrypted Configuration System';
PRINT '=============================================';
PRINT 'Database: ' + DB_NAME();
PRINT 'Installation Date: ' + CONVERT(NVARCHAR, GETUTCDATE(), 120) + ' UTC';
PRINT '';

-- =============================================
-- Step 1: Create Master Key (if not exists)
-- =============================================
PRINT 'Step 1: Creating database master key...';

IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'RAGChatApp_MasterKey_2025!SecureP@ssw0rd#';
    PRINT '   ✓ Master key created';
END
ELSE
BEGIN
    PRINT '   Master key already exists';
END

-- =============================================
-- Step 2: Create Certificate
-- =============================================
PRINT 'Step 2: Creating certificate for API key encryption...';

IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'RagApiKeyCertificate')
BEGIN
    CREATE CERTIFICATE RagApiKeyCertificate
    WITH SUBJECT = 'RAG Chat Application API Key Encryption Certificate',
         EXPIRY_DATE = '20991231';
    PRINT '   ✓ Certificate created';
END
ELSE
BEGIN
    PRINT '   Certificate already exists';
END

-- =============================================
-- Step 3: Create Symmetric Key
-- =============================================
PRINT 'Step 3: Creating symmetric encryption key...';

IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'RagApiKeySymmetricKey')
BEGIN
    CREATE SYMMETRIC KEY RagApiKeySymmetricKey
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE RagApiKeyCertificate;
    PRINT '   ✓ Symmetric key created';
END
ELSE
BEGIN
    PRINT '   Symmetric key already exists';
END

-- =============================================
-- Step 4: Create Configuration Table
-- =============================================
PRINT 'Step 4: Creating encrypted configuration table...';

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'AIProviderConfiguration')
BEGIN
    CREATE TABLE AIProviderConfiguration (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        ProviderName NVARCHAR(50) NOT NULL UNIQUE,
        ApiKeyEncrypted VARBINARY(MAX) NULL,  -- Encrypted API key
        BaseUrl NVARCHAR(500) NULL,
        Model NVARCHAR(100) NULL,
        DeploymentName NVARCHAR(100) NULL,
        ApiVersion NVARCHAR(50) NULL,
        IsActive BIT DEFAULT 1,
        CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
        CONSTRAINT CK_AIProviderConfiguration_ProviderName CHECK (ProviderName IN ('OpenAI', 'Gemini', 'AzureOpenAI'))
    );

    CREATE INDEX IX_AIProviderConfiguration_ProviderName ON AIProviderConfiguration(ProviderName);
    CREATE INDEX IX_AIProviderConfiguration_IsActive ON AIProviderConfiguration(IsActive);

    PRINT '   ✓ Configuration table created with encrypted API key column';
END
ELSE
BEGIN
    PRINT '   Configuration table already exists';

    -- Check if ApiKeyEncrypted column exists, if not add it
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_NAME = 'AIProviderConfiguration' AND COLUMN_NAME = 'ApiKeyEncrypted')
    BEGIN
        ALTER TABLE AIProviderConfiguration ADD ApiKeyEncrypted VARBINARY(MAX) NULL;
        PRINT '   ✓ Added ApiKeyEncrypted column to existing table';
    END
END
GO

-- =============================================
-- Step 5: Stored Procedure - Insert/Update Provider Configuration
-- =============================================
PRINT 'Step 5: Creating configuration management procedures...';
GO

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_UpsertProviderConfiguration]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_UpsertProviderConfiguration]
GO

CREATE PROCEDURE [dbo].[SP_UpsertProviderConfiguration]
    @ProviderName NVARCHAR(50),
    @ApiKey NVARCHAR(255) = NULL,
    @BaseUrl NVARCHAR(500) = NULL,
    @Model NVARCHAR(100) = NULL,
    @DeploymentName NVARCHAR(100) = NULL,
    @ApiVersion NVARCHAR(50) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @EncryptedApiKey VARBINARY(MAX) = NULL;

        -- Encrypt API key if provided
        IF @ApiKey IS NOT NULL AND LEN(@ApiKey) > 0
        BEGIN
            OPEN SYMMETRIC KEY RagApiKeySymmetricKey
            DECRYPTION BY CERTIFICATE RagApiKeyCertificate;

            SET @EncryptedApiKey = EncryptByKey(Key_GUID('RagApiKeySymmetricKey'), @ApiKey);

            CLOSE SYMMETRIC KEY RagApiKeySymmetricKey;
        END

        -- Check if provider exists
        IF EXISTS (SELECT 1 FROM AIProviderConfiguration WHERE ProviderName = @ProviderName)
        BEGIN
            -- Update existing
            UPDATE AIProviderConfiguration
            SET
                ApiKeyEncrypted = COALESCE(@EncryptedApiKey, ApiKeyEncrypted),
                BaseUrl = COALESCE(@BaseUrl, BaseUrl),
                Model = COALESCE(@Model, Model),
                DeploymentName = COALESCE(@DeploymentName, DeploymentName),
                ApiVersion = COALESCE(@ApiVersion, ApiVersion),
                IsActive = @IsActive,
                UpdatedAt = GETUTCDATE()
            WHERE ProviderName = @ProviderName;

            PRINT 'Provider configuration updated: ' + @ProviderName;
        END
        ELSE
        BEGIN
            -- Insert new
            INSERT INTO AIProviderConfiguration (
                ProviderName, ApiKeyEncrypted, BaseUrl, Model,
                DeploymentName, ApiVersion, IsActive, CreatedAt, UpdatedAt
            )
            VALUES (
                @ProviderName, @EncryptedApiKey, @BaseUrl, @Model,
                @DeploymentName, @ApiVersion, @IsActive, GETUTCDATE(), GETUTCDATE()
            );

            PRINT 'Provider configuration inserted: ' + @ProviderName;
        END

        -- Return success
        SELECT
            Id, ProviderName, BaseUrl, Model, DeploymentName,
            ApiVersion, IsActive, CreatedAt, UpdatedAt,
            CASE WHEN ApiKeyEncrypted IS NOT NULL THEN 1 ELSE 0 END as HasApiKey
        FROM AIProviderConfiguration
        WHERE ProviderName = @ProviderName;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'Error in SP_UpsertProviderConfiguration: ' + @ErrorMessage;
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH
END
GO

PRINT '   ✓ SP_UpsertProviderConfiguration created';

-- =============================================
-- Step 6: Stored Procedure - Get Decrypted API Key
-- =============================================

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetDecryptedApiKey]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetDecryptedApiKey]
GO

CREATE PROCEDURE [dbo].[SP_GetDecryptedApiKey]
    @ProviderName NVARCHAR(50),
    @ApiKey NVARCHAR(255) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @EncryptedApiKey VARBINARY(MAX);

        -- Get encrypted API key
        SELECT @EncryptedApiKey = ApiKeyEncrypted
        FROM AIProviderConfiguration
        WHERE ProviderName = @ProviderName AND IsActive = 1;

        IF @EncryptedApiKey IS NULL
        BEGIN
            SET @ApiKey = NULL;
            RETURN;
        END

        -- Decrypt API key
        OPEN SYMMETRIC KEY RagApiKeySymmetricKey
        DECRYPTION BY CERTIFICATE RagApiKeyCertificate;

        SET @ApiKey = CONVERT(NVARCHAR(255), DecryptByKey(@EncryptedApiKey));

        CLOSE SYMMETRIC KEY RagApiKeySymmetricKey;

    END TRY
    BEGIN CATCH
        IF (SELECT COUNT(*) FROM sys.openkeys WHERE key_name = 'RagApiKeySymmetricKey') > 0
            CLOSE SYMMETRIC KEY RagApiKeySymmetricKey;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'Error in SP_GetDecryptedApiKey: ' + @ErrorMessage;
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH
END
GO

PRINT '   ✓ SP_GetDecryptedApiKey created';

-- =============================================
-- Step 7: Stored Procedure - Get Provider Configuration
-- =============================================

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetProviderConfig]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetProviderConfig]
GO

CREATE PROCEDURE [dbo].[SP_GetProviderConfig]
    @ProviderName NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        ProviderName,
        BaseUrl,
        Model,
        DeploymentName,
        ApiVersion,
        IsActive,
        CASE WHEN ApiKeyEncrypted IS NOT NULL THEN 1 ELSE 0 END as HasApiKey,
        CASE WHEN ApiKeyEncrypted IS NOT NULL THEN '***ENCRYPTED***' ELSE NULL END as ApiKeyStatus,
        CreatedAt,
        UpdatedAt
    FROM AIProviderConfiguration
    WHERE ProviderName = @ProviderName;
END
GO

PRINT '   ✓ SP_GetProviderConfig created';

-- =============================================
-- Step 8: View for Safe Configuration Display
-- =============================================

IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_AIProviderConfiguration')
    DROP VIEW vw_AIProviderConfiguration;
GO

CREATE VIEW vw_AIProviderConfiguration
AS
SELECT
    Id,
    ProviderName,
    BaseUrl,
    Model,
    DeploymentName,
    ApiVersion,
    IsActive,
    CASE WHEN ApiKeyEncrypted IS NOT NULL THEN 1 ELSE 0 END as HasApiKey,
    CASE WHEN ApiKeyEncrypted IS NOT NULL THEN '***ENCRYPTED***' ELSE NULL END as ApiKeyStatus,
    CreatedAt,
    UpdatedAt
FROM AIProviderConfiguration;
GO

PRINT '   ✓ vw_AIProviderConfiguration view created';

-- =============================================
-- Verification
-- =============================================
PRINT '';
PRINT '=============================================';
PRINT 'Encrypted configuration system installed successfully!';
PRINT '=============================================';
PRINT '';
PRINT 'Installed Objects:';
PRINT '   • Master Key: ##MS_DatabaseMasterKey##';
PRINT '   • Certificate: RagApiKeyCertificate';
PRINT '   • Symmetric Key: RagApiKeySymmetricKey';
PRINT '   • Table: AIProviderConfiguration (with ApiKeyEncrypted)';
PRINT '   • Procedure: SP_UpsertProviderConfiguration';
PRINT '   • Procedure: SP_GetDecryptedApiKey';
PRINT '   • Procedure: SP_GetProviderConfig';
PRINT '   • View: vw_AIProviderConfiguration';
PRINT '';
PRINT 'Usage Examples:';
PRINT '   -- Insert/Update provider with encrypted API key:';
PRINT '   EXEC SP_UpsertProviderConfiguration';
PRINT '       @ProviderName = ''Gemini'',';
PRINT '       @ApiKey = ''AIzaSy-your-api-key'',';
PRINT '       @BaseUrl = ''https://generativelanguage.googleapis.com/v1beta'',';
PRINT '       @Model = ''models/embedding-001'';';
PRINT '';
PRINT '   -- Get decrypted API key (for internal use):';
PRINT '   DECLARE @ApiKey NVARCHAR(255);';
PRINT '   EXEC SP_GetDecryptedApiKey @ProviderName = ''Gemini'', @ApiKey = @ApiKey OUTPUT;';
PRINT '   SELECT @ApiKey;';
PRINT '';
PRINT '   -- View configurations (API keys masked):';
PRINT '   SELECT * FROM vw_AIProviderConfiguration;';
PRINT '';
PRINT 'Security Notes:';
PRINT '   • API keys are encrypted using AES-256';
PRINT '   • Master key is protected by password';
PRINT '   • Only authorized procedures can decrypt keys';
PRINT '   • View shows masked API key status only';
PRINT '   • Backup master key certificate for disaster recovery!';
PRINT '';
PRINT 'IMPORTANT - Backup Certificate:';
PRINT '   BACKUP CERTIFICATE RagApiKeyCertificate';
PRINT '       TO FILE = ''C:\Backup\RagApiKeyCertificate.cer''';
PRINT '       WITH PRIVATE KEY (';
PRINT '           FILE = ''C:\Backup\RagApiKeyCertificate.pvk'',';
PRINT '           ENCRYPTION BY PASSWORD = ''YourSecureBackupPassword!''';
PRINT '       );';
PRINT '';
PRINT '=============================================';
