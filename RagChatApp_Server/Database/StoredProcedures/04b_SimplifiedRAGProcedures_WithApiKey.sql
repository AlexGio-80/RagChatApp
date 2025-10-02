-- =============================================
-- Simplified RAG Search Procedures with API Key Parameter
-- =============================================
-- These procedures provide a simple interface for retrieving RAG data
-- with API keys passed as parameters (more secure for production)
--
-- Usage:
--   EXEC SP_GetDataForLLM_OpenAI_WithKey @SearchText = 'query', @ApiKey = 'sk-...', @TopK = 10
--   EXEC SP_GetDataForLLM_Gemini_WithKey @SearchText = 'query', @ApiKey = 'AIza...', @TopK = 10

USE [OSL_AI] -- Replace with your actual database name
GO

PRINT 'Installing Simplified RAG Search Procedures with API Key Parameters...'
PRINT 'Database: ' + DB_NAME()
PRINT 'Installation Date: ' + CONVERT(NVARCHAR, GETUTCDATE(), 120) + ' UTC'
PRINT '=============================================';

-- =============================================
-- 1. SP_GetDataForLLM_OpenAI_WithKey
-- =============================================
PRINT 'Creating SP_GetDataForLLM_OpenAI_WithKey...';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetDataForLLM_OpenAI_WithKey]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetDataForLLM_OpenAI_WithKey]
GO

CREATE PROCEDURE [dbo].[SP_GetDataForLLM_OpenAI_WithKey]
    @SearchText NVARCHAR(MAX),
    @ApiKey NVARCHAR(255),
    @TopK INT = 10,
    @BaseUrl NVARCHAR(500) = NULL,
    @Model NVARCHAR(100) = 'text-embedding-3-small',
    @IncludeMetadata BIT = 1,
    @SearchNotes BIT = 1,
    @SearchDetails BIT = 1,
    @SimilarityThreshold FLOAT = 0.6
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        PRINT 'SP_GetDataForLLM_OpenAI_WithKey: Starting RAG search with OpenAI provider';
        PRINT 'Search Text: ' + LEFT(@SearchText, 100) + CASE WHEN LEN(@SearchText) > 100 THEN '...' ELSE '' END;
        PRINT 'TopK: ' + CAST(@TopK AS NVARCHAR);
        PRINT 'Model: ' + @Model;

        -- Validate API key
        IF @ApiKey IS NULL OR LEN(@ApiKey) = 0
        BEGIN
            RAISERROR('API Key is required for OpenAI provider', 16, 1);
            RETURN;
        END

        -- Call multi-provider RAG search with OpenAI configuration
        EXEC [dbo].[SP_RAGSearch_MultiProvider]
            @QueryText = @SearchText,
            @TopK = @TopK,
            @SimilarityThreshold = @SimilarityThreshold,
            @AIProvider = 'OpenAI',
            @ApiKey = @ApiKey,
            @BaseUrl = @BaseUrl,
            @Model = @Model,
            @DeploymentName = NULL,
            @ApiVersion = NULL,
            @IncludeMetadata = @IncludeMetadata,
            @SearchNotes = @SearchNotes,
            @SearchDetails = @SearchDetails;

        PRINT 'SP_GetDataForLLM_OpenAI_WithKey: Search completed successfully';

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'SP_GetDataForLLM_OpenAI_WithKey ERROR: ' + @ErrorMessage;
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH
END
GO

PRINT '✓ SP_GetDataForLLM_OpenAI_WithKey created successfully';

-- =============================================
-- 2. SP_GetDataForLLM_Gemini_WithKey
-- =============================================
PRINT 'Creating SP_GetDataForLLM_Gemini_WithKey...';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetDataForLLM_Gemini_WithKey]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetDataForLLM_Gemini_WithKey]
GO

CREATE PROCEDURE [dbo].[SP_GetDataForLLM_Gemini_WithKey]
    @SearchText NVARCHAR(MAX),
    @ApiKey NVARCHAR(255),
    @TopK INT = 10,
    @BaseUrl NVARCHAR(500) = NULL,
    @Model NVARCHAR(100) = 'models/embedding-001',
    @IncludeMetadata BIT = 1,
    @SearchNotes BIT = 1,
    @SearchDetails BIT = 1,
    @SimilarityThreshold FLOAT = 0.6
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        PRINT 'SP_GetDataForLLM_Gemini_WithKey: Starting RAG search with Gemini provider';
        PRINT 'Search Text: ' + LEFT(@SearchText, 100) + CASE WHEN LEN(@SearchText) > 100 THEN '...' ELSE '' END;
        PRINT 'TopK: ' + CAST(@TopK AS NVARCHAR);
        PRINT 'Model: ' + @Model;

        -- Validate API key
        IF @ApiKey IS NULL OR LEN(@ApiKey) = 0
        BEGIN
            RAISERROR('API Key is required for Gemini provider', 16, 1);
            RETURN;
        END

        -- Call multi-provider RAG search with Gemini configuration
        EXEC [dbo].[SP_RAGSearch_MultiProvider]
            @QueryText = @SearchText,
            @TopK = @TopK,
            @SimilarityThreshold = @SimilarityThreshold,
            @AIProvider = 'Gemini',
            @ApiKey = @ApiKey,
            @BaseUrl = @BaseUrl,
            @Model = @Model,
            @DeploymentName = NULL,
            @ApiVersion = NULL,
            @IncludeMetadata = @IncludeMetadata,
            @SearchNotes = @SearchNotes,
            @SearchDetails = @SearchDetails;

        PRINT 'SP_GetDataForLLM_Gemini_WithKey: Search completed successfully';

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'SP_GetDataForLLM_Gemini_WithKey ERROR: ' + @ErrorMessage;
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH
END
GO

PRINT '✓ SP_GetDataForLLM_Gemini_WithKey created successfully';

-- =============================================
-- 3. SP_GetDataForLLM_AzureOpenAI_WithKey
-- =============================================
PRINT 'Creating SP_GetDataForLLM_AzureOpenAI_WithKey...';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetDataForLLM_AzureOpenAI_WithKey]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetDataForLLM_AzureOpenAI_WithKey]
GO

CREATE PROCEDURE [dbo].[SP_GetDataForLLM_AzureOpenAI_WithKey]
    @SearchText NVARCHAR(MAX),
    @ApiKey NVARCHAR(255),
    @Endpoint NVARCHAR(500),
    @DeploymentName NVARCHAR(100),
    @TopK INT = 10,
    @ApiVersion NVARCHAR(50) = '2024-02-15-preview',
    @IncludeMetadata BIT = 1,
    @SearchNotes BIT = 1,
    @SearchDetails BIT = 1,
    @SimilarityThreshold FLOAT = 0.6
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        PRINT 'SP_GetDataForLLM_AzureOpenAI_WithKey: Starting RAG search with Azure OpenAI provider';
        PRINT 'Search Text: ' + LEFT(@SearchText, 100) + CASE WHEN LEN(@SearchText) > 100 THEN '...' ELSE '' END;
        PRINT 'TopK: ' + CAST(@TopK AS NVARCHAR);
        PRINT 'Deployment: ' + @DeploymentName;

        -- Validate parameters
        IF @ApiKey IS NULL OR LEN(@ApiKey) = 0
        BEGIN
            RAISERROR('API Key is required for Azure OpenAI provider', 16, 1);
            RETURN;
        END

        IF @Endpoint IS NULL OR LEN(@Endpoint) = 0
        BEGIN
            RAISERROR('Endpoint is required for Azure OpenAI provider', 16, 1);
            RETURN;
        END

        IF @DeploymentName IS NULL OR LEN(@DeploymentName) = 0
        BEGIN
            RAISERROR('Deployment Name is required for Azure OpenAI provider', 16, 1);
            RETURN;
        END

        -- Call multi-provider RAG search with Azure OpenAI configuration
        EXEC [dbo].[SP_RAGSearch_MultiProvider]
            @QueryText = @SearchText,
            @TopK = @TopK,
            @SimilarityThreshold = @SimilarityThreshold,
            @AIProvider = 'AzureOpenAI',
            @ApiKey = @ApiKey,
            @BaseUrl = @Endpoint,
            @Model = @DeploymentName,
            @DeploymentName = @DeploymentName,
            @ApiVersion = @ApiVersion,
            @IncludeMetadata = @IncludeMetadata,
            @SearchNotes = @SearchNotes,
            @SearchDetails = @SearchDetails;

        PRINT 'SP_GetDataForLLM_AzureOpenAI_WithKey: Search completed successfully';

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'SP_GetDataForLLM_AzureOpenAI_WithKey ERROR: ' + @ErrorMessage;
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH
END
GO

PRINT '✓ SP_GetDataForLLM_AzureOpenAI_WithKey created successfully';

-- =============================================
-- Verification and Usage Examples
-- =============================================
PRINT '';
PRINT '=============================================';
PRINT 'Simplified RAG Search Procedures with API Keys installed successfully!';
PRINT '=============================================';
PRINT '';
PRINT 'Available Procedures:';
PRINT '  • SP_GetDataForLLM_OpenAI_WithKey';
PRINT '  • SP_GetDataForLLM_Gemini_WithKey';
PRINT '  • SP_GetDataForLLM_AzureOpenAI_WithKey';
PRINT '';
PRINT 'USAGE EXAMPLES:';
PRINT '=============================================';
PRINT '';
PRINT '-- OpenAI Provider:';
PRINT 'EXEC SP_GetDataForLLM_OpenAI_WithKey';
PRINT '    @SearchText = ''creazione prodotto in GP90'',';
PRINT '    @ApiKey = ''sk-your-openai-key-here'',';
PRINT '    @TopK = 10;';
PRINT '';
PRINT '-- Gemini Provider:';
PRINT 'EXEC SP_GetDataForLLM_Gemini_WithKey';
PRINT '    @SearchText = ''come creare un ordine'',';
PRINT '    @ApiKey = ''AIzaSy...-your-gemini-key-here'',';
PRINT '    @TopK = 5;';
PRINT '';
PRINT '-- Azure OpenAI Provider:';
PRINT 'EXEC SP_GetDataForLLM_AzureOpenAI_WithKey';
PRINT '    @SearchText = ''gestione magazzino'',';
PRINT '    @ApiKey = ''your-azure-key-here'',';
PRINT '    @Endpoint = ''https://your-resource.openai.azure.com'',';
PRINT '    @DeploymentName = ''text-embedding-ada-002'',';
PRINT '    @TopK = 15;';
PRINT '';
PRINT '=============================================';
PRINT 'SECURITY BEST PRACTICES:';
PRINT '  • Never hardcode API keys in stored procedures';
PRINT '  • Store API keys in encrypted configuration tables';
PRINT '  • Use application-level security to pass keys at runtime';
PRINT '  • Consider using Azure Key Vault or similar for key management';
PRINT '  • Implement proper access control on these procedures';
PRINT '';
PRINT 'Installation completed successfully!';
PRINT '=============================================';
