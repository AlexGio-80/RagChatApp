# ============================================
# RagChatApp - CLR Installation Script
# ============================================
# This script installs the RAG system using CLR functions for cosine similarity
# Compatible with SQL Server 2016, 2017, 2019, 2022, and 2025
#
# Prerequisites:
# - SQL Server with sysadmin permissions
# - .NET Framework 4.7.2 or later
# - CLR integration enabled
#
# Usage:
#   .\Install-RAG-CLR.ps1 -ServerInstance "SERVER\INSTANCE" -DatabaseName "OSL_AI"

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
    [switch]$SkipCLRBuild
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "RagChatApp - CLR Installation" -ForegroundColor Cyan
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

# Check if dotnet is available
if (-not $SkipCLRBuild) {
    try {
        $dotnetVersion = & dotnet --version
        Write-Host "  ✓ .NET SDK found: $dotnetVersion" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ .NET SDK not found. Please install .NET SDK or use -SkipCLRBuild flag." -ForegroundColor Red
        exit 1
    }
}

# Determine script locations
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootFolder = Split-Path -Parent (Split-Path -Parent $scriptRoot)
$clrProjectPath = Join-Path $rootFolder "SqlClr"
$storedProcFolder = Join-Path $rootFolder "StoredProcedures"

Write-Host "  ✓ Script location: $scriptRoot" -ForegroundColor Green
Write-Host ""

# ============================================
# Step 2: Build CLR Assembly
# ============================================
if (-not $SkipCLRBuild) {
    Write-Host "Step 2: Building CLR assembly..." -ForegroundColor Yellow

    if (-not (Test-Path $clrProjectPath)) {
        Write-Host "  ✗ CLR project not found at: $clrProjectPath" -ForegroundColor Red
        exit 1
    }

    Push-Location $clrProjectPath

    try {
        Write-Host "  Building SqlVectorFunctions.dll..." -ForegroundColor White
        & dotnet restore 2>&1 | Out-Null
        $buildResult = & dotnet build -c Release 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ✗ Build failed:" -ForegroundColor Red
            Write-Host $buildResult -ForegroundColor Red
            Pop-Location
            exit 1
        }

        $dllPath = Join-Path $clrProjectPath "bin\Release\SqlVectorFunctions.dll"
        if (Test-Path $dllPath) {
            $dllSize = (Get-Item $dllPath).Length
            Write-Host "  ✓ CLR assembly built successfully ($dllSize bytes)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ DLL not found at: $dllPath" -ForegroundColor Red
            Pop-Location
            exit 1
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "Step 2: Skipping CLR build (using existing DLL)" -ForegroundColor Yellow
    $dllPath = Join-Path $clrProjectPath "bin\Release\SqlVectorFunctions.dll"

    if (-not (Test-Path $dllPath)) {
        Write-Host "  ✗ Pre-built DLL not found at: $dllPath" -ForegroundColor Red
        Write-Host "  Please build the CLR project first or remove -SkipCLRBuild flag" -ForegroundColor Red
        exit 1
    }

    Write-Host "  ✓ Using existing DLL: $dllPath" -ForegroundColor Green
}

Write-Host ""

# ============================================
# Step 3: Configure SQL Server
# ============================================
Write-Host "Step 3: Configuring SQL Server for CLR..." -ForegroundColor Yellow

# Enable CLR integration
Write-Host "  Enabling CLR integration..." -ForegroundColor White
$enableCLRQuery = @"
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE;
"@

try {
    & sqlcmd -S $ServerInstance -d "master" -E -Q $enableCLRQuery -b
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ CLR integration enabled" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠ Failed to enable CLR integration (may require sysadmin)" -ForegroundColor Yellow
}

# Disable CLR strict security (SQL Server 2017+)
Write-Host "  Configuring CLR strict security..." -ForegroundColor White
$disableStrictSecurityQuery = @"
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'clr strict security', 0;
RECONFIGURE;
"@

try {
    & sqlcmd -S $ServerInstance -d "master" -E -Q $disableStrictSecurityQuery -b 2>&1 | Out-Null
    Write-Host "  ✓ CLR strict security configured" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ CLR strict security configuration skipped (not available or already set)" -ForegroundColor Yellow
}

# Set database as TRUSTWORTHY
Write-Host "  Setting database as TRUSTWORTHY..." -ForegroundColor White
$trustworthyQuery = "ALTER DATABASE [$DatabaseName] SET TRUSTWORTHY ON;"

try {
    & sqlcmd -S $ServerInstance -d "master" -E -Q $trustworthyQuery -b
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Database set as TRUSTWORTHY" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ Failed to set database as TRUSTWORTHY" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================
# Step 4: Deploy CLR Assembly
# ============================================
Write-Host "Step 4: Deploying CLR assembly..." -ForegroundColor Yellow

# Drop existing assembly and functions
Write-Host "  Cleaning up existing CLR objects..." -ForegroundColor White
$cleanupQuery = @"
USE [$DatabaseName];
IF OBJECT_ID('dbo.fn_CosineSimilarity') IS NOT NULL DROP FUNCTION dbo.fn_CosineSimilarity;
IF OBJECT_ID('dbo.fn_EmbeddingToString') IS NOT NULL DROP FUNCTION dbo.fn_EmbeddingToString;
IF OBJECT_ID('dbo.fn_EmbeddingDimension') IS NOT NULL DROP FUNCTION dbo.fn_EmbeddingDimension;
IF OBJECT_ID('dbo.fn_IsValidEmbedding') IS NOT NULL DROP FUNCTION dbo.fn_IsValidEmbedding;
IF EXISTS (SELECT * FROM sys.assemblies WHERE name = 'SqlVectorFunctions') DROP ASSEMBLY SqlVectorFunctions;
"@

& sqlcmd -S $ServerInstance -d $DatabaseName -E -Q $cleanupQuery -b 2>&1 | Out-Null
Write-Host "  ✓ Cleanup completed" -ForegroundColor Green

# Register assembly
Write-Host "  Registering CLR assembly..." -ForegroundColor White
$escapedDllPath = $dllPath.Replace("'", "''")
$registerAssemblyQuery = @"
USE [$DatabaseName];
CREATE ASSEMBLY SqlVectorFunctions
FROM '$escapedDllPath'
WITH PERMISSION_SET = SAFE;
"@

try {
    & sqlcmd -S $ServerInstance -d $DatabaseName -E -Q $registerAssemblyQuery -b
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ CLR assembly registered" -ForegroundColor Green
    } else {
        throw "Assembly registration failed"
    }
} catch {
    Write-Host "  ✗ Failed to register CLR assembly" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    exit 1
}

# Create CLR functions
Write-Host "  Creating CLR functions..." -ForegroundColor White
$createFunctionsQuery = @"
USE [$DatabaseName];

CREATE FUNCTION dbo.fn_CosineSimilarity(@embedding1 VARBINARY(MAX), @embedding2 VARBINARY(MAX))
RETURNS FLOAT
AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.CosineSimilarity;

CREATE FUNCTION dbo.fn_EmbeddingToString(@embedding VARBINARY(MAX), @maxValues INT)
RETURNS NVARCHAR(MAX)
AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.EmbeddingToString;

CREATE FUNCTION dbo.fn_EmbeddingDimension(@embedding VARBINARY(MAX))
RETURNS INT
AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.EmbeddingDimension;

CREATE FUNCTION dbo.fn_IsValidEmbedding(@embedding VARBINARY(MAX))
RETURNS BIT
AS EXTERNAL NAME SqlVectorFunctions.SqlVectorFunctions.IsValidEmbedding;
"@

try {
    & sqlcmd -S $ServerInstance -d $DatabaseName -E -Q $createFunctionsQuery -b
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ CLR functions created" -ForegroundColor Green
    } else {
        throw "Function creation failed"
    }
} catch {
    Write-Host "  ✗ Failed to create CLR functions" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================
# Step 5: Install Base Stored Procedures
# ============================================
Write-Host "Step 5: Installing base stored procedures..." -ForegroundColor Yellow

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
# Step 6: Install CLR RAG Procedures
# ============================================
Write-Host "Step 6: Installing CLR RAG search procedures..." -ForegroundColor Yellow

$clrRagScript = Join-Path $scriptRoot "02_RAGSearch_CLR.sql"

if (Test-Path $clrRagScript) {
    Write-Host "  Installing RAG search procedures (CLR version)..." -ForegroundColor White

    try {
        & sqlcmd -S $ServerInstance -d $DatabaseName -E -i $clrRagScript -b
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ CLR RAG procedures installed" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ CLR RAG procedures completed with warnings" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ✗ Failed to install CLR RAG procedures" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✗ CLR RAG script not found: $clrRagScript" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================
# Step 7: Test Installation
# ============================================
Write-Host "Step 7: Testing installation..." -ForegroundColor Yellow

$testQuery = @"
USE [$DatabaseName];

-- Test CLR functions
DECLARE @TestEmb VARBINARY(MAX);
SELECT TOP 1 @TestEmb = Embedding FROM DocumentChunkContentEmbeddings WHERE Embedding IS NOT NULL;

IF @TestEmb IS NOT NULL
BEGIN
    SELECT
        'CLR Functions Test' AS TestName,
        dbo.fn_EmbeddingDimension(@TestEmb) AS Dimension,
        dbo.fn_IsValidEmbedding(@TestEmb) AS IsValid,
        dbo.fn_CosineSimilarity(@TestEmb, @TestEmb) AS SelfSimilarity;
END
ELSE
BEGIN
    SELECT 'No test embeddings available' AS Message;
END

-- List installed procedures
SELECT
    'Installed Procedures' AS Category,
    name AS ProcedureName,
    create_date AS CreatedDate
FROM sys.objects
WHERE type = 'P' AND name LIKE 'SP_%'
ORDER BY name;

-- List CLR functions
SELECT
    'Installed CLR Functions' AS Category,
    name AS FunctionName,
    type_desc AS Type
FROM sys.objects
WHERE type = 'FS'
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
Write-Host "Installation Type: CLR-based (SQL Server 2016-2025)" -ForegroundColor White
Write-Host "Server: $ServerInstance" -ForegroundColor White
Write-Host "Database: $DatabaseName" -ForegroundColor White
Write-Host ""
Write-Host "Installed Components:" -ForegroundColor White
Write-Host "  ✓ SqlVectorFunctions CLR assembly" -ForegroundColor Green
Write-Host "  ✓ 4 CLR vector functions (cosine similarity, validation, etc.)" -ForegroundColor Green
Write-Host "  ✓ Multi-provider AI support (OpenAI, Gemini, Azure OpenAI)" -ForegroundColor Green
Write-Host "  ✓ RAG search procedures with accurate similarity scoring" -ForegroundColor Green
Write-Host "  ✓ Document and chunk management procedures" -ForegroundColor Green
Write-Host "  ✓ Semantic cache management" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Configure AI provider API keys in application settings" -ForegroundColor White
Write-Host "  2. Test RAG search: EXEC SP_RAGSearch_MultiProvider @QueryText=`'test query`'" -ForegroundColor White
Write-Host "  3. Upload documents via REST API or stored procedures" -ForegroundColor White
Write-Host "  4. Review documentation in CLR/README_CLR_Installation.md" -ForegroundColor White
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
