# =============================================
# PowerShell Script to Install RAG Chat Stored Procedures
# =============================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerName = "DEV-ALEX\MSSQLSERVER01",

    [Parameter(Mandatory=$true)]
    [string]$DatabaseName = "OSL_AI",

    [string]$AuthenticationType = "Integrated", # "Integrated" or "SqlAuth"
    [string]$Username = "",
    [string]$Password = ""
)

Write-Host "🚀 RAG Chat Application - Stored Procedures Installation" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
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
    # Import SqlServer module if available
    if (Get-Module -ListAvailable -Name SqlServer) {
        Import-Module SqlServer -ErrorAction SilentlyContinue
        Write-Host "✅ SqlServer PowerShell module loaded" -ForegroundColor Green
    } else {
        Write-Host "⚠️  SqlServer PowerShell module not found. Using .NET SqlClient instead." -ForegroundColor Yellow
    }

    # Test connection
    Write-Host "🔗 Testing database connection..." -ForegroundColor Yellow

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()

    $TestCommand = $Connection.CreateCommand()
    $TestCommand.CommandText = "SELECT DB_NAME() as DatabaseName, @@VERSION as SQLVersion"
    $TestResult = $TestCommand.ExecuteReader()

    if ($TestResult.Read()) {
        Write-Host "✅ Connected to database: $($TestResult['DatabaseName'])" -ForegroundColor Green
        Write-Host "   SQL Server: $($TestResult['SQLVersion'].ToString().Split("`n")[0])" -ForegroundColor Gray
    }
    $TestResult.Close()
    $Connection.Close()

    Write-Host ""

    # Method 1: Try to use the unified script
    $UnifiedScript = Join-Path $ScriptDir "00_InstallAllStoredProcedures_Unified.sql"

    if (Test-Path $UnifiedScript) {
        Write-Host "📜 Using unified installation script..." -ForegroundColor Cyan

        $SqlContent = Get-Content $UnifiedScript -Raw
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
                    Write-Host "❌ Error executing batch $BatchCount`: $($_.Exception.Message)" -ForegroundColor Red
                    throw
                }
            }
        }

        $Connection.Close()
        Write-Host "✅ Unified script executed successfully ($BatchCount batches)" -ForegroundColor Green

    } else {
        # Method 2: Execute individual files
        Write-Host "📜 Executing individual script files..." -ForegroundColor Cyan

        $ScriptFiles = @(
            "01_DocumentsCRUD.sql",
            "02_DocumentChunksCRUD.sql",
            "03_RAGSearchProcedure.sql",
            "04_SemanticCacheManagement.sql",
            "05_OpenAIEmbeddingIntegration.sql"
        )

        foreach ($ScriptFile in $ScriptFiles) {
            $ScriptPath = Join-Path $ScriptDir $ScriptFile

            if (Test-Path $ScriptPath) {
                Write-Host "   Executing $ScriptFile..." -ForegroundColor Yellow

                $SqlContent = Get-Content $ScriptPath -Raw
                $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
                $Connection.Open()

                $Batches = $SqlContent -split "(?m)^GO\s*$"
                foreach ($Batch in $Batches) {
                    $Batch = $Batch.Trim()
                    if ($Batch.Length -gt 0) {
                        $Command = $Connection.CreateCommand()
                        $Command.CommandText = $Batch
                        $Command.CommandTimeout = 300
                        $null = $Command.ExecuteNonQuery()
                    }
                }

                $Connection.Close()
                Write-Host "   ✅ $ScriptFile completed" -ForegroundColor Green
            } else {
                Write-Host "   ❌ File not found: $ScriptFile" -ForegroundColor Red
            }
        }
    }

    # Verify installation
    Write-Host ""
    Write-Host "🔍 Verifying installation..." -ForegroundColor Cyan

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()

    $VerifyCommand = $Connection.CreateCommand()
    $VerifyCommand.CommandText = @"
        SELECT COUNT(*) as ProcedureCount
        FROM INFORMATION_SCHEMA.ROUTINES
        WHERE ROUTINE_TYPE = 'PROCEDURE'
          AND (ROUTINE_NAME LIKE 'SP_%Document%' OR
               ROUTINE_NAME LIKE 'SP_RAG%' OR
               ROUTINE_NAME LIKE 'SP_%Semantic%' OR
               ROUTINE_NAME LIKE 'SP_Generate%')
"@

    $ProcCount = $VerifyCommand.ExecuteScalar()
    $Connection.Close()

    Write-Host ""
    Write-Host "🎉 Installation completed successfully!" -ForegroundColor Green
    Write-Host "   Total procedures installed: $ProcCount" -ForegroundColor Green
    Write-Host ""
    Write-Host "📖 Usage Examples:" -ForegroundColor Cyan
    Write-Host "   -- Test document insertion:" -ForegroundColor Gray
    Write-Host "   DECLARE @DocId INT;" -ForegroundColor Gray
    Write-Host "   EXEC SP_InsertDocument 'test.txt', 'text/plain', 1000, 'Sample content', NULL, 'Pending', @DocId OUTPUT;" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   -- Test RAG search:" -ForegroundColor Gray
    Write-Host "   DECLARE @QueryEmbedding VARBINARY(MAX);" -ForegroundColor Gray
    Write-Host "   EXEC SP_GenerateEmbedding 'search query', NULL, DEFAULT, @QueryEmbedding OUTPUT;" -ForegroundColor Gray
    Write-Host "   EXEC SP_RAGSearch @QueryEmbedding, 10, 0.7, 'search query';" -ForegroundColor Gray
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "   1. Verify server name and database name are correct" -ForegroundColor Gray
    Write-Host "   2. Ensure you have proper permissions on the database" -ForegroundColor Gray
    Write-Host "   3. Check that Entity Framework migrations have been applied first" -ForegroundColor Gray
    Write-Host "   4. Verify all required tables exist (Documents, DocumentChunks, etc.)" -ForegroundColor Gray
    exit 1
}

Write-Host "=======================================================" -ForegroundColor Green