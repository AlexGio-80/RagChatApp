# =============================================
# PowerShell Script to Install Multi-Provider AI Support
# =============================================
# This script installs all multi-provider stored procedures including
# simplified RAG procedures for LLM integration

param(
    [Parameter(Mandatory=$false)]
    [string]$ServerName = "DEV-ALEX\MSSQLSERVER01",

    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "OSL_AI",

    [Parameter(Mandatory=$false)]
    [string]$AuthenticationType = "Integrated", # "Integrated" or "SqlAuth"

    [Parameter(Mandatory=$false)]
    [string]$Username = "",

    [Parameter(Mandatory=$false)]
    [string]$Password = "",

    [Parameter(Mandatory=$false)]
    [switch]$TestAfterInstall = $false,

    # AI Provider API Keys (optional - can be configured later)
    [Parameter(Mandatory=$false)]
    [string]$OpenAIApiKey = "",

    [Parameter(Mandatory=$false)]
    [string]$GeminiApiKey = "",

    [Parameter(Mandatory=$false)]
    [string]$AzureOpenAIApiKey = "",

    [Parameter(Mandatory=$false)]
    [string]$AzureOpenAIEndpoint = "",

    [Parameter(Mandatory=$false)]
    [string]$AzureOpenAIDeployment = "text-embedding-ada-002",

    # Provider Configuration
    [Parameter(Mandatory=$false)]
    [string]$OpenAIBaseUrl = "https://api.openai.com/v1",

    [Parameter(Mandatory=$false)]
    [string]$OpenAIModel = "text-embedding-3-small",

    [Parameter(Mandatory=$false)]
    [string]$GeminiBaseUrl = "https://generativelanguage.googleapis.com/v1beta",

    [Parameter(Mandatory=$false)]
    [string]$GeminiModel = "models/embedding-001",

    # Installation Options
    [Parameter(Mandatory=$false)]
    [switch]$InstallSimplifiedProcedures = $true,

    [Parameter(Mandatory=$false)]
    [switch]$InstallApiKeyProcedures = $true,

    [Parameter(Mandatory=$false)]
    [switch]$SkipConfiguration = $false
)

Write-Host "=========================================================" -ForegroundColor Green
Write-Host "RAG Chat Application - Multi-Provider AI Installation" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "   Server: $ServerName" -ForegroundColor Gray
Write-Host "   Database: $DatabaseName" -ForegroundColor Gray
Write-Host "   Authentication: $AuthenticationType" -ForegroundColor Gray
Write-Host ""
Write-Host "Installation Options:" -ForegroundColor Cyan
Write-Host "   Install Simplified Procedures: $InstallSimplifiedProcedures" -ForegroundColor Gray
Write-Host "   Install API Key Procedures: $InstallApiKeyProcedures" -ForegroundColor Gray
Write-Host "   Skip Configuration: $SkipConfiguration" -ForegroundColor Gray
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Build connection string
if ($AuthenticationType -eq "Integrated") {
    $ConnectionString = "Server=$ServerName;Database=$DatabaseName;Integrated Security=True;TrustServerCertificate=True;"
} else {
    $ConnectionString = "Server=$ServerName;Database=$DatabaseName;User Id=$Username;Password=$Password;TrustServerCertificate=True;"
}

function Execute-SqlScript {
    param(
        [string]$ScriptPath,
        [string]$ConnectionString,
        [string]$DatabaseName
    )

    if (-not (Test-Path $ScriptPath)) {
        Write-Host "   File not found: $ScriptPath" -ForegroundColor Red
        return $false
    }

    try {
        Write-Host "   Executing $(Split-Path $ScriptPath -Leaf)..." -ForegroundColor Yellow

        $SqlContent = Get-Content $ScriptPath -Raw
        $SqlContent = $SqlContent -replace "USE \[OSL_AI\]", "USE [$DatabaseName]"

        $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $Connection.Open()

        # Register InfoMessage handler once for the connection
        $InfoMessageHandler = {
            param($sender, $e)
            Write-Host "      $($e.Message)" -ForegroundColor DarkGray
        }
        $Connection.add_InfoMessage($InfoMessageHandler)

        # Split script by GO statements and execute each batch
        $Batches = $SqlContent -split "(?m)^GO\s*$"
        $BatchCount = 0
        $SuccessCount = 0

        foreach ($Batch in $Batches) {
            $Batch = $Batch.Trim()
            if ($Batch.Length -gt 0 -and $Batch -notmatch "^\s*--.*$") {
                try {
                    $Command = $Connection.CreateCommand()
                    $Command.CommandText = $Batch
                    $Command.CommandTimeout = 300 # 5 minutes

                    $Result = $Command.ExecuteNonQuery()
                    $BatchCount++
                    $SuccessCount++
                } catch {
                    Write-Host "      Error in batch: $($_.Exception.Message)" -ForegroundColor Red
                    $BatchCount++
                }
            }
        }

        # Remove the handler before closing
        $Connection.remove_InfoMessage($InfoMessageHandler)
        $Connection.Close()
        Write-Host "    Completed: $SuccessCount/$BatchCount batches successful" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Install-EncryptedConfiguration {
    param(
        [string]$ConnectionString,
        [string]$DatabaseName,
        [string]$ScriptDir
    )

    Write-Host "Installing encrypted configuration system..." -ForegroundColor Cyan

    $EncryptionScript = Join-Path $ScriptDir "06_EncryptedConfiguration.sql"

    if (Test-Path $EncryptionScript) {
        $Result = Execute-SqlScript -ScriptPath $EncryptionScript -ConnectionString $ConnectionString -DatabaseName $DatabaseName

        if ($Result) {
            # Wait a moment for all objects to be fully committed
            Start-Sleep -Milliseconds 500

            # Verify that the stored procedure exists before continuing
            $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
            $Connection.Open()

            $CheckCommand = $Connection.CreateCommand()
            $CheckCommand.CommandText = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'SP_UpsertProviderConfiguration'"
            $ProcExists = $CheckCommand.ExecuteScalar()

            $Connection.Close()

            if ($ProcExists -eq 0) {
                Write-Host "   WARNING: SP_UpsertProviderConfiguration not found. Encryption installation may have failed." -ForegroundColor Yellow
                return $false
            }
        }

        return $Result
    } else {
        Write-Host "   WARNING: Encryption script not found. Creating basic table..." -ForegroundColor Yellow

        # Fallback to basic creation if script not found
        $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $Connection.Open()

        $CheckCommand = $Connection.CreateCommand()
        $CheckCommand.CommandText = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'AIProviderConfiguration'"
        $TableExists = $CheckCommand.ExecuteScalar()

        if ($TableExists -eq 0) {
            $CreateCommand = $Connection.CreateCommand()
            $CreateCommand.CommandText = @"
                CREATE TABLE AIProviderConfiguration (
                    Id INT IDENTITY(1,1) PRIMARY KEY,
                    ProviderName NVARCHAR(50) NOT NULL UNIQUE,
                    ApiKeyEncrypted VARBINARY(MAX) NULL,
                    BaseUrl NVARCHAR(500) NULL,
                    Model NVARCHAR(100) NULL,
                    DeploymentName NVARCHAR(100) NULL,
                    ApiVersion NVARCHAR(50) NULL,
                    IsActive BIT DEFAULT 1,
                    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
                    UpdatedAt DATETIME2 DEFAULT GETUTCDATE()
                );

                CREATE INDEX IX_AIProviderConfiguration_ProviderName ON AIProviderConfiguration(ProviderName);
                CREATE INDEX IX_AIProviderConfiguration_IsActive ON AIProviderConfiguration(IsActive);
"@
            $CreateCommand.ExecuteNonQuery()
            Write-Host "   [OK] Configuration table created" -ForegroundColor Green
        }

        $Connection.Close()
    }
}

function Insert-ProviderConfiguration {
    param(
        [string]$ConnectionString,
        [string]$ProviderName,
        [string]$ApiKey,
        [string]$BaseUrl,
        [string]$Model,
        [string]$DeploymentName = $null,
        [string]$ApiVersion = $null
    )

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()

    # Register InfoMessage handler once for the connection
    $InfoMessageHandler = {
        param($sender, $e)
        Write-Host "      $($e.Message)" -ForegroundColor DarkGray
    }
    $Connection.add_InfoMessage($InfoMessageHandler)

    try {
        # Use the stored procedure that handles encryption
        $UpsertCommand = $Connection.CreateCommand()
        $UpsertCommand.CommandText = "SP_UpsertProviderConfiguration"
        $UpsertCommand.CommandType = [System.Data.CommandType]::StoredProcedure

        [void]$UpsertCommand.Parameters.AddWithValue("@ProviderName", $ProviderName)
        [void]$UpsertCommand.Parameters.AddWithValue("@ApiKey", $(if ($ApiKey) { $ApiKey } else { [System.DBNull]::Value }))
        [void]$UpsertCommand.Parameters.AddWithValue("@BaseUrl", $(if ($BaseUrl) { $BaseUrl } else { [System.DBNull]::Value }))
        [void]$UpsertCommand.Parameters.AddWithValue("@Model", $(if ($Model) { $Model } else { [System.DBNull]::Value }))
        [void]$UpsertCommand.Parameters.AddWithValue("@DeploymentName", $(if ($DeploymentName) { $DeploymentName } else { [System.DBNull]::Value }))
        [void]$UpsertCommand.Parameters.AddWithValue("@ApiVersion", $(if ($ApiVersion) { $ApiVersion } else { [System.DBNull]::Value }))
        [void]$UpsertCommand.Parameters.AddWithValue("@IsActive", 1)

        $Reader = $UpsertCommand.ExecuteReader()
        if ($Reader.Read()) {
            $hasApiKey = $Reader["HasApiKey"]
            $keyStatus = if ($hasApiKey -eq 1) { "Encrypted" } else { "Not set" }
            Write-Host "   [OK] $ProviderName - API Key: $keyStatus" -ForegroundColor Green
        }
        $Reader.Close()
    }
    catch {
        Write-Host "   [ERROR] Error configuring $ProviderName : $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        # Remove the handler before closing
        $Connection.remove_InfoMessage($InfoMessageHandler)
        $Connection.Close()
    }
}

try {
    # =============================================
    # Step 1: Test Connection
    # =============================================
    Write-Host "Step 1: Testing database connection..." -ForegroundColor Cyan

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()

    $TestCommand = $Connection.CreateCommand()
    $TestCommand.CommandText = "SELECT DB_NAME() as DatabaseName, @@VERSION as SQLVersion"
    $TestResult = $TestCommand.ExecuteReader()

    if ($TestResult.Read()) {
        Write-Host "    Connected to: $($TestResult['DatabaseName'])" -ForegroundColor Green
        $versionInfo = $TestResult['SQLVersion'].ToString().Split("`n")[0]
        Write-Host "   SQL Server: $versionInfo" -ForegroundColor Gray
    }
    $TestResult.Close()
    $Connection.Close()
    Write-Host ""

    # =============================================
    # Step 2: Install Core Multi-Provider Support
    # =============================================
    Write-Host "Step 2: Installing core multi-provider support..." -ForegroundColor Cyan

    $CoreScripts = @(
        "01_MultiProviderSupport.sql",
        "02_UpdateExistingProcedures.sql"
    )

    foreach ($ScriptFile in $CoreScripts) {
        $ScriptPath = Join-Path $ScriptDir $ScriptFile
        Execute-SqlScript -ScriptPath $ScriptPath -ConnectionString $ConnectionString -DatabaseName $DatabaseName
    }
    Write-Host ""

    # =============================================
    # Step 3: Install Simplified Procedures
    # =============================================
    if ($InstallSimplifiedProcedures) {
        Write-Host "Step 3: Installing simplified RAG procedures..." -ForegroundColor Cyan

        $SimplifiedScript = Join-Path $ScriptDir "04_SimplifiedRAGProcedures.sql"
        Execute-SqlScript -ScriptPath $SimplifiedScript -ConnectionString $ConnectionString -DatabaseName $DatabaseName
        Write-Host ""
    }

    # =============================================
    # Step 4: Install API Key Procedures
    # =============================================
    if ($InstallApiKeyProcedures) {
        Write-Host "Step 4: Installing API key procedures..." -ForegroundColor Cyan

        $ApiKeyScript = Join-Path $ScriptDir "04b_SimplifiedRAGProcedures_WithApiKey.sql"
        Execute-SqlScript -ScriptPath $ApiKeyScript -ConnectionString $ConnectionString -DatabaseName $DatabaseName
        Write-Host ""
    }

    # =============================================
    # Step 5: Install Encrypted Configuration System
    # =============================================
    if (-not $SkipConfiguration) {
        Write-Host "Step 5: Installing encrypted configuration system..." -ForegroundColor Cyan
        $EncryptionResult = Install-EncryptedConfiguration -ConnectionString $ConnectionString -DatabaseName $DatabaseName -ScriptDir $ScriptDir
        Write-Host ""

        if ($EncryptionResult) {
            Write-Host "   Configuring AI providers with encrypted keys..." -ForegroundColor Yellow
        } else {
            Write-Host "   WARNING: Skipping provider configuration due to encryption installation issues" -ForegroundColor Yellow
            Write-Host ""
            return
        }

        # OpenAI
        Insert-ProviderConfiguration `
            -ConnectionString $ConnectionString `
            -ProviderName "OpenAI" `
            -ApiKey $OpenAIApiKey `
            -BaseUrl $OpenAIBaseUrl `
            -Model $OpenAIModel

        # Gemini
        Insert-ProviderConfiguration `
            -ConnectionString $ConnectionString `
            -ProviderName "Gemini" `
            -ApiKey $GeminiApiKey `
            -BaseUrl $GeminiBaseUrl `
            -Model $GeminiModel

        # Azure OpenAI
        Insert-ProviderConfiguration `
            -ConnectionString $ConnectionString `
            -ProviderName "AzureOpenAI" `
            -ApiKey $AzureOpenAIApiKey `
            -BaseUrl $AzureOpenAIEndpoint `
            -Model $AzureOpenAIDeployment `
            -DeploymentName $AzureOpenAIDeployment `
            -ApiVersion "2024-02-15-preview"

        Write-Host ""
    }

    # =============================================
    # Step 6: Verify Installation
    # =============================================
    Write-Host "Step 6: Verifying installation..." -ForegroundColor Cyan

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()

    $VerifyCommand = $Connection.CreateCommand()
    $VerifyCommand.CommandText = @"
        SELECT
            COUNT(CASE WHEN ROUTINE_NAME LIKE '%MultiProvider%' THEN 1 END) as MultiProviderProcs,
            COUNT(CASE WHEN ROUTINE_NAME LIKE 'SP_GetDataForLLM%' THEN 1 END) as SimplifiedProcs,
            COUNT(*) as TotalProcs
        FROM INFORMATION_SCHEMA.ROUTINES
        WHERE ROUTINE_TYPE = 'PROCEDURE'
          AND (ROUTINE_NAME LIKE '%MultiProvider%' OR
               ROUTINE_NAME LIKE 'SP_GetDataForLLM%' OR
               ROUTINE_NAME LIKE 'SP_GenerateEmbedding%' OR
               ROUTINE_NAME LIKE 'SP_TestAllProviders%')
"@

    $ProcCounts = $VerifyCommand.ExecuteReader()
    if ($ProcCounts.Read()) {
        Write-Host "    Multi-provider procedures: $($ProcCounts['MultiProviderProcs'])" -ForegroundColor Green
        Write-Host "    Simplified RAG procedures: $($ProcCounts['SimplifiedProcs'])" -ForegroundColor Green
        Write-Host "    Total installed procedures: $($ProcCounts['TotalProcs'])" -ForegroundColor Green
    }
    $ProcCounts.Close()
    $Connection.Close()
    Write-Host ""

    # =============================================
    # Step 7: Run Tests (if requested)
    # =============================================
    if ($TestAfterInstall -and ($OpenAIApiKey -or $GeminiApiKey -or $AzureOpenAIApiKey)) {
        Write-Host "Step 7: Running post-installation tests..." -ForegroundColor Cyan

        $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $Connection.Open()

        # Test embedding generation
        if ($GeminiApiKey) {
            Write-Host "   Testing Gemini embedding generation..." -ForegroundColor Yellow

            $TestCommand = $Connection.CreateCommand()
            $TestCommand.CommandText = @"
                DECLARE @Embedding VARBINARY(MAX);
                EXEC SP_GenerateEmbedding_MultiProvider
                    @Text = 'test embedding',
                    @Provider = 'Gemini',
                    @ApiKey = @apikey,
                    @Model = @model,
                    @Embedding = @Embedding OUTPUT;
                SELECT CASE WHEN @Embedding IS NOT NULL THEN 1 ELSE 0 END as Success;
"@
            $TestCommand.Parameters.AddWithValue("@apikey", $GeminiApiKey)
            $TestCommand.Parameters.AddWithValue("@model", $GeminiModel)
            $TestCommand.CommandTimeout = 60

            $Result = $TestCommand.ExecuteScalar()
            if ($Result -eq 1) {
                Write-Host "    Gemini embedding test passed" -ForegroundColor Green
            } else {
                Write-Host "    Gemini embedding test failed" -ForegroundColor Red
            }
        }

        # Test simplified RAG procedure
        if ($GeminiApiKey) {
            Write-Host "   Testing simplified RAG search..." -ForegroundColor Yellow

            $RagCommand = $Connection.CreateCommand()
            $RagCommand.CommandText = @"
                EXEC SP_GetDataForLLM_Gemini_WithKey
                    @SearchText = 'test search query',
                    @ApiKey = @apikey,
                    @TopK = 3;
"@
            $RagCommand.Parameters.AddWithValue("@apikey", $GeminiApiKey)
            $RagCommand.CommandTimeout = 60

            try {
                $RagResults = $RagCommand.ExecuteReader()
                $ResultCount = 0
                while ($RagResults.Read()) {
                    $ResultCount++
                }
                $RagResults.Close()
                Write-Host "    RAG search test passed ($ResultCount results)" -ForegroundColor Green
            } catch {
                Write-Host "    RAG search test failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        $Connection.Close()
        Write-Host ""
    }

    # =============================================
    # Final Summary
    # =============================================
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "Installed Procedures:" -ForegroundColor Cyan
    Write-Host "   Core Multi-Provider:" -ForegroundColor White
    Write-Host "       SP_GenerateEmbedding_MultiProvider" -ForegroundColor Gray
    Write-Host "       SP_GenerateMockEmbedding" -ForegroundColor Gray
    Write-Host "       SP_GetProviderConfiguration" -ForegroundColor Gray
    Write-Host "       SP_TestAllProviders" -ForegroundColor Gray
    Write-Host "       SP_RAGSearch_MultiProvider" -ForegroundColor Gray
    Write-Host ""

    if ($InstallSimplifiedProcedures) {
        Write-Host "   Simplified RAG Procedures (No API Key):" -ForegroundColor White
        Write-Host "       SP_GetDataForLLM_OpenAI" -ForegroundColor Gray
        Write-Host "       SP_GetDataForLLM_Gemini" -ForegroundColor Gray
        Write-Host "       SP_GetDataForLLM_AzureOpenAI" -ForegroundColor Gray
        Write-Host ""
    }

    if ($InstallApiKeyProcedures) {
        Write-Host "   Simplified RAG Procedures (With API Key):" -ForegroundColor White
        Write-Host "       SP_GetDataForLLM_OpenAI_WithKey" -ForegroundColor Gray
        Write-Host "       SP_GetDataForLLM_Gemini_WithKey" -ForegroundColor Gray
        Write-Host "       SP_GetDataForLLM_AzureOpenAI_WithKey" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "   OpenAI API Key: $(if ($OpenAIApiKey) { 'Configured ' } else { 'Not configured' })" -ForegroundColor $(if ($OpenAIApiKey) { 'Green' } else { 'Yellow' })
    Write-Host "   Gemini API Key: $(if ($GeminiApiKey) { 'Configured ' } else { 'Not configured' })" -ForegroundColor $(if ($GeminiApiKey) { 'Green' } else { 'Yellow' })
    Write-Host "   Azure OpenAI: $(if ($AzureOpenAIApiKey) { 'Configured ' } else { 'Not configured' })" -ForegroundColor $(if ($AzureOpenAIApiKey) { 'Green' } else { 'Yellow' })
    Write-Host ""

    Write-Host "Quick Start Examples:" -ForegroundColor Cyan
    Write-Host "   # Using Gemini with API key:" -ForegroundColor White
    Write-Host "   EXEC SP_GetDataForLLM_Gemini_WithKey" -ForegroundColor Gray
    Write-Host "       @SearchText = 'your search query'," -ForegroundColor Gray
    Write-Host "       @ApiKey = 'your-gemini-api-key'," -ForegroundColor Gray
    Write-Host "       @TopK = 10;" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   # Using configuration table:" -ForegroundColor White
    Write-Host "   SELECT * FROM AIProviderConfiguration;" -ForegroundColor Gray
    Write-Host ""

    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Update API keys in AIProviderConfiguration table" -ForegroundColor Gray
    Write-Host "   2. Test the installation with: .\Install-MultiProvider.ps1 -TestAfterInstall -GeminiApiKey 'your-key'" -ForegroundColor Gray
    Write-Host "   3. Run the test workflow: 05_TestRAGWorkflow.sql" -ForegroundColor Gray
    Write-Host "   4. Review documentation: README_SimplifiedRAG.md" -ForegroundColor Gray
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "=========================================================" -ForegroundColor Red
    Write-Host "Installation failed!" -ForegroundColor Red
    Write-Host "=========================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Verify server name and database name" -ForegroundColor Gray
    Write-Host "   2. Check SQL Server permissions" -ForegroundColor Gray
    Write-Host "   3. Ensure base RAG procedures are installed first" -ForegroundColor Gray
    Write-Host "   4. Verify required tables exist (Documents, DocumentChunks)" -ForegroundColor Gray
    Write-Host "   5. Check SQL Server logs for details" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "=========================================================" -ForegroundColor Green

