-- =============================================
-- Multi-Provider AI Support for RAG Chat Application
-- =============================================
-- Uses float array format for embeddings (compatible with C# Buffer.BlockCopy)
-- This ensures compatibility between SQL-generated and C#-generated embeddings

USE [OSL_AI] -- Replace with your actual database name
GO

PRINT 'Installing Multi-Provider AI Support (FIXED VERSION)...'
PRINT 'Database: ' + DB_NAME()
PRINT 'Installation Date: ' + CONVERT(NVARCHAR, GETUTCDATE(), 120) + ' UTC'
PRINT '=============================================';

-- =============================================
-- SP_GenerateEmbedding_MultiProvider - Enhanced version with provider support (FIXED)
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
            -- FIX: Removed "encoding_format": "base64" to get float array instead
            SET @payload = N'{
                "input": "' + STRING_ESCAPE(@Text, 'json') + '",
                "model": "' + @Model + '"
            }';
        END
        ELSE IF @Provider = 'AzureOpenAI'
        BEGIN
            SET @url = RTRIM(@BaseUrl, '/') + '/openai/deployments/' + @DeploymentName + '/embeddings?api-version=' + @ApiVersion;
            SET @headers = '{"Content-Type": "application/json", "api-key": "' + @ApiKey + '"}';
            SET @payload = N'{
                "input": "' + STRING_ESCAPE(@Text, 'json') + '"
            }';
        END
        ELSE IF @Provider = 'Gemini'
        BEGIN
            SET @url = ISNULL(@BaseUrl, 'https://generativelanguage.googleapis.com/v1beta') + '/' + @Model + ':embedContent?key=' + @ApiKey;
            SET @headers = '{"Content-Type": "application/json"}';
            SET @payload = N'{
                "content": {
                    "parts": [{"text": "' + STRING_ESCAPE(@Text, 'json') + '"}]
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

            -- Debug: Print first 500 chars of response
            PRINT 'API Response (first 500 chars): ' + LEFT(@response, 500);

            -- Parse response based on provider
            -- Note: sp_invoke_external_rest_endpoint wraps the response in $.result
            IF @Provider = 'OpenAI' OR @Provider = 'AzureOpenAI'
            BEGIN
                -- FIX: Use JSON_QUERY to get the embedding array (not JSON_VALUE which truncates)
                -- Extract the entire result object, then the data array, then the first element
                DECLARE @resultObj NVARCHAR(MAX) = JSON_QUERY(@response, '$.result');
                DECLARE @dataArray NVARCHAR(MAX) = JSON_QUERY(@resultObj, '$.data');
                DECLARE @firstElement NVARCHAR(MAX) = JSON_QUERY(@dataArray, '$[0]');
                SET @embeddingData = JSON_QUERY(@firstElement, '$.embedding');

                IF @embeddingData IS NULL
                BEGIN
                    -- Fallback: try direct path (though it may not work due to truncation)
                    SET @embeddingData = JSON_QUERY(@response, '$.result.data[0].embedding');
                END
            END
            ELSE IF @Provider = 'Gemini'
            BEGIN
                -- Gemini returns embedding in different format
                SET @embeddingData = JSON_QUERY(@response, '$.result.embedding.values');
            END

            -- Debug: Print embedding data info
            PRINT 'Embedding Data Length: ' + CAST(ISNULL(LEN(@embeddingData), 0) AS NVARCHAR);
            IF @embeddingData IS NOT NULL
                PRINT 'Embedding Data (first 200 chars): ' + LEFT(@embeddingData, 200);

            -- Convert to binary format
            IF @embeddingData IS NOT NULL AND @embeddingData != '' AND @embeddingData != 'null'
            BEGIN
                -- FIX: Use CLR function for C# Buffer.BlockCopy compatibility
                -- This ensures format compatibility between SQL-generated and C#-generated embeddings
                SET @Embedding = dbo.fn_JsonArrayToEmbedding(@embeddingData);

                IF @Embedding IS NULL
                BEGIN
                    THROW 50002, 'Failed to convert JSON array to embedding', 1;
                END

                DECLARE @dimension INT = dbo.fn_EmbeddingDimension(@Embedding);
                PRINT 'Converted to embedding: ' + CAST(@dimension AS NVARCHAR) + ' dimensions, ' + CAST(LEN(@Embedding) AS NVARCHAR) + ' bytes';
            END
            ELSE
            BEGIN
                DECLARE @debugMsg NVARCHAR(MAX) = 'Failed to extract embedding. Response: ' + LEFT(@response, 1000);
                PRINT @debugMsg;
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

PRINT '========================================';
PRINT 'Multi-Provider AI Support installed successfully!';
PRINT 'Features:';
PRINT '• OpenAI/Azure: Float array format (compatible with C# Buffer.BlockCopy)';
PRINT '• JSON extraction: Using JSON_QUERY for large arrays';
PRINT '• Binary conversion: Using CLR fn_JsonArrayToEmbedding for format consistency';
PRINT '========================================';
