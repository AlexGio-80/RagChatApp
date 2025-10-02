-- =============================================
-- Simplified RAG Search Procedures for Each AI Provider
-- =============================================
-- These procedures provide a simple interface for retrieving RAG data
-- with pre-configured provider settings
--
-- Usage:
--   EXEC SP_GetDataForLLM_OpenAI @SearchText = 'your query', @TopK = 10
--   EXEC SP_GetDataForLLM_Gemini @SearchText = 'your query', @TopK = 10
--   EXEC SP_GetDataForLLM_AzureOpenAI @SearchText = 'your query', @TopK = 10

USE [OSL_AI] -- Replace with your actual database name
GO

PRINT 'Installing Simplified RAG Search Procedures for LLM Integration...'
PRINT 'Database: ' + DB_NAME()
PRINT 'Installation Date: ' + CONVERT(NVARCHAR, GETUTCDATE(), 120) + ' UTC'
PRINT '=============================================';

-- =============================================
-- Configuration Section
-- =============================================
-- IMPORTANT: Update these values with your actual API keys and settings
-- before running this script in production!

-- OpenAI Configuration
DECLARE @OpenAI_ApiKey NVARCHAR(255) = 'YOUR_OPENAI_API_KEY_HERE';
DECLARE @OpenAI_BaseUrl NVARCHAR(500) = 'https://api.openai.com/v1';
DECLARE @OpenAI_Model NVARCHAR(100) = 'text-embedding-3-small';

-- Gemini Configuration
DECLARE @Gemini_ApiKey NVARCHAR(255) = 'YOUR_GEMINI_API_KEY_HERE';
DECLARE @Gemini_BaseUrl NVARCHAR(500) = 'https://generativelanguage.googleapis.com/v1beta';
DECLARE @Gemini_Model NVARCHAR(100) = 'models/embedding-001';

-- Azure OpenAI Configuration
DECLARE @AzureOpenAI_ApiKey NVARCHAR(255) = 'YOUR_AZURE_OPENAI_API_KEY_HERE';
DECLARE @AzureOpenAI_Endpoint NVARCHAR(500) = 'https://your-resource.openai.azure.com';
DECLARE @AzureOpenAI_DeploymentName NVARCHAR(100) = 'text-embedding-ada-002';
DECLARE @AzureOpenAI_ApiVersion NVARCHAR(50) = '2024-02-15-preview';

PRINT 'Configuration loaded (API keys masked for security)';
PRINT '=============================================';

-- =============================================
-- 1. SP_GetDataForLLM_OpenAI
-- =============================================
PRINT 'Creating SP_GetDataForLLM_OpenAI...';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetDataForLLM_OpenAI]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetDataForLLM_OpenAI]
GO

CREATE PROCEDURE [dbo].[SP_GetDataForLLM_OpenAI]
    @SearchText NVARCHAR(MAX),
    @TopK INT = 10,
    @IncludeMetadata BIT = 1,
    @SearchNotes BIT = 1,
    @SearchDetails BIT = 1,
    @SimilarityThreshold FLOAT = 0.6
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        PRINT 'SP_GetDataForLLM_OpenAI: Starting RAG search with OpenAI provider';
        PRINT 'Search Text: ' + LEFT(@SearchText, 100) + CASE WHEN LEN(@SearchText) > 100 THEN '...' ELSE '' END;
        PRINT 'TopK: ' + CAST(@TopK AS NVARCHAR);

        -- Get decrypted API key from configuration
        DECLARE @ApiKey NVARCHAR(255) = NULL;
        DECLARE @BaseUrl NVARCHAR(500) = NULL;
        DECLARE @Model NVARCHAR(100) = 'text-embedding-3-small';

        -- Try to get API key from encrypted configuration
        IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'SP_GetDecryptedApiKey')
        BEGIN
            EXEC SP_GetDecryptedApiKey @ProviderName = 'OpenAI', @ApiKey = @ApiKey OUTPUT;

            -- Get other configuration
            SELECT @BaseUrl = BaseUrl, @Model = ISNULL(Model, 'text-embedding-3-small')
            FROM AIProviderConfiguration
            WHERE ProviderName = 'OpenAI' AND IsActive = 1;
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

        PRINT 'SP_GetDataForLLM_OpenAI: Search completed successfully';

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'SP_GetDataForLLM_OpenAI ERROR: ' + @ErrorMessage;
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH
END
GO

PRINT '✓ SP_GetDataForLLM_OpenAI created successfully';

-- =============================================
-- 2. SP_GetDataForLLM_Gemini
-- =============================================
PRINT 'Creating SP_GetDataForLLM_Gemini...';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetDataForLLM_Gemini]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetDataForLLM_Gemini]
GO

CREATE PROCEDURE [dbo].[SP_GetDataForLLM_Gemini]
    @SearchText NVARCHAR(MAX),
    @TopK INT = 10,
    @IncludeMetadata BIT = 1,
    @SearchNotes BIT = 1,
    @SearchDetails BIT = 1,
    @SimilarityThreshold FLOAT = 0.6
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        PRINT 'SP_GetDataForLLM_Gemini: Starting RAG search with Gemini provider';
        PRINT 'Search Text: ' + LEFT(@SearchText, 100) + CASE WHEN LEN(@SearchText) > 100 THEN '...' ELSE '' END;
        PRINT 'TopK: ' + CAST(@TopK AS NVARCHAR);

        -- Get decrypted API key from configuration
        DECLARE @ApiKey NVARCHAR(255) = NULL;
        DECLARE @BaseUrl NVARCHAR(500) = NULL;
        DECLARE @Model NVARCHAR(100) = 'models/embedding-001';

        -- Try to get API key from encrypted configuration
        IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'SP_GetDecryptedApiKey')
        BEGIN
            EXEC SP_GetDecryptedApiKey @ProviderName = 'Gemini', @ApiKey = @ApiKey OUTPUT;

            -- Get other configuration
            SELECT @BaseUrl = BaseUrl, @Model = ISNULL(Model, 'models/embedding-001')
            FROM AIProviderConfiguration
            WHERE ProviderName = 'Gemini' AND IsActive = 1;
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

        PRINT 'SP_GetDataForLLM_Gemini: Search completed successfully';

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'SP_GetDataForLLM_Gemini ERROR: ' + @ErrorMessage;
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH
END
GO

PRINT '✓ SP_GetDataForLLM_Gemini created successfully';

-- =============================================
-- 3. SP_GetDataForLLM_AzureOpenAI
-- =============================================
PRINT 'Creating SP_GetDataForLLM_AzureOpenAI...';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetDataForLLM_AzureOpenAI]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetDataForLLM_AzureOpenAI]
GO

CREATE PROCEDURE [dbo].[SP_GetDataForLLM_AzureOpenAI]
    @SearchText NVARCHAR(MAX),
    @TopK INT = 10,
    @IncludeMetadata BIT = 1,
    @SearchNotes BIT = 1,
    @SearchDetails BIT = 1,
    @SimilarityThreshold FLOAT = 0.6
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        PRINT 'SP_GetDataForLLM_AzureOpenAI: Starting RAG search with Azure OpenAI provider';
        PRINT 'Search Text: ' + LEFT(@SearchText, 100) + CASE WHEN LEN(@SearchText) > 100 THEN '...' ELSE '' END;
        PRINT 'TopK: ' + CAST(@TopK AS NVARCHAR);

        -- Get decrypted API key from configuration
        DECLARE @ApiKey NVARCHAR(255) = NULL;
        DECLARE @BaseUrl NVARCHAR(500) = NULL;
        DECLARE @Model NVARCHAR(100) = 'text-embedding-ada-002';
        DECLARE @DeploymentName NVARCHAR(100) = 'text-embedding-ada-002';
        DECLARE @ApiVersion NVARCHAR(50) = '2024-02-15-preview';

        -- Try to get API key from encrypted configuration
        IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'SP_GetDecryptedApiKey')
        BEGIN
            EXEC SP_GetDecryptedApiKey @ProviderName = 'AzureOpenAI', @ApiKey = @ApiKey OUTPUT;

            -- Get other configuration
            SELECT
                @BaseUrl = BaseUrl,
                @Model = ISNULL(Model, 'text-embedding-ada-002'),
                @DeploymentName = ISNULL(DeploymentName, 'text-embedding-ada-002'),
                @ApiVersion = ISNULL(ApiVersion, '2024-02-15-preview')
            FROM AIProviderConfiguration
            WHERE ProviderName = 'AzureOpenAI' AND IsActive = 1;
        END

        -- Call multi-provider RAG search with Azure OpenAI configuration
        EXEC [dbo].[SP_RAGSearch_MultiProvider]
            @QueryText = @SearchText,
            @TopK = @TopK,
            @SimilarityThreshold = @SimilarityThreshold,
            @AIProvider = 'AzureOpenAI',
            @ApiKey = @ApiKey,
            @BaseUrl = @BaseUrl,
            @Model = @Model,
            @DeploymentName = @DeploymentName,
            @ApiVersion = @ApiVersion,
            @IncludeMetadata = @IncludeMetadata,
            @SearchNotes = @SearchNotes,
            @SearchDetails = @SearchDetails;

        PRINT 'SP_GetDataForLLM_AzureOpenAI: Search completed successfully';

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'SP_GetDataForLLM_AzureOpenAI ERROR: ' + @ErrorMessage;
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH
END
GO

PRINT '✓ SP_GetDataForLLM_AzureOpenAI created successfully';

-- =============================================
-- Verification and Usage Examples
-- =============================================
PRINT '';
PRINT '=============================================';
PRINT 'Simplified RAG Search Procedures installed successfully!';
PRINT '=============================================';
PRINT '';
PRINT 'Available Procedures:';
PRINT '  • SP_GetDataForLLM_OpenAI';
PRINT '  • SP_GetDataForLLM_Gemini';
PRINT '  • SP_GetDataForLLM_AzureOpenAI';
PRINT '';
PRINT 'USAGE EXAMPLES:';
PRINT '=============================================';
PRINT '';
PRINT '-- OpenAI Provider (default 10 results with metadata):';
PRINT 'EXEC SP_GetDataForLLM_OpenAI';
PRINT '    @SearchText = ''creazione prodotto in GP90'',';
PRINT '    @TopK = 10;';
PRINT '';
PRINT '-- Gemini Provider (5 results without metadata):';
PRINT 'EXEC SP_GetDataForLLM_Gemini';
PRINT '    @SearchText = ''come creare un ordine'',';
PRINT '    @TopK = 5,';
PRINT '    @IncludeMetadata = 0;';
PRINT '';
PRINT '-- Azure OpenAI Provider (15 results, search only content):';
PRINT 'EXEC SP_GetDataForLLM_AzureOpenAI';
PRINT '    @SearchText = ''gestione magazzino'',';
PRINT '    @TopK = 15,';
PRINT '    @SearchNotes = 0,';
PRINT '    @SearchDetails = 0;';
PRINT '';
PRINT '=============================================';
PRINT 'PARAMETERS:';
PRINT '  @SearchText (required)      - Text to search for in documents';
PRINT '  @TopK (default: 10)         - Number of top results to return';
PRINT '  @IncludeMetadata (default: 1) - Include full metadata (dates, user, etc.)';
PRINT '  @SearchNotes (default: 1)   - Include search in notes field';
PRINT '  @SearchDetails (default: 1) - Include search in details field';
PRINT '  @SimilarityThreshold (default: 0.7) - Minimum similarity score';
PRINT '';
PRINT '=============================================';
PRINT 'RETURNED COLUMNS (when @IncludeMetadata = 1):';
PRINT '  • DocumentId        - Unique document identifier';
PRINT '  • DocumentChunkId   - Unique chunk identifier';
PRINT '  • FileName          - Original document filename';
PRINT '  • Content           - Document chunk content';
PRINT '  • HeaderContext     - Document section/header context';
PRINT '  • Notes             - User notes associated with chunk';
PRINT '  • Details           - Additional metadata (JSON format)';
PRINT '  • MaxSimilarity     - Highest similarity score for this chunk';
PRINT '  • MatchedFields     - Which fields matched (Content, Notes, Details)';
PRINT '  • ChunkIndex        - Position of chunk in document';
PRINT '  • UploadedBy        - User who uploaded the document';
PRINT '  • UploadedAt        - Upload timestamp';
PRINT '  • ProcessedAt       - Processing completion timestamp';
PRINT '';
PRINT 'RETURNED COLUMNS (when @IncludeMetadata = 0):';
PRINT '  • DocumentId        - Unique document identifier';
PRINT '  • DocumentChunkId   - Unique chunk identifier';
PRINT '  • FileName          - Original document filename';
PRINT '  • Content           - Document chunk content';
PRINT '  • MaxSimilarity     - Highest similarity score for this chunk';
PRINT '  • ChunkIndex        - Position of chunk in document';
PRINT '';
PRINT '=============================================';
PRINT 'CONFIGURATION NOTES:';
PRINT '  • API keys are currently set to NULL (uses mock embeddings)';
PRINT '  • To use real AI providers, update the @ApiKey parameter';
PRINT '  • Or modify the procedures to include hardcoded keys (NOT RECOMMENDED for production)';
PRINT '  • Recommended: Store API keys in a secure configuration table';
PRINT '';
PRINT 'Installation completed successfully!';
PRINT '=============================================';
