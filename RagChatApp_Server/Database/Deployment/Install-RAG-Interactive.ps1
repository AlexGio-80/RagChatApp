# Interactive RAG Installation Script
# This script helps choose and install the appropriate RAG search implementation

param(
    [Parameter(Mandatory=$false)]
    [string]$ServerInstance = "localhost",

    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "RagChatAppDB",

    [string]$OpenAIApiKey = "",
    [string]$GeminiApiKey = "",
    [string]$AzureOpenAIApiKey = "",
    [string]$AzureOpenAIEndpoint = "",
    [string]$DefaultProvider = "Gemini",

    [switch]$NonInteractive = $false,
    [ValidateSet("CLR", "VECTOR", "Auto")]
    [string]$InstallationType = "Auto"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "RAG Chat App - RAG Installation Wizard" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Function to detect SQL Server version and VECTOR support
function Test-VectorSupport {
    param([string]$ServerInstance, [string]$DatabaseName)

    Write-Host "Detecting SQL Server capabilities..." -ForegroundColor Yellow

    $query = @"
SELECT
    CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)) AS Version,
    CAST(SERVERPROPERTY('ProductLevel') AS VARCHAR(50)) AS Level,
    CAST(SERVERPROPERTY('Edition') AS VARCHAR(50)) AS Edition;
"@

    try {
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -Query $query -TrustServerCertificate -ErrorAction Stop

        $version = $result.Version
        $majorVersion = [int]($version.Split('.')[0])
        $level = $result.Level
        $edition = $result.Edition

        Write-Host "  SQL Server Version: $version" -ForegroundColor White
        Write-Host "  Product Level: $level" -ForegroundColor White
        Write-Host "  Edition: $edition" -ForegroundColor White
        Write-Host ""

        # Test VECTOR type support
        $vectorTest = @"
BEGIN TRY
    DECLARE @TestVector VECTOR(768);
    SELECT 1 AS VectorSupported;
END TRY
BEGIN CATCH
    SELECT 0 AS VectorSupported;
END CATCH
"@

        $vectorResult = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -Query $vectorTest -TrustServerCertificate -ErrorAction SilentlyContinue
        $vectorSupported = $false
        if ($vectorResult -and $vectorResult.VectorSupported) {
            $vectorSupported = $vectorResult.VectorSupported -eq 1
        }

        return @{
            MajorVersion = $majorVersion
            FullVersion = $version
            Level = $level
            Edition = $edition
            VectorSupported = $vectorSupported
        }
    }
    catch {
        Write-Host "ERROR: Unable to connect to SQL Server" -ForegroundColor Red
        Write-Host "  Server: $ServerInstance" -ForegroundColor Red
        Write-Host "  Database: $DatabaseName" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to display recommendations
function Show-Recommendation {
    param($ServerInfo)

    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Installation Recommendation" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "DEBUG: In Show-Recommendation" -ForegroundColor Magenta
    Write-Host "DEBUG: ServerInfo is null: $($null -eq $ServerInfo)" -ForegroundColor Magenta
    if ($ServerInfo) {
        Write-Host "DEBUG: MajorVersion is null: $($null -eq $ServerInfo.MajorVersion)" -ForegroundColor Magenta
        Write-Host "DEBUG: MajorVersion value: $($ServerInfo.MajorVersion)" -ForegroundColor Magenta
    }

    if ($null -eq $ServerInfo -or $null -eq $ServerInfo.MajorVersion) {
        Write-Host "⚠️  ERROR: Failed to detect SQL Server version properly" -ForegroundColor Red
        Write-Host ""
        return $null
    }

    Write-Host "DEBUG: Checking version >= 13" -ForegroundColor Magenta
    $majorVersionInt = [int]$ServerInfo.MajorVersion
    Write-Host "DEBUG: MajorVersion as int: $majorVersionInt" -ForegroundColor Magenta

    # Check SQL Server version first
    if ($majorVersionInt -lt 13) {
        Write-Host "⚠️  WARNING: Unsupported SQL Server Version" -ForegroundColor Red
        Write-Host ""
        Write-Host "Your version: $($ServerInfo.FullVersion)" -ForegroundColor White
        Write-Host "Minimum required: SQL Server 2016 (version 13.x)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Please upgrade SQL Server to use RAG functionality." -ForegroundColor Yellow
        return $null
    }

    Write-Host "DEBUG: Past version check, checking VECTOR support" -ForegroundColor Magenta
    Write-Host "DEBUG: VectorSupported value: '$($ServerInfo.VectorSupported)'" -ForegroundColor Magenta

    # Check for VECTOR support (SQL Server 2025 RTM+)
    # Using explicit string comparison to avoid boolean issues
    if ($ServerInfo.VectorSupported -and $ServerInfo.VectorSupported -ne $false) {
        Write-Host "DEBUG: Entering VECTOR branch" -ForegroundColor Magenta
        Write-Host "✅ RECOMMENDATION: VECTOR Installation" -ForegroundColor Green
        Write-Host ""
        Write-Host "Your SQL Server supports the native VECTOR type!" -ForegroundColor White
        Write-Host ""
        Write-Host "VECTOR Installation Benefits:" -ForegroundColor Yellow
        Write-Host "  ✓ Native SQL Server 2025 performance" -ForegroundColor White
        Write-Host "  ✓ Future vector indexing support" -ForegroundColor White
        Write-Host "  ✓ Optimized memory usage" -ForegroundColor White
        Write-Host "  ✓ Better query optimization" -ForegroundColor White
        Write-Host "  ✓ No CLR dependencies" -ForegroundColor White
        return "VECTOR"
    }

    # Default to CLR for all other cases
    Write-Host "DEBUG: Defaulting to CLR installation" -ForegroundColor Magenta
    Write-Host "✅ RECOMMENDATION: CLR Installation" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your SQL Server version: $($ServerInfo.FullVersion)" -ForegroundColor White
    Write-Host "VECTOR type: Not available (requires SQL Server 2025 RTM)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "CLR Installation Benefits:" -ForegroundColor Yellow
    Write-Host "  ✓ Compatible with SQL Server 2016-2025 RC" -ForegroundColor White
    Write-Host "  ✓ Production-ready and stable" -ForegroundColor White
    Write-Host "  ✓ Accurate cosine similarity" -ForegroundColor White
    Write-Host "  ✓ Tested with real workloads" -ForegroundColor White
    Write-Host "  ✓ Available today" -ForegroundColor White
    return "CLR"
}

# Main installation flow
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Server: $ServerInstance" -ForegroundColor White
Write-Host "  Database: $DatabaseName" -ForegroundColor White
Write-Host "  Default Provider: $DefaultProvider" -ForegroundColor White
Write-Host ""

# Detect server capabilities
$serverInfo = Test-VectorSupport -ServerInstance $ServerInstance -DatabaseName $DatabaseName

if ($null -eq $serverInfo) {
    Write-Host ""
    Write-Host "INSTALLATION ABORTED" -ForegroundColor Red
    exit 1
}

# Get recommendation
Write-Host "DEBUG: ServerInfo object received: $($null -ne $serverInfo)" -ForegroundColor Yellow
if ($serverInfo) {
    Write-Host "DEBUG: ServerInfo.MajorVersion = $($serverInfo.MajorVersion)" -ForegroundColor Yellow
    Write-Host "DEBUG: ServerInfo.FullVersion = $($serverInfo.FullVersion)" -ForegroundColor Yellow
    Write-Host "DEBUG: ServerInfo.VectorSupported = $($serverInfo.VectorSupported)" -ForegroundColor Yellow
}

$recommendation = Show-Recommendation -ServerInfo $serverInfo

Write-Host "DEBUG: Recommendation returned: $recommendation" -ForegroundColor Yellow

if ($null -eq $recommendation) {
    Write-Host ""
    Write-Host "INSTALLATION ABORTED: Unsupported SQL Server version" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Installation Type Selection" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Determine installation type
$selectedType = $InstallationType

if ($InstallationType -eq "Auto") {
    $selectedType = $recommendation
    Write-Host "Auto-selected: $selectedType (based on server capabilities)" -ForegroundColor Green
}
elseif (-not $NonInteractive) {
    Write-Host "Available installation types:" -ForegroundColor White
    Write-Host "  [1] CLR - SQL CLR functions (SQL Server 2016-2025)" -ForegroundColor White
    Write-Host "  [2] VECTOR - Native VECTOR type (SQL Server 2025 RTM+)" -ForegroundColor White
    Write-Host ""
    Write-Host "Recommended: $recommendation" -ForegroundColor Yellow
    Write-Host ""

    $choice = Read-Host "Select installation type [1 or 2, or press Enter for recommended]"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        $selectedType = $recommendation
        Write-Host "Using recommended: $selectedType" -ForegroundColor Green
    }
    elseif ($choice -eq "1") {
        $selectedType = "CLR"
    }
    elseif ($choice -eq "2") {
        if (-not $serverInfo.VectorSupported) {
            Write-Host ""
            Write-Host "WARNING: VECTOR type is not supported on your SQL Server!" -ForegroundColor Yellow
            Write-Host "This installation will likely fail." -ForegroundColor Yellow
            Write-Host ""
            $confirm = Read-Host "Continue anyway? [y/N]"
            if ($confirm -ne "y") {
                Write-Host "Installation cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
        $selectedType = "VECTOR"
    }
    else {
        Write-Host "Invalid choice. Using recommended: $recommendation" -ForegroundColor Yellow
        $selectedType = $recommendation
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Installing RAG: $selectedType" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

# Determine script location
$scriptPath = $PSScriptRoot
$storedProcsPath = Join-Path $scriptPath "..\StoredProcedures"

# Check if we're in the deployment package structure
if (-not (Test-Path $storedProcsPath)) {
    $storedProcsPath = Join-Path $scriptPath "Database\StoredProcedures"
}

if (-not (Test-Path $storedProcsPath)) {
    Write-Host "ERROR: Cannot find StoredProcedures folder!" -ForegroundColor Red
    Write-Host "Expected at: $storedProcsPath" -ForegroundColor Red
    exit 1
}

# Build installation script path
$installScriptPath = if ($selectedType -eq "CLR") {
    Join-Path $storedProcsPath "CLR\Install-RAG-CLR.ps1"
} else {
    Join-Path $storedProcsPath "VECTOR\Install-RAG-VECTOR.ps1"
}

if (-not (Test-Path $installScriptPath)) {
    Write-Host "ERROR: Installation script not found!" -ForegroundColor Red
    Write-Host "Expected at: $installScriptPath" -ForegroundColor Red
    exit 1
}

# Prepare installation parameters
$installParams = @{
    ServerInstance = $ServerInstance
    DatabaseName = $DatabaseName
    DefaultProvider = $DefaultProvider
}

if (-not [string]::IsNullOrWhiteSpace($OpenAIApiKey)) {
    $installParams.OpenAIApiKey = $OpenAIApiKey
}
if (-not [string]::IsNullOrWhiteSpace($GeminiApiKey)) {
    $installParams.GeminiApiKey = $GeminiApiKey
}
if (-not [string]::IsNullOrWhiteSpace($AzureOpenAIApiKey)) {
    $installParams.AzureOpenAIApiKey = $AzureOpenAIApiKey
}
if (-not [string]::IsNullOrWhiteSpace($AzureOpenAIEndpoint)) {
    $installParams.AzureOpenAIEndpoint = $AzureOpenAIEndpoint
}

# Execute installation
Write-Host "Executing installation script..." -ForegroundColor Cyan
Write-Host "  Script: $installScriptPath" -ForegroundColor White
Write-Host ""

try {
    & $installScriptPath @installParams

    if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor Green
        Write-Host "✅ RAG Installation Completed Successfully!" -ForegroundColor Green
        Write-Host "============================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Installation Type: $selectedType" -ForegroundColor White
        Write-Host "Server: $ServerInstance" -ForegroundColor White
        Write-Host "Database: $DatabaseName" -ForegroundColor White
        Write-Host ""

        # Show next steps
        Write-Host "Next Steps:" -ForegroundColor Cyan
        Write-Host "  1. Test RAG search with:" -ForegroundColor White
        Write-Host "     EXEC SP_RAGSearch_MultiProvider @QueryText = 'your query', @TopK = 5" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  2. Check installation documentation:" -ForegroundColor White
        if ($selectedType -eq "CLR") {
            Write-Host "     Database\StoredProcedures\CLR\README_CLR_Installation.md" -ForegroundColor Gray
        } else {
            Write-Host "     Database\StoredProcedures\VECTOR\README_VECTOR_Installation.md" -ForegroundColor Gray
        }
        Write-Host ""
    }
    else {
        Write-Host ""
        Write-Host "ERROR: Installation script failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host ""
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "ERROR: Installation failed!" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}
