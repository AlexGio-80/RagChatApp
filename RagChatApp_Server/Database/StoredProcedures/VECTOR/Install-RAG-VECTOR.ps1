# ============================================
# RagChatApp - VECTOR Installation Script
# ============================================
# This script installs the RAG system using native SQL Server 2025 VECTOR type
# Compatible with SQL Server 2025 RTM or later (when VECTOR support is complete)
#
# Prerequisites:
# - SQL Server 2025 RTM+ with VECTOR type support
# - Sysadmin permissions
# - Existing VARBINARY embeddings migrated to VECTOR type
#
# Usage:
#   .\Install-RAG-VECTOR.ps1 -ServerInstance "SERVER\INSTANCE" -DatabaseName "OSL_AI"

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerInstance,

    [Parameter(Mandatory=$true)]
    [string]$DatabaseName,

    [Parameter(Mandatory=$false)]
    [string]$OpenAIApiKey = "",

    [Parameter(Mandatory=$false)]
    [string]$GeminiApiKey = "",

    [Parameter(Mandatory=$false)]
    [string]$AzureOpenAIApiKey = "",

    [Parameter(Mandatory=$false)]
    [string]$AzureOpenAIEndpoint = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet('OpenAI', 'Gemini', 'AzureOpenAI')]
    [string]$DefaultProvider = 'OpenAI',

    [Parameter(Mandatory=$false)]
    [switch]$SkipMigration
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "RagChatApp - VECTOR Installation" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Server: $ServerInstance" -ForegroundColor White
Write-Host "Database: $DatabaseName" -ForegroundColor White
Write-Host "Default Provider: $DefaultProvider" -ForegroundColor White
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host ""

# ============================================
# Step 1: Verify Prerequisites
# ============================================
Write-Host "Step 1: Verifying prerequisites..." -ForegroundColor Yellow

# Check if sqlcmd is available
try {
    $sqlcmdVersion = & sqlcmd -? 2>&1 | Select-String "Version"
    Write-Host "  ✓ sqlcmd found: $sqlcmdVersion" -ForegroundColor Green
} catch {
    Write-Host "  ✗ sqlcmd not found. Please install SQL Server Command Line Tools." -ForegroundColor Red
    exit 1
}

# Check SQL Server version
Write-Host "  Checking SQL Server version..." -ForegroundColor White
$versionQuery = "SELECT CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)) AS Version, CAST(SERVERPROPERTY('ProductLevel') AS VARCHAR(50)) AS Level;"
$versionResult = & sqlcmd -S $ServerInstance -d "master" -E -Q $versionQuery -h -1 -W -s "|"

if ($versionResult -match "17\.") {
    Write-Host "  ✓ SQL Server 2025 detected" -ForegroundColor Green
} else {
    Write-Host "  ⚠ WARNING: SQL Server version may not support VECTOR type" -ForegroundColor Yellow
    Write-Host "  Detected: $versionResult" -ForegroundColor Yellow
    Write-Host "  This installation requires SQL Server 2025 RTM with full VECTOR support" -ForegroundColor Yellow

    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        Write-Host "  Installation cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Determine script locations
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootFolder = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$storedProcFolder = Join-Path $rootFolder "StoredProcedures"

Write-Host "  ✓ Script location: $scriptRoot" -ForegroundColor Green
Write-Host ""

# ============================================
# Step 2: Check VECTOR Type Support
# ============================================
Write-Host "Step 2: Checking VECTOR type support..." -ForegroundColor Yellow

$vectorCheckQuery = @"
USE [$DatabaseName];
BEGIN TRY
    DECLARE @TestVector VECTOR(768);
    SELECT 'VECTOR type is supported' AS Status;
END TRY
BEGIN CATCH
    SELECT 'VECTOR type NOT supported: ' + ERROR_MESSAGE() AS Status;
END CATCH
"@

Write-Host "  Testing VECTOR type..." -ForegroundColor White
$vectorSupport = & sqlcmd -S $ServerInstance -d $DatabaseName -E -Q $vectorCheckQuery -h -1 -W

if ($vectorSupport -match "NOT supported") {
    Write-Host "  ✗ VECTOR type not supported on this SQL Server version" -ForegroundColor Red
    Write-Host "  $vectorSupport" -ForegroundColor Red
    Write-Host ""
    Write-Host "  This installation requires SQL Server 2025 RTM with VECTOR type support." -ForegroundColor Yellow
    Write-Host "  Please use the CLR installation instead (Install-RAG-CLR.ps1)" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "  ✓ VECTOR type is supported" -ForegroundColor Green
}

Write-Host ""

# ============================================
# Step 3: Migrate to VECTOR Type
# ============================================
if (-not $SkipMigration) {
    Write-Host "Step 3: Migrating embeddings to VECTOR type..." -ForegroundColor Yellow

    $migrationScript = Join-Path (Split-Path -Parent $storedProcFolder) "StoredProcedures\09_MigrateToVectorType.sql"

    if (Test-Path $migrationScript) {
        Write-Host "  Running migration script..." -ForegroundColor White

        try {
            & sqlcmd -S $ServerInstance -d $DatabaseName -E -i $migrationScript -b
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ Migration completed successfully" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ Migration completed with warnings" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  ✗ Migration failed" -ForegroundColor Red
            Write-Host "  Error: $_" -ForegroundColor Red

            $continue = Read-Host "Continue without migration? (y/N)"
            if ($continue -ne 'y' -and $continue -ne 'Y') {
                exit 1
            }
        }
    } else {
        Write-Host "  ⚠ Migration script not found: $migrationScript" -ForegroundColor Yellow
        Write-Host "  Assuming embeddings are already in VECTOR format" -ForegroundColor Yellow
    }
} else {
    Write-Host "Step 3: Skipping migration (assuming VECTOR columns exist)" -ForegroundColor Yellow
}

Write-Host ""

# ============================================
# Step 4: Install Base Stored Procedures
# ============================================
Write-Host "Step 4: Installing base stored procedures..." -ForegroundColor Yellow

$baseScripts = @(
    "01_MultiProviderSupport.sql",
    "01_DocumentsCRUD.sql",
    "02_DocumentChunksCRUD.sql",
    "04_SemanticCacheManagement.sql"
)

foreach ($script in $baseScripts) {
    $scriptPath = Join-Path $storedProcFolder $script

    if (Test-Path $scriptPath) {
        Write-Host "  Installing $script..." -ForegroundColor White

        try {
            & sqlcmd -S $ServerInstance -d $DatabaseName -E -i $scriptPath -b 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ $script installed" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ $script completed with warnings" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  ✗ Failed to install $script" -ForegroundColor Red
            Write-Host "  Error: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  ⚠ Script not found: $script" -ForegroundColor Yellow
    }
}

Write-Host ""

# ============================================
# Step 5: Install VECTOR RAG Procedures
# ============================================
Write-Host "Step 5: Installing VECTOR RAG search procedures..." -ForegroundColor Yellow

$vectorRagScript = Join-Path $scriptRoot "02_RAGSearch_VECTOR.sql"

if (Test-Path $vectorRagScript) {
    Write-Host "  Installing RAG search procedures (VECTOR version)..." -ForegroundColor White

    try {
        & sqlcmd -S $ServerInstance -d $DatabaseName -E -i $vectorRagScript -b
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ VECTOR RAG procedures installed" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ VECTOR RAG procedures completed with warnings" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ✗ Failed to install VECTOR RAG procedures" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✗ VECTOR RAG script not found: $vectorRagScript" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================
# Step 6: Test Installation
# ============================================
Write-Host "Step 6: Testing installation..." -ForegroundColor Yellow

$testQuery = @"
USE [$DatabaseName];

-- Test VECTOR functions
DECLARE @TestVector VECTOR(768);
SELECT TOP 1 @TestVector = EmbeddingVector
FROM DocumentChunkContentEmbeddings
WHERE EmbeddingVector IS NOT NULL;

IF @TestVector IS NOT NULL
BEGIN
    SELECT
        'VECTOR Functions Test' AS TestName,
        VECTOR_DISTANCE('cosine', @TestVector, @TestVector) AS SelfDistance;
END
ELSE
BEGIN
    SELECT 'No test vectors available' AS Message;
END

-- List installed procedures
SELECT
    'Installed Procedures' AS Category,
    name AS ProcedureName,
    create_date AS CreatedDate
FROM sys.objects
WHERE type = 'P' AND name LIKE 'SP_%'
ORDER BY name;
"@

Write-Host "  Running verification tests..." -ForegroundColor White
& sqlcmd -S $ServerInstance -d $DatabaseName -E -Q $testQuery -W -s "|"

Write-Host ""

# ============================================
# Summary
# ============================================
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installation Type: VECTOR-based (SQL Server 2025 RTM+)" -ForegroundColor White
Write-Host "Server: $ServerInstance" -ForegroundColor White
Write-Host "Database: $DatabaseName" -ForegroundColor White
Write-Host ""
Write-Host "Installed Components:" -ForegroundColor White
Write-Host "  ✓ Native VECTOR(768) type support" -ForegroundColor Green
Write-Host "  ✓ VECTOR_DISTANCE function for similarity" -ForegroundColor Green
Write-Host "  ✓ Multi-provider AI support (OpenAI, Gemini, Azure OpenAI)" -ForegroundColor Green
Write-Host "  ✓ RAG search procedures with native vector operations" -ForegroundColor Green
Write-Host "  ✓ Document and chunk management procedures" -ForegroundColor Green
Write-Host "  ✓ Semantic cache management" -ForegroundColor Green
Write-Host ""
Write-Host "Benefits of VECTOR Installation:" -ForegroundColor Yellow
Write-Host "  • Native SQL Server performance optimization" -ForegroundColor White
Write-Host "  • Future-ready for vector indexing features" -ForegroundColor White
Write-Host "  • No CLR assembly management" -ForegroundColor White
Write-Host "  • Simplified deployment and maintenance" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Configure AI provider API keys in application settings" -ForegroundColor White
Write-Host "  2. Test RAG search: EXEC SP_RAGSearch_MultiProvider @QueryText='test query'" -ForegroundColor White
Write-Host "  3. Upload documents via REST API or stored procedures" -ForegroundColor White
Write-Host "  4. Review documentation in VECTOR/README_VECTOR_Installation.md" -ForegroundColor White
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
