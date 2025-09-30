# =============================================
# PowerShell Script to Install Multi-Provider AI Support
# =============================================

param(
    [Parameter(Mandatory=$false)]
    [string]$ServerName = "DEV-ALEX\MSSQLSERVER01",

    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "OSL_AI",

    [string]$AuthenticationType = "Integrated", # "Integrated" or "SqlAuth"
    [string]$Username = "",
    [string]$Password = "",
    [switch]$TestAfterInstall = $false,
    [string]$OpenAIApiKey = "",
    [string]$GeminiApiKey = "",
    [string]$AzureOpenAIApiKey = "",
    [string]$AzureOpenAIEndpoint = ""
)

Write-Host "RAG Chat Application - Multi-Provider AI Installation" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "Server: $ServerName" -ForegroundColor Cyan
Write-Host "Database: $DatabaseName" -ForegroundColor Cyan
Write-Host "Authentication: $AuthenticationType" -ForegroundColor Cyan
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Build connection string
if ($AuthenticationType -eq "Integrated") {
    $ConnectionString = "Server=$ServerName;Database=$DatabaseName;Integrated Security=True;TrustServerCertificate=True;"
} else {
    $ConnectionString = "Server=$ServerName;Database=$DatabaseName;User Id=$Username;Password=$Password;TrustServerCertificate=True;"
}

try {
    # Test connection
    Write-Host "Testing database connection..." -ForegroundColor Yellow

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()

    $TestCommand = $Connection.CreateCommand()
    $TestCommand.CommandText = "SELECT DB_NAME() as DatabaseName, @@VERSION as SQLVersion"
    $TestResult = $TestCommand.ExecuteReader()

    if ($TestResult.Read()) {
        Write-Host "Connected to database: $($TestResult['DatabaseName'])" -ForegroundColor Green
        $versionInfo = $TestResult['SQLVersion'].ToString().Split("`n")[0]
        Write-Host "   SQL Server: $versionInfo" -ForegroundColor Gray
    }
    $TestResult.Close()
    $Connection.Close()

    Write-Host ""

    # Install multi-provider support
    $ScriptFiles = @(
        "01_MultiProviderSupport.sql",
        "02_UpdateExistingProcedures.sql"
    )

    foreach ($ScriptFile in $ScriptFiles) {
        $ScriptPath = Join-Path $ScriptDir $ScriptFile

        if (Test-Path $ScriptPath) {
            Write-Host "Executing $ScriptFile..." -ForegroundColor Cyan

            $SqlContent = Get-Content $ScriptPath -Raw
            $SqlContent = $SqlContent -replace "USE \[OSL_AI\]", "USE [$DatabaseName]"

            $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
            $Connection.Open()

            # Split script by GO statements and execute each batch
            $Batches = $SqlContent -split "(?m)^GO\s*$"
            $BatchCount = 0

            foreach ($Batch in $Batches) {
                $Batch = $Batch.Trim()
                if ($Batch.Length -gt 0 -and $Batch -notmatch "^\s*--.*$") {
                    try {
                        $Command = $Connection.CreateCommand()
                        $Command.CommandText = $Batch
                        $Command.CommandTimeout = 300 # 5 minutes
                        $Result = $Command.ExecuteNonQuery()
                        $BatchCount++
                    } catch {
                        Write-Host "Error executing batch in $ScriptFile : $($_.Exception.Message)" -ForegroundColor Red
                        $Connection.Close()
                        throw
                    }
                }
            }

            $Connection.Close()
            Write-Host "   $ScriptFile completed ($BatchCount batches)" -ForegroundColor Green
        } else {
            Write-Host "   File not found: $ScriptFile" -ForegroundColor Red
        }
    }

    # Verify installation
    Write-Host ""
    Write-Host "Verifying multi-provider installation..." -ForegroundColor Cyan

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()

    $VerifyCommand = $Connection.CreateCommand()
    $VerifyCommand.CommandText = @"
        SELECT COUNT(*) as ProcedureCount
        FROM INFORMATION_SCHEMA.ROUTINES
        WHERE ROUTINE_TYPE = 'PROCEDURE'
          AND (ROUTINE_NAME LIKE '%MultiProvider%' OR
               ROUTINE_NAME LIKE 'SP_GenerateEmbedding_MultiProvider' OR
               ROUTINE_NAME LIKE 'SP_TestAllProviders' OR
               ROUTINE_NAME LIKE 'SP_TestMultiProviderWorkflow')
"@

    $ProcCount = $VerifyCommand.ExecuteScalar()
    $Connection.Close()

    Write-Host ""
    Write-Host "Multi-Provider AI installation completed successfully!" -ForegroundColor Green
    Write-Host "   Multi-provider procedures installed: $ProcCount" -ForegroundColor Green

    # Run tests if requested
    if ($TestAfterInstall -and ($OpenAIApiKey -or $GeminiApiKey -or $AzureOpenAIApiKey)) {
        Write-Host ""
        Write-Host "Running post-installation tests..." -ForegroundColor Cyan

        $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $Connection.Open()

        # Test all providers
        if ($OpenAIApiKey -or $GeminiApiKey -or $AzureOpenAIApiKey) {
            Write-Host "   Testing available AI providers..." -ForegroundColor Yellow

            $TestCommand = $Connection.CreateCommand()
            $TestCommand.CommandText = "EXEC SP_TestAllProviders @OpenAIApiKey = @openai, @GeminiApiKey = @gemini, @AzureOpenAIApiKey = @azure, @AzureOpenAIEndpoint = @endpoint"
            $TestCommand.Parameters.AddWithValue("@openai", [System.DBNull]::Value)
            $TestCommand.Parameters.AddWithValue("@gemini", [System.DBNull]::Value)
            $TestCommand.Parameters.AddWithValue("@azure", [System.DBNull]::Value)
            $TestCommand.Parameters.AddWithValue("@endpoint", [System.DBNull]::Value)

            if ($OpenAIApiKey) { $TestCommand.Parameters["@openai"].Value = $OpenAIApiKey }
            if ($GeminiApiKey) { $TestCommand.Parameters["@gemini"].Value = $GeminiApiKey }
            if ($AzureOpenAIApiKey) { $TestCommand.Parameters["@azure"].Value = $AzureOpenAIApiKey }
            if ($AzureOpenAIEndpoint) { $TestCommand.Parameters["@endpoint"].Value = $AzureOpenAIEndpoint }

            $TestCommand.CommandTimeout = 120
            $TestResults = $TestCommand.ExecuteReader()

            Write-Host "   Provider test results:" -ForegroundColor Gray
            while ($TestResults.Read()) {
                $provider = $TestResults["Provider"]
                $success = $TestResults["Success"]
                $error = if ($TestResults["ErrorMessage"] -eq [System.DBNull]::Value) { "" } else { $TestResults["ErrorMessage"] }

                if ($success) {
                    Write-Host "   SUCCESS: $provider" -ForegroundColor Green
                } else {
                    Write-Host "   FAILED: $provider - $error" -ForegroundColor Red
                }
            }
            $TestResults.Close()
        }

        # Test complete workflow if we have at least one provider
        if ($OpenAIApiKey) {
            Write-Host "   Testing complete multi-provider workflow..." -ForegroundColor Yellow

            $WorkflowCommand = $Connection.CreateCommand()
            $WorkflowCommand.CommandText = "EXEC SP_TestMultiProviderWorkflow @OpenAIApiKey = @key"
            $WorkflowCommand.Parameters.AddWithValue("@key", $OpenAIApiKey)
            $WorkflowCommand.CommandTimeout = 180
            $WorkflowCommand.ExecuteNonQuery()

            Write-Host "   Workflow test completed" -ForegroundColor Green
        }

        $Connection.Close()
    }

    Write-Host ""
    Write-Host "Available Multi-Provider Procedures:" -ForegroundColor Cyan
    Write-Host "   - SP_GenerateEmbedding_MultiProvider - Generate embeddings with any provider" -ForegroundColor Gray
    Write-Host "   - SP_RAGSearch_MultiProvider - Enhanced RAG search with multi-provider" -ForegroundColor Gray
    Write-Host "   - SP_TestAllProviders - Test all configured providers" -ForegroundColor Gray
    Write-Host "   - SP_TestMultiProviderWorkflow - Complete workflow testing" -ForegroundColor Gray
    Write-Host "   - SP_GetBestAvailableProvider - Intelligent provider selection" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Usage Examples:" -ForegroundColor Cyan
    Write-Host ('   DECLARE @embedding VARBINARY(MAX);') -ForegroundColor Gray
    Write-Host ('   EXEC SP_GenerateEmbedding_MultiProvider @Text=''test'', @Provider=''OpenAI'', @ApiKey=''your-key'', @Embedding=@embedding OUTPUT;') -ForegroundColor Gray
    Write-Host ""
    Write-Host ('   EXEC SP_TestMultiProviderWorkflow @OpenAIApiKey=''your-openai-key'';') -ForegroundColor Gray
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "   1. Verify server name and database name are correct" -ForegroundColor Gray
    Write-Host "   2. Ensure you have proper permissions on the database" -ForegroundColor Gray
    Write-Host "   3. Check that the base RAG Chat procedures are already installed" -ForegroundColor Gray
    Write-Host "   4. Verify all required tables exist (Documents, DocumentChunks, etc.)" -ForegroundColor Gray
    Write-Host "   5. Make sure SQL Server supports vector operations (SQL Server 2022+ or Azure SQL)" -ForegroundColor Gray
    exit 1
}

Write-Host "=========================================================" -ForegroundColor Green