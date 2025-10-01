-- =============================================
-- Cleanup Existing Encryption Objects
-- =============================================
-- Run this script to remove existing encryption objects
-- and allow clean reinstallation

USE [OSL_AI]
GO

PRINT '=============================================';
PRINT 'Cleaning up existing encryption objects';
PRINT '=============================================';
PRINT '';

-- Drop view
IF EXISTS (SELECT * FROM sys.views WHERE name = 'vw_AIProviderConfiguration')
BEGIN
    DROP VIEW vw_AIProviderConfiguration;
    PRINT '✓ Dropped vw_AIProviderConfiguration';
END

-- Drop procedures
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetProviderConfig]') AND type in (N'P', N'PC'))
BEGIN
    DROP PROCEDURE [dbo].[SP_GetProviderConfig];
    PRINT '✓ Dropped SP_GetProviderConfig';
END

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetDecryptedApiKey]') AND type in (N'P', N'PC'))
BEGIN
    DROP PROCEDURE [dbo].[SP_GetDecryptedApiKey];
    PRINT '✓ Dropped SP_GetDecryptedApiKey';
END

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_UpsertProviderConfiguration]') AND type in (N'P', N'PC'))
BEGIN
    DROP PROCEDURE [dbo].[SP_UpsertProviderConfiguration];
    PRINT '✓ Dropped SP_UpsertProviderConfiguration';
END

-- Drop table (WARNING: This will delete all configuration data!)
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'AIProviderConfiguration')
BEGIN
    DROP TABLE AIProviderConfiguration;
    PRINT '✓ Dropped AIProviderConfiguration table';
END

-- Drop symmetric key
IF EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'RagApiKeySymmetricKey')
BEGIN
    DROP SYMMETRIC KEY RagApiKeySymmetricKey;
    PRINT '✓ Dropped RagApiKeySymmetricKey';
END

-- Drop certificate
IF EXISTS (SELECT * FROM sys.certificates WHERE name = 'RagApiKeyCertificate')
BEGIN
    DROP CERTIFICATE RagApiKeyCertificate;
    PRINT '✓ Dropped RagApiKeyCertificate';
END

-- Drop master key (WARNING: This affects all database encryption!)
-- Uncomment the following lines only if you want to completely reset database encryption
-- IF EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
-- BEGIN
--     DROP MASTER KEY;
--     PRINT '✓ Dropped Master Key';
-- END

PRINT '';
PRINT '=============================================';
PRINT 'Cleanup completed successfully!';
PRINT 'You can now run 06_EncryptedConfiguration.sql';
PRINT '=============================================';
