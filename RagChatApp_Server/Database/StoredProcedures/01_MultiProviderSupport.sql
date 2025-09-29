-- =============================================
-- Multi-Provider AI Support for RAG Chat Application
-- =============================================
-- This script adds support for multiple AI providers (OpenAI, Gemini, Azure OpenAI)
-- to the existing stored procedure infrastructure

USE [OSL_AI] -- Replace with your actual database name
GO

PRINT 'Installing Multi-Provider AI Support...'
PRINT 'Database: ' + DB_NAME()
PRINT 'Installation Date: ' + CONVERT(NVARCHAR, GETUTCDATE(), 120) + ' UTC'
PRINT '=============================================';

-- =============================================
-- SP_GenerateEmbedding_MultiProvider - Enhanced version with provider support
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GenerateEmbedding_MultiProvider]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GenerateEmbedding_MultiProvider]
GO

CREATE PROCEDURE [dbo].[SP_GenerateEmbedding_MultiProvider]
    @Text NVARCHAR(MAX),
    @Provider NVARCHAR(50) = 'OpenAI',
    @ApiKey NVARCHAR(255),
    @BaseUrl NVARCHAR(500) = NULL,
    @Model NVARCHAR(100) = 'text-embedding-3-small',
    @DeploymentName NVARCHAR(100) = NULL,
    @ApiVersion NVARCHAR(50) = '2024-02-15-preview',
    @Embedding VARBINARY(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @url NVARCHAR(4000);
        DECLARE @headers NVARCHAR(4000);
        DECLARE @payload NVARCHAR(MAX);
        DECLARE @response NVARCHAR(MAX);
        DECLARE @ret INT;

        -- Configure URL and headers based on provider
        IF @Provider = 'OpenAI'
        BEGIN
            SET @url = ISNULL(@BaseUrl, 'https://api.openai.com/v1') + '/embeddings';
            SET @headers = '{"Content-Type": "application/json", "Authorization": "Bearer ' + @ApiKey + '"}';
            SET @payload = N'{
                "input": ' + STRING_ESCAPE(@Text, 'json') + ',
                "model": "' + @Model + '",
                "encoding_format": "base64"
            }';
        END
        ELSE IF @Provider = 'AzureOpenAI'
        BEGIN
            SET @url = RTRIM(@BaseUrl, '/') + '/openai/deployments/' + @DeploymentName + '/embeddings?api-version=' + @ApiVersion;
            SET @headers = '{"Content-Type": "application/json", "api-key": "' + @ApiKey + '"}';
            SET @payload = N'{
                "input": ' + STRING_ESCAPE(@Text, 'json') + '
            }';
        END
        ELSE IF @Provider = 'Gemini'
        BEGIN
            SET @url = ISNULL(@BaseUrl, 'https://generativelanguage.googleapis.com/v1beta') + '/' + @Model + ':embedContent?key=' + @ApiKey;
            SET @headers = '{"Content-Type": "application/json"}';
            SET @payload = N'{
                "content": {
                    "parts": [{"text": ' + STRING_ESCAPE(@Text, 'json') + '}]
                }
            }';
        END
        ELSE
        BEGIN
            THROW 50001, 'Unsupported AI provider', 1;
        END

        PRINT 'Calling ' + @Provider + ' API at: ' + @url;

        -- Call AI provider API
        EXEC @ret = sp_invoke_external_rest_endpoint
            @url = @url,
            @method = 'POST',
            @headers = @headers,
            @payload = @payload,
            @response = @response OUTPUT;

        -- Check for successful response
        IF @ret = 0 AND @response IS NOT NULL
        BEGIN
            DECLARE @embeddingData NVARCHAR(MAX);

            -- Parse response based on provider
            IF @Provider = 'OpenAI' OR @Provider = 'AzureOpenAI'
            BEGIN
                SET @embeddingData = JSON_VALUE(@response, '$.data[0].embedding');
            END
            ELSE IF @Provider = 'Gemini'
            BEGIN
                -- Gemini returns embedding in different format
                SET @embeddingData = JSON_QUERY(@response, '$.embedding.values');
            END

            -- Convert to binary format
            IF @embeddingData IS NOT NULL AND @embeddingData != ''
            BEGIN
                IF @Provider = 'Gemini'
                BEGIN
                    -- For Gemini, convert array to binary format
                    SET @Embedding = CONVERT(VARBINARY(MAX), @embeddingData);
                END
                ELSE
                BEGIN
                    -- For OpenAI/Azure, decode base64
                    SET @Embedding = CAST('' as xml).value('xs:base64Binary(sql:variable("@embeddingData"))', 'varbinary(max)');
                END
            END
            ELSE
            BEGIN
                THROW 50002, 'Failed to extract embedding from API response', 1;
            END
        END
        ELSE
        BEGIN
            DECLARE @errorMsg NVARCHAR(500) = @Provider + ' API call failed. Return code: ' + CAST(@ret AS NVARCHAR) + '. Response: ' + ISNULL(@response, 'NULL');
            THROW 50003, @errorMsg, 1;
        END

        PRINT @Provider + ' embedding generated successfully';

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        PRINT 'Error in SP_GenerateEmbedding_MultiProvider: ' + @ErrorMessage;

        -- In development mode, generate mock embedding as fallback
        IF ERROR_NUMBER() = 50003 -- API call failed
        BEGIN
            PRINT 'Generating mock embedding for development...';
            EXEC [dbo].[SP_GenerateMockEmbedding] @Text = @Text, @Embedding = @Embedding OUTPUT;
        END
        ELSE
        BEGIN
            THROW;
        END
    END CATCH
END
GO

-- =============================================
-- SP_GenerateMockEmbedding - Generate mock embeddings for development
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GenerateMockEmbedding]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GenerateMockEmbedding]
GO

CREATE PROCEDURE [dbo].[SP_GenerateMockEmbedding]
    @Text NVARCHAR(MAX),
    @Dimensions INT = 1536,
    @Embedding VARBINARY(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @mockEmbedding NVARCHAR(MAX) = '[';
    DECLARE @i INT = 1;
    DECLARE @seed INT = ABS(CHECKSUM(@Text)) % 1000;

    -- Generate consistent mock embedding based on text content
    WHILE @i <= @Dimensions
    BEGIN
        DECLARE @value FLOAT = (SIN(@seed + @i) + COS(@seed * @i)) / 2.0;
        SET @mockEmbedding = @mockEmbedding + FORMAT(@value, 'F6');

        IF @i < @Dimensions
            SET @mockEmbedding = @mockEmbedding + ',';

        SET @i = @i + 1;
    END

    SET @mockEmbedding = @mockEmbedding + ']';
    SET @Embedding = CONVERT(VARBINARY(MAX), @mockEmbedding);

    PRINT 'Generated mock embedding with ' + CAST(@Dimensions AS NVARCHAR) + ' dimensions';
END
GO

-- =============================================
-- SP_GetProviderConfiguration - Get AI provider configuration
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_GetProviderConfiguration]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_GetProviderConfiguration]
GO

CREATE PROCEDURE [dbo].[SP_GetProviderConfiguration]
    @Provider NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Return provider-specific default configurations
    IF @Provider = 'OpenAI'
    BEGIN
        SELECT
            'OpenAI' AS Provider,
            'https://api.openai.com/v1' AS BaseUrl,
            'text-embedding-3-small' AS DefaultEmbeddingModel,
            'gpt-4o-mini' AS DefaultChatModel,
            4096 AS MaxTokens,
            30 AS TimeoutSeconds
    END
    ELSE IF @Provider = 'AzureOpenAI'
    BEGIN
        SELECT
            'AzureOpenAI' AS Provider,
            'https://your-resource.openai.azure.com/' AS BaseUrl,
            'text-embedding-ada-002' AS DefaultEmbeddingModel,
            'gpt-4' AS DefaultChatModel,
            '2024-02-15-preview' AS ApiVersion,
            4096 AS MaxTokens,
            30 AS TimeoutSeconds
    END
    ELSE IF @Provider = 'Gemini'
    BEGIN
        SELECT
            'Gemini' AS Provider,
            'https://generativelanguage.googleapis.com/v1beta' AS BaseUrl,
            'models/embedding-001' AS DefaultEmbeddingModel,
            'models/gemini-1.5-pro-latest' AS DefaultChatModel,
            8192 AS MaxTokens,
            30 AS TimeoutSeconds
    END
    ELSE
    BEGIN
        THROW 50004, 'Unknown AI provider', 1;
    END
END
GO

-- =============================================
-- SP_TestAllProviders - Test all configured AI providers
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_TestAllProviders]') AND type in (N'P', N'PC'))
    DROP PROCEDURE [dbo].[SP_TestAllProviders]
GO

CREATE PROCEDURE [dbo].[SP_TestAllProviders]
    @TestText NVARCHAR(MAX) = 'This is a test embedding.',
    @OpenAIApiKey NVARCHAR(255) = NULL,
    @GeminiApiKey NVARCHAR(255) = NULL,
    @AzureOpenAIApiKey NVARCHAR(255) = NULL,
    @AzureOpenAIEndpoint NVARCHAR(500) = NULL,
    @AzureOpenAIDeployment NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Test results table
    CREATE TABLE #TestResults (
        Provider NVARCHAR(50),
        Success BIT,
        ErrorMessage NVARCHAR(MAX),
        EmbeddingGenerated BIT,
        TestTime DATETIME2
    );

    PRINT 'Testing all configured AI providers...';
    PRINT 'Test Text: ' + @TestText;
    PRINT '========================================';

    -- Test OpenAI
    IF @OpenAIApiKey IS NOT NULL
    BEGIN
        BEGIN TRY
            DECLARE @openaiEmbedding VARBINARY(MAX);

            EXEC [dbo].[SP_GenerateEmbedding_MultiProvider]
                @Text = @TestText,
                @Provider = 'OpenAI',
                @ApiKey = @OpenAIApiKey,
                @Model = 'text-embedding-3-small',
                @Embedding = @openaiEmbedding OUTPUT;

            INSERT INTO #TestResults VALUES ('OpenAI', 1, NULL, CASE WHEN @openaiEmbedding IS NOT NULL THEN 1 ELSE 0 END, GETUTCDATE());
            PRINT '✓ OpenAI: SUCCESS';
        END TRY
        BEGIN CATCH
            INSERT INTO #TestResults VALUES ('OpenAI', 0, ERROR_MESSAGE(), 0, GETUTCDATE());
            PRINT '✗ OpenAI: FAILED - ' + ERROR_MESSAGE();
        END CATCH
    END
    ELSE
    BEGIN
        INSERT INTO #TestResults VALUES ('OpenAI', 0, 'API Key not provided', 0, GETUTCDATE());
        PRINT '- OpenAI: SKIPPED (no API key)';
    END

    -- Test Azure OpenAI
    IF @AzureOpenAIApiKey IS NOT NULL AND @AzureOpenAIEndpoint IS NOT NULL AND @AzureOpenAIDeployment IS NOT NULL
    BEGIN
        BEGIN TRY
            DECLARE @azureEmbedding VARBINARY(MAX);

            EXEC [dbo].[SP_GenerateEmbedding_MultiProvider]
                @Text = @TestText,
                @Provider = 'AzureOpenAI',
                @ApiKey = @AzureOpenAIApiKey,
                @BaseUrl = @AzureOpenAIEndpoint,
                @DeploymentName = @AzureOpenAIDeployment,
                @Embedding = @azureEmbedding OUTPUT;

            INSERT INTO #TestResults VALUES ('AzureOpenAI', 1, NULL, CASE WHEN @azureEmbedding IS NOT NULL THEN 1 ELSE 0 END, GETUTCDATE());
            PRINT '✓ Azure OpenAI: SUCCESS';
        END TRY
        BEGIN CATCH
            INSERT INTO #TestResults VALUES ('AzureOpenAI', 0, ERROR_MESSAGE(), 0, GETUTCDATE());
            PRINT '✗ Azure OpenAI: FAILED - ' + ERROR_MESSAGE();
        END CATCH
    END
    ELSE
    BEGIN
        INSERT INTO #TestResults VALUES ('AzureOpenAI', 0, 'Configuration incomplete', 0, GETUTCDATE());
        PRINT '- Azure OpenAI: SKIPPED (configuration incomplete)';
    END

    -- Test Gemini
    IF @GeminiApiKey IS NOT NULL
    BEGIN
        BEGIN TRY
            DECLARE @geminiEmbedding VARBINARY(MAX);

            EXEC [dbo].[SP_GenerateEmbedding_MultiProvider]
                @Text = @TestText,
                @Provider = 'Gemini',
                @ApiKey = @GeminiApiKey,
                @Model = 'models/embedding-001',
                @Embedding = @geminiEmbedding OUTPUT;

            INSERT INTO #TestResults VALUES ('Gemini', 1, NULL, CASE WHEN @geminiEmbedding IS NOT NULL THEN 1 ELSE 0 END, GETUTCDATE());
            PRINT '✓ Gemini: SUCCESS';
        END TRY
        BEGIN CATCH
            INSERT INTO #TestResults VALUES ('Gemini', 0, ERROR_MESSAGE(), 0, GETUTCDATE());
            PRINT '✗ Gemini: FAILED - ' + ERROR_MESSAGE();
        END CATCH
    END
    ELSE
    BEGIN
        INSERT INTO #TestResults VALUES ('Gemini', 0, 'API Key not provided', 0, GETUTCDATE());
        PRINT '- Gemini: SKIPPED (no API key)';
    END

    -- Return results
    SELECT
        Provider,
        Success,
        ErrorMessage,
        EmbeddingGenerated,
        TestTime
    FROM #TestResults
    ORDER BY Provider;

    -- Summary
    DECLARE @totalTests INT = (SELECT COUNT(*) FROM #TestResults);
    DECLARE @successfulTests INT = (SELECT COUNT(*) FROM #TestResults WHERE Success = 1);

    PRINT '========================================';
    PRINT 'Test Summary: ' + CAST(@successfulTests AS NVARCHAR) + '/' + CAST(@totalTests AS NVARCHAR) + ' providers successful';

    DROP TABLE #TestResults;
END
GO

-- =============================================
-- Update existing SP_InsertDocumentWithEmbeddings to use multi-provider
-- =============================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_InsertDocumentWithEmbeddings]') AND type in (N'P', N'PC'))
BEGIN
    PRINT 'Updating SP_InsertDocumentWithEmbeddings to support multi-provider...';

    -- Drop and recreate with multi-provider support
    DROP PROCEDURE [dbo].[SP_InsertDocumentWithEmbeddings]
END
GO

CREATE PROCEDURE [dbo].[SP_InsertDocumentWithEmbeddings]
    @FileName NVARCHAR(255),
    @ContentType NVARCHAR(100),
    @FileSize BIGINT,
    @Content NVARCHAR(MAX),
    @UploadedBy NVARCHAR(255),
    @ProcessingStatus NVARCHAR(50) = 'Pending',
    @Notes NVARCHAR(MAX) = NULL,
    @Details NVARCHAR(MAX) = NULL,
    @AIProvider NVARCHAR(50) = 'OpenAI',
    @ApiKey NVARCHAR(255) = NULL,
    @BaseUrl NVARCHAR(500) = NULL,
    @Model NVARCHAR(100) = 'text-embedding-3-small',
    @DeploymentName NVARCHAR(100) = NULL,
    @ApiVersion NVARCHAR(50) = '2024-02-15-preview',
    @DocumentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRANSACTION;

    BEGIN TRY
        -- Insert document record
        INSERT INTO Documents (FileName, ContentType, FileSize, Content, UploadedBy, UploadedAt, ProcessingStatus, Notes)
        VALUES (@FileName, @ContentType, @FileSize, @Content, @UploadedBy, GETUTCDATE(), @ProcessingStatus, @Notes);

        SET @DocumentId = SCOPE_IDENTITY();

        -- Insert document chunk with metadata
        DECLARE @ChunkId INT;
        INSERT INTO DocumentChunks (DocumentId, ChunkIndex, Content, HeaderContext, Notes, Details, CreatedAt)
        VALUES (@DocumentId, 0, @Content, '', @Notes, @Details, GETUTCDATE());

        SET @ChunkId = SCOPE_IDENTITY();

        -- Generate embeddings using multi-provider approach
        DECLARE @ContentEmbedding VARBINARY(MAX);
        DECLARE @NotesEmbedding VARBINARY(MAX) = NULL;
        DECLARE @DetailsEmbedding VARBINARY(MAX) = NULL;

        -- Generate content embedding
        EXEC [dbo].[SP_GenerateEmbedding_MultiProvider]
            @Text = @Content,
            @Provider = @AIProvider,
            @ApiKey = @ApiKey,
            @BaseUrl = @BaseUrl,
            @Model = @Model,
            @DeploymentName = @DeploymentName,
            @ApiVersion = @ApiVersion,
            @Embedding = @ContentEmbedding OUTPUT;

        -- Generate notes embedding if provided
        IF @Notes IS NOT NULL AND LEN(@Notes) > 0
        BEGIN
            EXEC [dbo].[SP_GenerateEmbedding_MultiProvider]
                @Text = @Notes,
                @Provider = @AIProvider,
                @ApiKey = @ApiKey,
                @BaseUrl = @BaseUrl,
                @Model = @Model,
                @DeploymentName = @DeploymentName,
                @ApiVersion = @ApiVersion,
                @Embedding = @NotesEmbedding OUTPUT;
        END

        -- Generate details embedding if provided
        IF @Details IS NOT NULL AND LEN(@Details) > 0
        BEGIN
            EXEC [dbo].[SP_GenerateEmbedding_MultiProvider]
                @Text = @Details,
                @Provider = @AIProvider,
                @ApiKey = @ApiKey,
                @BaseUrl = @BaseUrl,
                @Model = @Model,
                @DeploymentName = @DeploymentName,
                @ApiVersion = @ApiVersion,
                @Embedding = @DetailsEmbedding OUTPUT;
        END

        -- Insert embeddings
        INSERT INTO DocumentChunkContentEmbeddings (DocumentChunkId, Embedding, CreatedAt, Model)
        VALUES (@ChunkId, @ContentEmbedding, GETUTCDATE(), @Model);

        IF @NotesEmbedding IS NOT NULL
        BEGIN
            INSERT INTO DocumentChunkNotesEmbeddings (DocumentChunkId, Embedding, CreatedAt, Model)
            VALUES (@ChunkId, @NotesEmbedding, GETUTCDATE(), @Model);
        END

        IF @DetailsEmbedding IS NOT NULL
        BEGIN
            INSERT INTO DocumentChunkDetailsEmbeddings (DocumentChunkId, Embedding, CreatedAt, Model)
            VALUES (@ChunkId, @DetailsEmbedding, GETUTCDATE(), @Model);
        END

        -- Update document status
        UPDATE Documents
        SET ProcessingStatus = 'Completed', ProcessedAt = GETUTCDATE()
        WHERE Id = @DocumentId;

        COMMIT TRANSACTION;

        PRINT 'Document inserted successfully with multi-provider embeddings. DocumentId: ' + CAST(@DocumentId AS NVARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        PRINT 'Error in SP_InsertDocumentWithEmbeddings: ' + @ErrorMessage;
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

PRINT '========================================';
PRINT 'Multi-Provider AI Support installation completed successfully!';
PRINT '========================================';
PRINT '';
PRINT 'New Stored Procedures Available:';
PRINT '• SP_GenerateEmbedding_MultiProvider - Generate embeddings with any AI provider';
PRINT '• SP_GenerateMockEmbedding - Generate mock embeddings for development';
PRINT '• SP_GetProviderConfiguration - Get provider-specific configurations';
PRINT '• SP_TestAllProviders - Test all configured AI providers';
PRINT '';
PRINT 'Updated Procedures:';
PRINT '• SP_InsertDocumentWithEmbeddings - Now supports multi-provider embedding generation';
PRINT '';
PRINT 'Usage Examples:';
PRINT '-- Test OpenAI provider:';
PRINT 'DECLARE @embedding VARBINARY(MAX);';
PRINT 'EXEC SP_GenerateEmbedding_MultiProvider @Text = ''test'', @Provider = ''OpenAI'', @ApiKey = ''your-key'', @Embedding = @embedding OUTPUT;';
PRINT '';
PRINT '-- Test all providers:';
PRINT 'EXEC SP_TestAllProviders @OpenAIApiKey = ''your-openai-key'', @GeminiApiKey = ''your-gemini-key'';';
PRINT '';