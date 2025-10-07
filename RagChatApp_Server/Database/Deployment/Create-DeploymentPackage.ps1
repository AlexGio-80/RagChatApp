# Create Deployment Package
# This script creates a complete deployment package for production

param(
    [string]$OutputPath = ".\DeploymentPackage",
    [switch]$IncludeStoredProcedures = $true,
    [switch]$IncludeApplication = $true,
    [switch]$IncludeFrontend = $true,
    [switch]$SkipBuild = $false,
    [switch]$SelfContained = $false
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Creating RagChatApp Deployment Package" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory
if (Test-Path $OutputPath) {
    Write-Host "WARNING: Output directory exists. Cleaning..." -ForegroundColor Yellow
    Remove-Item -Path $OutputPath -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# Create subdirectories
$dbPath = Join-Path $OutputPath "Database"
$spPath = Join-Path $dbPath "StoredProcedures"
$encPath = Join-Path $dbPath "Encryption"
$docsPath = Join-Path $OutputPath "Documentation"
$appPath = Join-Path $OutputPath "Application"
$frontendPath = Join-Path $OutputPath "Frontend"

New-Item -ItemType Directory -Path $dbPath -Force | Out-Null
New-Item -ItemType Directory -Path $docsPath -Force | Out-Null

# Build and publish application if requested
if ($IncludeApplication) {
    Write-Host "Building and publishing application..." -ForegroundColor Cyan

    # Navigate to server project (use absolute path)
    $scriptPath = $PSScriptRoot
    $serverProjectPath = Resolve-Path (Join-Path $scriptPath "..\..") | Select-Object -ExpandProperty Path
    $publishPath = Join-Path $serverProjectPath "bin\Release\net9.0\publish"

    if (-not $SkipBuild) {
        Write-Host "  Running dotnet publish..." -ForegroundColor White

        if ($SelfContained) {
            Write-Host "  Mode: Self-contained (includes .NET Runtime)" -ForegroundColor Cyan
        } else {
            Write-Host "  Mode: Framework-dependent (requires .NET Runtime on server)" -ForegroundColor Yellow
        }

        Push-Location $serverProjectPath
        try {
            # Clean ALL previous builds (aggressive clean)
            Write-Host "  Cleaning previous builds..." -ForegroundColor Gray
            & dotnet clean --configuration Release --verbosity quiet

            # Remove bin folder to ensure clean build
            $binPath = Join-Path $serverProjectPath "bin"
            if (Test-Path $binPath) {
                Remove-Item -Path $binPath -Recurse -Force -ErrorAction SilentlyContinue
            }

            # Publish application
            if ($SelfContained) {
                # Self-contained: includes .NET runtime (larger, no runtime needed on server)
                Write-Host "  Publishing self-contained application..." -ForegroundColor Cyan
                $publishResult = & dotnet publish --configuration Release --output $publishPath --self-contained true --runtime win-x64 /p:PublishSingleFile=false --verbosity minimal 2>&1
            } else {
                # Framework-dependent: requires .NET runtime on server (smaller package)
                Write-Host "  Publishing framework-dependent application..." -ForegroundColor Cyan
                $publishResult = & dotnet publish --configuration Release --output $publishPath --self-contained false --verbosity minimal 2>&1
            }

            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: Application build failed!" -ForegroundColor Red
                Write-Host $publishResult -ForegroundColor Red
                Pop-Location
                exit 1
            }

            Write-Host "  Build successful!" -ForegroundColor Green
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "  Skipping build (using existing binaries)" -ForegroundColor Yellow
        Write-Host "  WARNING: Make sure the existing binaries match the deployment mode!" -ForegroundColor Yellow
    }

    # Copy published files
    if (Test-Path $publishPath) {
        Write-Host "  Copying application files..." -ForegroundColor White
        New-Item -ItemType Directory -Path $appPath -Force | Out-Null
        Copy-Item -Path "$publishPath\*" -Destination $appPath -Recurse -Force

        # Verify deployment mode
        $runtimeConfigPath = Join-Path $appPath "RagChatApp_Server.runtimeconfig.json"
        if (Test-Path $runtimeConfigPath) {
            $runtimeConfig = Get-Content $runtimeConfigPath | ConvertFrom-Json
            if ($SelfContained) {
                Write-Host "  Verifying self-contained deployment..." -ForegroundColor Gray
                # Self-contained should have many more DLLs
                $dllCount = (Get-ChildItem -Path $appPath -Filter "*.dll" | Measure-Object).Count
                if ($dllCount -lt 200) {
                    Write-Host "  WARNING: Expected 400+ DLLs for self-contained, found only $dllCount" -ForegroundColor Yellow
                    Write-Host "  The build may not have been self-contained!" -ForegroundColor Yellow
                } else {
                    Write-Host "  OK: Self-contained verified ($dllCount DLLs)" -ForegroundColor Green
                }
            }
        }

        # Create appsettings.json template (without sensitive data)
        $templateSettings = @"
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:5000"
      },
      "Https": {
        "Url": "https://0.0.0.0:5001"
      }
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Server=YOUR_SERVER\\INSTANCE;Database=RagChatAppDB;Integrated Security=true;TrustServerCertificate=true"
  },
  "AIProvider": {
    "DefaultProvider": "OpenAI",
    "OrderProcessingModel": "gpt-4o",
    "ArticleMatchingModel": "gpt-4o",
    "EmbeddingModel": "text-embedding-3-small",
    "ChatModel": "gpt-4o-mini",
    "OpenAI": {
      "ApiKey": "your-openai-api-key-here",
      "BaseUrl": "https://api.openai.com/v1",
      "DefaultEmbeddingModel": "text-embedding-3-small",
      "DefaultChatModel": "gpt-4o-mini",
      "MaxTokens": 4096,
      "TimeoutSeconds": 30
    },
    "Gemini": {
      "ApiKey": "your-gemini-api-key-here",
      "BaseUrl": "https://generativelanguage.googleapis.com/v1beta",
      "DefaultEmbeddingModel": "models/embedding-001",
      "DefaultChatModel": "models/gemini-1.5-pro-latest",
      "MaxTokens": 8192,
      "TimeoutSeconds": 30,
      "GenerationConfig": {
        "Temperature": 0.1,
        "TopP": 0.95,
        "TopK": 40
      }
    },
    "AzureOpenAI": {
      "ApiKey": "your-azure-openai-key-here",
      "Endpoint": "https://your-resource.openai.azure.com/",
      "ApiVersion": "2024-02-15-preview",
      "EmbeddingDeploymentName": "text-embedding-ada-002",
      "ChatDeploymentName": "gpt-4",
      "MaxTokens": 4096,
      "TimeoutSeconds": 30
    }
  },
  "RagSettings": {
    "MaxChunksForLLM": 10
  }
}
"@

        # Overwrite with template (remove any dev credentials)
        $templateSettings | Out-File -FilePath (Join-Path $appPath "appsettings.json") -Encoding UTF8 -Force

        # Remove Development settings if present
        $devSettingsPath = Join-Path $appPath "appsettings.Development.json"
        if (Test-Path $devSettingsPath) {
            Remove-Item $devSettingsPath -Force
        }

        Write-Host "  Application files copied successfully!" -ForegroundColor Green

        # Get file count and size
        $fileCount = (Get-ChildItem -Path $appPath -Recurse -File | Measure-Object).Count
        $totalSize = (Get-ChildItem -Path $appPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "  Files: $fileCount, Total size: $([math]::Round($totalSize, 2)) MB" -ForegroundColor White
    } else {
        Write-Host "ERROR: Published application not found at: $publishPath" -ForegroundColor Red
        Write-Host "Run without -SkipBuild or build the application first" -ForegroundColor Yellow
        exit 1
    }
    Write-Host ""
}

# Copy frontend files if requested
if ($IncludeFrontend) {
    Write-Host "Copying frontend files..." -ForegroundColor Cyan

    # Frontend is located relative to the script location
    $scriptPath = $PSScriptRoot
    $uiSourcePath = Resolve-Path (Join-Path $scriptPath "..\..\..\RagChatApp_UI") -ErrorAction SilentlyContinue

    if ($uiSourcePath -and (Test-Path $uiSourcePath)) {
        New-Item -ItemType Directory -Path $frontendPath -Force | Out-Null

        Write-Host "  Copying UI files from: $uiSourcePath" -ForegroundColor White

        # Copy frontend files (excluding node_modules and package files)
        Copy-Item -Path (Join-Path $uiSourcePath "index.html") -Destination $frontendPath -Force
        Copy-Item -Path (Join-Path $uiSourcePath "css") -Destination $frontendPath -Recurse -Force
        Copy-Item -Path (Join-Path $uiSourcePath "js") -Destination $frontendPath -Recurse -Force
        Copy-Item -Path (Join-Path $uiSourcePath "assets") -Destination $frontendPath -Recurse -Force -ErrorAction SilentlyContinue

        # Create README for frontend deployment
        $frontendReadme = @"
# Frontend Deployment Guide

## Quick Start

The frontend is a static HTML/CSS/JavaScript application that can be deployed in multiple ways.

### Option 1: Simple Web Server (Development/Testing)

Using Node.js http-server:
``````powershell
# Install http-server globally (one time)
npm install -g http-server

# Run from this directory
http-server -p 3000 -c-1
``````

Access at: http://localhost:3000

### Option 2: IIS Deployment (Production - Recommended)

1. **Install IIS** (if not already installed):
   - Control Panel → Programs → Turn Windows features on or off
   - Check "Internet Information Services"

2. **Create IIS Site**:
   ``````powershell
   # Import IIS module
   Import-Module WebAdministration

   # Create application pool
   New-WebAppPool -Name "RagChatAppUI"

   # Create website
   New-Website -Name "RagChatAppUI" \`
       -PhysicalPath "C:\inetpub\wwwroot\RagChatApp" \`
       -ApplicationPool "RagChatAppUI" \`
       -Port 80

   # Copy frontend files
   Copy-Item -Path * -Destination "C:\inetpub\wwwroot\RagChatApp" -Recurse -Force
   ``````

3. **Configure CORS** (if backend is on different port):
   - Update backend appsettings.json to allow your frontend URL
   - Or use reverse proxy configuration

4. Access at: http://localhost or http://your-server-ip

### Option 3: Nginx (Linux/Docker)

``````nginx
server {
    listen 80;
    server_name your-domain.com;

    root /var/www/ragchatapp;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Proxy API requests to backend
    location /api/ {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
``````

### Configuration

Update `js/app.js` if backend API is on different host/port:

``````javascript
const API_BASE_URL = 'http://localhost:5000';  // Change to your backend URL
``````

### Troubleshooting

**CORS Errors:**
- Ensure backend appsettings.json allows your frontend origin
- Or deploy both frontend and backend on same domain/port

**Files not loading:**
- Check file permissions
- Verify web server is running
- Check browser console for errors
"@
        $frontendReadme | Out-File -FilePath (Join-Path $frontendPath "README_DEPLOYMENT.md") -Encoding UTF8 -Force

        # Get file count and size
        $uiFileCount = (Get-ChildItem -Path $frontendPath -Recurse -File | Measure-Object).Count
        $uiTotalSize = (Get-ChildItem -Path $frontendPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1KB
        Write-Host "  Frontend files copied successfully!" -ForegroundColor Green
        Write-Host "  Files: $uiFileCount, Total size: $([math]::Round($uiTotalSize, 2)) KB" -ForegroundColor White
    } else {
        Write-Host "  WARNING: Frontend source not found at: $uiSourcePath" -ForegroundColor Yellow
        Write-Host "  Skipping frontend files" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Copy database schema script and deployment guides
Write-Host "Copying database schema script and guides..." -ForegroundColor Cyan
Copy-Item "01_DatabaseSchema.sql" -Destination $dbPath
Copy-Item "README_DEPLOYMENT.md" -Destination $dbPath
Copy-Item "00_PRODUCTION_SETUP_GUIDE.md" -Destination $OutputPath
Copy-Item "QUICK_START_DEPLOYMENT.md" -Destination $OutputPath
Copy-Item "OFFLINE_DEPLOYMENT_GUIDE.md" -Destination $OutputPath
Copy-Item "README_RAG_INSTALLATION.md" -Destination $OutputPath
Copy-Item "Install-WindowsService.ps1" -Destination $OutputPath
Copy-Item "Install-RAG-Interactive.ps1" -Destination $OutputPath
Copy-Item "Check-Prerequisites.ps1" -Destination $OutputPath
Copy-Item "Validate-AppSettings.ps1" -Destination $OutputPath
Copy-Item "Fix-HttpsConfiguration.ps1" -Destination $OutputPath
Copy-Item "Fix-PortConflict.ps1" -Destination $OutputPath
Copy-Item "appsettings.TEMPLATE.json" -Destination $OutputPath
Copy-Item "appsettings.HTTP-ONLY.json" -Destination $OutputPath
Copy-Item "appsettings.PORT-8080.json" -Destination $OutputPath

# Copy stored procedures if requested
if ($IncludeStoredProcedures) {
    Write-Host "Copying stored procedures..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $spPath -Force | Out-Null
    New-Item -ItemType Directory -Path $encPath -Force | Out-Null

    # Copy main installation script
    $mainSpPath = "..\..\Database\StoredProcedures"
    if (Test-Path $mainSpPath) {
        Copy-Item "$mainSpPath\00_InstallAllStoredProcedures.sql" -Destination $spPath -ErrorAction SilentlyContinue
        Copy-Item "$mainSpPath\Install-MultiProvider.ps1" -Destination $spPath -ErrorAction SilentlyContinue
        Copy-Item "$mainSpPath\README.md" -Destination $spPath -ErrorAction SilentlyContinue
        Copy-Item "$mainSpPath\README_Installation_Guide.md" -Destination $spPath -ErrorAction SilentlyContinue
        Copy-Item "$mainSpPath\README_SimplifiedRAG.md" -Destination $spPath -ErrorAction SilentlyContinue
        Copy-Item "$mainSpPath\ENCRYPTION_UPGRADE_GUIDE.md" -Destination $spPath -ErrorAction SilentlyContinue

        # Copy individual stored procedure files
        Get-ChildItem "$mainSpPath\*.sql" | ForEach-Object {
            Copy-Item $_.FullName -Destination $spPath -ErrorAction SilentlyContinue
        }

        # Copy encryption scripts
        if (Test-Path "$mainSpPath\Encryption") {
            Get-ChildItem "$mainSpPath\Encryption\*.sql" | ForEach-Object {
                Copy-Item $_.FullName -Destination $encPath -ErrorAction SilentlyContinue
            }
        }

        # Copy RAG implementation folders (CLR and VECTOR)
        Write-Host "  Copying RAG implementations (CLR and VECTOR)..." -ForegroundColor White

        # Create CLR and VECTOR directories
        $clrPath = Join-Path $spPath "CLR"
        $vectorPath = Join-Path $spPath "VECTOR"
        New-Item -ItemType Directory -Path $clrPath -Force | Out-Null
        New-Item -ItemType Directory -Path $vectorPath -Force | Out-Null

        # Copy CLR folder contents
        if (Test-Path "$mainSpPath\CLR") {
            Copy-Item "$mainSpPath\CLR\*" -Destination $clrPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "    CLR implementation copied" -ForegroundColor Gray
        }

        # Copy VECTOR folder contents
        if (Test-Path "$mainSpPath\VECTOR") {
            Copy-Item "$mainSpPath\VECTOR\*" -Destination $vectorPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "    VECTOR implementation copied" -ForegroundColor Gray
        }

        # Copy SqlClr compiled DLL for CLR installation
        $sqlClrSourcePath = Join-Path $scriptPath "..\..\SqlClr\bin\Release"
        if (Test-Path $sqlClrSourcePath) {
            $clrBinPath = Join-Path $clrPath "bin"
            New-Item -ItemType Directory -Path $clrBinPath -Force | Out-Null
            Copy-Item "$sqlClrSourcePath\SqlVectorFunctions.dll" -Destination $clrBinPath -ErrorAction SilentlyContinue
            Copy-Item "$sqlClrSourcePath\Microsoft.SqlServer.Server.dll" -Destination $clrBinPath -ErrorAction SilentlyContinue
            Write-Host "    CLR binaries copied" -ForegroundColor Gray
        }
    }
}

# Copy documentation
Write-Host "Copying documentation..." -ForegroundColor Cyan
$docSourcePath = "..\..\..\..\Documentation"
if (Test-Path "$docSourcePath\DatabaseSchemas\rag-database-schema.md") {
    Copy-Item "$docSourcePath\DatabaseSchemas\rag-database-schema.md" -Destination $docsPath -ErrorAction SilentlyContinue
}
if (Test-Path "$docSourcePath\ConfigurationGuides\setup-configuration-guide.md") {
    Copy-Item "$docSourcePath\ConfigurationGuides\setup-configuration-guide.md" -Destination $docsPath -ErrorAction SilentlyContinue
}

# Create deployment instructions
Write-Host "Creating deployment instructions..." -ForegroundColor Cyan
$includeAppText = if ($IncludeApplication) { "YES" } else { "NO" }
$includeSPText = if ($IncludeStoredProcedures) { "YES" } else { "NO" }
$includeFEText = if ($IncludeFrontend) { "YES" } else { "NO" }
$deploymentMode = if ($SelfContained) { "Self-Contained (includes .NET Runtime)" } else { "Framework-Dependent (requires .NET 9.0 Runtime)" }

$deploymentInstructions = @"
# RagChatApp - Production Deployment Package
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Package Configuration
- Application Binaries: $includeAppText
- Deployment Mode: $deploymentMode
- Frontend UI: $includeFEText
- Stored Procedures: $includeSPText

## Package Contents

\`\`\`
DeploymentPackage/
├── 00_PRODUCTION_SETUP_GUIDE.md           # START HERE - Complete setup guide
├── Install-WindowsService.ps1             # Windows Service installer
├── README.txt                             # This file
├── DEPLOYMENT_CHECKLIST.txt               # Deployment verification checklist
├── Application/                           # Backend API binaries (if included)
│   ├── RagChatApp_Server.exe             # Main executable
│   ├── RagChatApp_Server.dll             # Application DLL
│   ├── appsettings.json                  # Configuration template
│   └── ... (dependencies and runtime files)
├── Frontend/                              # Frontend UI (if included)
│   ├── index.html                        # Main page
│   ├── README_DEPLOYMENT.md              # Frontend deployment guide
│   ├── css/                              # Stylesheets
│   ├── js/                               # JavaScript files
│   └── assets/                           # Images and other assets
├── Database/
│   ├── 01_DatabaseSchema.sql             # Complete database schema (REQUIRED)
│   ├── README_DEPLOYMENT.md              # Detailed database deployment guide
│   ├── StoredProcedures/                 # SQL interface (OPTIONAL)
│   │   ├── Install-MultiProvider.ps1
│   │   ├── 00_InstallAllStoredProcedures.sql
│   │   ├── README.md
│   │   └── ... (individual procedure files)
│   └── Encryption/                       # AES-256 encryption scripts (OPTIONAL)
│       └── ... (encryption setup files)
└── Documentation/
    ├── rag-database-schema.md            # Database schema reference
    └── setup-configuration-guide.md      # Configuration guide
\`\`\`

## Quick Start

**IMPORTANT**: Read \`00_PRODUCTION_SETUP_GUIDE.md\` for complete step-by-step instructions!

### Minimum Installation (REST API Only)

1. **Create database:**
   \`\`\`sql
   CREATE DATABASE RagChatAppDB;
   GO
   \`\`\`

2. **Run schema script:**
   \`\`\`sql
   USE RagChatAppDB;
   :r "Database\01_DatabaseSchema.sql"
   GO
   \`\`\`

3. **Deploy application** (if binaries included):
   \`\`\`powershell
   # Copy application to installation directory
   Copy-Item -Path "Application\*" -Destination "C:\Program Files\RagChatApp" -Recurse -Force

   # Edit configuration
   notepad "C:\Program Files\RagChatApp\appsettings.json"
   # Update: connection string and API keys

   # Test manually first
   cd "C:\Program Files\RagChatApp"
   .\RagChatApp_Server.exe
   # Press Ctrl+C when verified

   # Install as Windows Service
   .\Install-WindowsService.ps1 -ApplicationPath "C:\Program Files\RagChatApp"
   \`\`\`

4. **Verify installation:**
   \`\`\`powershell
   Invoke-RestMethod -Uri "http://localhost:5000/health"
   \`\`\`

### Full Installation (REST API + SQL Interface + Windows Service)

Follow detailed instructions in: \`00_PRODUCTION_SETUP_GUIDE.md\`

1. Database setup (as above)
2. Install stored procedures (optional):
   \`\`\`powershell
   cd Database\StoredProcedures
   .\Install-MultiProvider.ps1 -GeminiApiKey "your-key" -TestAfterInstall
   \`\`\`
3. Deploy application and install service (as above)

## Requirements

- **SQL Server**: 2019 or later / Azure SQL Database
- **Permissions**: CREATE TABLE, CREATE PROCEDURE, CREATE CERTIFICATE
- **.NET Runtime**: $(if ($SelfContained) { "INCLUDED in package (no installation required)" } else { "9.0 required on server (download from https://dotnet.microsoft.com/download/dotnet/9.0)" })

## Support Documentation

- **Deployment Guide**: Database\README_DEPLOYMENT.md (START HERE!)
- **Database Schema**: Documentation\rag-database-schema.md
- **Configuration**: Documentation\setup-configuration-guide.md
- **Stored Procedures**: Database\StoredProcedures\README.md

## Security Notes

⚠️ **IMPORTANT**: If installing encrypted API keys:

1. Backup encryption certificate immediately:
   \`\`\`sql
   BACKUP CERTIFICATE RagApiKeyCertificate
       TO FILE = 'C:\SecureBackup\RagApiKeyCertificate.cer'
       WITH PRIVATE KEY (
           FILE = 'C:\SecureBackup\RagApiKeyCertificate.pvk',
           ENCRYPTION BY PASSWORD = 'YourSecurePassword!'
       );
   \`\`\`

2. Store certificate backup in secure location (Azure Key Vault, encrypted storage)
3. Without backup, encrypted API keys are **permanently unrecoverable**

## Version Information

- Schema Version: 3 migrations (up to 20250930065546_AddMultiProviderSupport)
- Generated: $(Get-Date -Format "yyyy-MM-dd")
- Compatible: .NET 9.0, SQL Server 2019+

---
For detailed step-by-step instructions, see: **Database\README_DEPLOYMENT.md**
"@

$deploymentInstructions | Out-File -FilePath (Join-Path $OutputPath "README.txt") -Encoding UTF8

# Create verification checklist
$checklist = @"
# Deployment Verification Checklist

## Pre-Deployment
- [ ] SQL Server 2019+ installed or Azure SQL Database provisioned
- [ ] Database created or existing database selected
- [ ] SQL user has required permissions (CREATE TABLE, CREATE PROCEDURE)
- [ ] Connection string prepared
- [ ] API keys available (if using SQL interface)

## Database Setup
- [ ] 01_DatabaseSchema.sql executed successfully
- [ ] Verified 9 tables created (run: SELECT * FROM INFORMATION_SCHEMA.TABLES)
- [ ] Verified migrations recorded (run: SELECT * FROM __EFMigrationsHistory)
- [ ] (Optional) Stored procedures installed
- [ ] (Optional) Encryption certificate backed up

## Application Configuration
- [ ] appsettings.json updated with connection string
- [ ] (Optional) Environment variables configured
- [ ] Application binaries deployed
- [ ] Application started successfully

## Post-Deployment Verification
- [ ] Application connects to database
- [ ] Health check endpoint responds: /health
- [ ] API info endpoint responds: /api/info
- [ ] (Optional) Test document upload
- [ ] (Optional) Test chat functionality

## Security Verification
- [ ] No credentials in source control
- [ ] Connection strings use environment variables or secure config
- [ ] (If encryption used) Certificate backup stored securely
- [ ] Database access restricted to application user only

## Production Checklist
- [ ] Database backup scheduled
- [ ] Application logs configured
- [ ] Monitoring configured
- [ ] Performance baseline established
- [ ] Disaster recovery plan documented

Date Completed: _________________
Deployed By: _________________
"@

$checklist | Out-File -FilePath (Join-Path $OutputPath "DEPLOYMENT_CHECKLIST.txt") -Encoding UTF8

# Create ZIP archive
Write-Host "Creating ZIP archive..." -ForegroundColor Cyan
$zipPath = "RagChatApp_DeploymentPackage_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
Compress-Archive -Path "$OutputPath\*" -DestinationPath $zipPath -Force

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "SUCCESS: Deployment package created!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

# Show package stats
Write-Host "Package Statistics:" -ForegroundColor Cyan
$totalFiles = (Get-ChildItem -Path $OutputPath -Recurse -File | Measure-Object).Count
$totalSize = (Get-ChildItem -Path $OutputPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "  Total files: $totalFiles" -ForegroundColor White
Write-Host "  Total size:  $([math]::Round($totalSize, 2)) MB" -ForegroundColor White
Write-Host ""

Write-Host "Package location:" -ForegroundColor Cyan
Write-Host "  Directory: $OutputPath" -ForegroundColor White
Write-Host "  Archive:   $zipPath" -ForegroundColor White
Write-Host ""

# Show what's included
Write-Host "Package includes:" -ForegroundColor Cyan
if ($IncludeApplication) {
    $appFiles = (Get-ChildItem -Path $appPath -File | Measure-Object).Count
    Write-Host "  Application binaries: YES ($appFiles files)" -ForegroundColor Green
} else {
    Write-Host "  Application binaries: NO" -ForegroundColor Yellow
}

if ($IncludeFrontend -and (Test-Path $frontendPath)) {
    $feFiles = (Get-ChildItem -Path $frontendPath -Recurse -File | Measure-Object).Count
    Write-Host "  Frontend UI: YES ($feFiles files)" -ForegroundColor Green
} else {
    Write-Host "  Frontend UI: NO" -ForegroundColor Yellow
}

if ($IncludeStoredProcedures) {
    $spFiles = (Get-ChildItem -Path $spPath -File -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "  Stored procedures: YES ($spFiles files)" -ForegroundColor Green
} else {
    Write-Host "  Stored procedures: NO" -ForegroundColor Yellow
}

Write-Host "  Database schema: YES" -ForegroundColor Green
Write-Host "  Documentation: YES" -ForegroundColor Green
Write-Host "  Service installer: YES" -ForegroundColor Green
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Extract: $zipPath" -ForegroundColor White
Write-Host "  2. Read:    00_PRODUCTION_SETUP_GUIDE.md (START HERE!)" -ForegroundColor White
Write-Host "  3. Follow:  Step-by-step installation instructions" -ForegroundColor White
Write-Host "  4. Use:     DEPLOYMENT_CHECKLIST.txt for verification" -ForegroundColor White
Write-Host ""
Write-Host "Ready for production deployment!" -ForegroundColor Green
Write-Host ""
