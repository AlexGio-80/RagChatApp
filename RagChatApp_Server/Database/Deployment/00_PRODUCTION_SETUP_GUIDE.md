# RAG Chat App - Production Installation Guide

## 🎯 Overview

This guide covers **production deployment** without requiring a .NET development environment. Perfect for:
- IT administrators deploying to production servers
- Clients installing the packaged solution
- Remote deployments where Visual Studio/dev tools are not available

**What you'll install:**
1. SQL Server database with complete schema
2. (Optional) Stored procedures for SQL interface
3. (Optional) AES-256 encryption for API keys
4. (Optional) RAG search functionality (CLR or VECTOR) - **Highly recommended**
5. Backend API application (.NET 9.0 runtime only required)
6. (Optional) Frontend UI (HTML/CSS/JavaScript)
7. (Optional) Windows Service for automatic startup

---

## ⚠️ IMPORTANT NOTES

**📖 This is the ONLY file you need to read for installation!**

- ✅ All installation commands are in this guide with complete parameters
- ✅ Follow the steps in order - each section is self-contained
- ✅ Other README files in subfolders are for **reference/troubleshooting only**
- ✅ Replace placeholders like `YOUR_SERVER\INSTANCE` with your actual values

**Example placeholders used throughout:**
- `YOUR_SERVER\INSTANCE` → Your SQL Server (e.g., `localhost\SQLEXPRESS`, `PRODSERVER`, `192.168.1.100`)
- `RagChatAppDB` → Your database name (change if using different name)
- `your-gemini-api-key` → Your actual Gemini API key from Google AI Studio
- `your-openai-api-key` → Your actual OpenAI API key

**💡 Tip**: Use a text editor to replace all placeholders before copying commands!

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Database Setup](#step-1-database-setup)
   - 1.1 Extract Package
   - 1.2 Create Database
   - 1.3 Run Schema Script
   - 1.4 Verify Installation
   - 1.5 (Optional) Install Stored Procedures
   - 1.6 (Optional) Install RAG Search Functionality
3. [Step 2: Application Deployment](#step-2-application-deployment)
4. [Step 3: Frontend Deployment (Optional)](#step-3-frontend-deployment-optional)
5. [Step 4: Windows Service Setup (Optional)](#step-4-windows-service-setup-optional)
6. [Step 5: Verification](#step-5-verification)
7. [Step 6: Maintenance](#step-6-maintenance)

---

## Prerequisites

### Required Software (Production Server)

- ✅ **SQL Server** 2019+ (Express, Standard, or Enterprise)
  - Download: https://www.microsoft.com/sql-server/sql-server-downloads
- ✅ **.NET 9.0 Runtime** (NOT SDK - runtime only)
  - Download: https://dotnet.microsoft.com/download/dotnet/9.0
  - Select: "Download .NET Runtime" (not SDK)
- ✅ **SQL Server Management Studio (SSMS)** or **Azure Data Studio**
  - SSMS: https://aka.ms/ssmsfullsetup
  - Azure Data Studio: https://aka.ms/azuredatastudio

### Required Permissions

- ✅ Windows Administrator (for service installation)
- ✅ SQL Server sysadmin or db_owner role
- ✅ Firewall rules (if remote access needed)

### AI Provider Account (at least one)

- 🔑 **Google Gemini API Key**: https://makersuite.google.com/app/apikey (Free tier available)
- 🔑 **OpenAI API Key**: https://platform.openai.com/api-keys (Requires billing)
- 🔑 **Azure OpenAI**: Azure subscription with OpenAI resource

---

## Step 1: Database Setup

### 1.1 Extract Deployment Package

```powershell
# Extract the deployment ZIP to a working directory
Expand-Archive -Path "RagChatApp_DeploymentPackage_YYYYMMDD.zip" -DestinationPath "C:\RagChatApp_Install"
cd C:\RagChatApp_Install
```

**Package structure:**
```
C:\RagChatApp_Install\
├── 00_PRODUCTION_SETUP_GUIDE.md           # This guide (START HERE!)
├── README.txt                             # Quick start instructions
├── DEPLOYMENT_CHECKLIST.txt               # Deployment verification checklist
├── Install-WindowsService.ps1             # Windows Service installer
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
│   │   ├── Install-MultiProvider-Fixed.ps1
│   │   ├── 00_InstallAllStoredProcedures.sql
│   │   ├── README.md
│   │   └── ... (individual procedure files)
│   └── Encryption/                       # AES-256 encryption scripts (OPTIONAL)
│       └── ... (encryption setup files)
└── Documentation/
    ├── rag-database-schema.md            # Database schema reference
    └── setup-configuration-guide.md      # Configuration guide
```

### 1.2 Create Database

Open **SQL Server Management Studio (SSMS)** and connect to your server:

```sql
-- Create production database
CREATE DATABASE RagChatAppDB
GO

-- Verify creation
USE RagChatAppDB
GO
SELECT DB_NAME() AS CurrentDatabase
```

**Expected output**: `RagChatAppDB`

### 1.3 Run Database Schema Script

**In SSMS:**
1. Open file: `Database\01_DatabaseSchema.sql`
2. Ensure `RagChatAppDB` is selected in the database dropdown
3. Press **F5** to execute

**Or use command line:**
```powershell
sqlcmd -S localhost -d RagChatAppDB -i "Database\01_DatabaseSchema.sql"
```

**This creates:**
- ✅ 8 tables (Documents, DocumentChunks, 4 embedding tables, SemanticCache, AIProviderConfiguration)
- ✅ All indexes and foreign keys
- ✅ Migration history tracking

### 1.4 Verify Database Installation

```sql
-- Check tables created
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME

-- Check migrations applied
SELECT * FROM __EFMigrationsHistory ORDER BY MigrationId
```

**Expected output**: 8 tables, 3 migration records

✅ **Database setup complete!**

### 1.5 (Optional) Install Stored Procedures for SQL Interface

If you need to access the database directly via SQL procedures (for reporting, external integrations, or direct SQL access):

**Quick install with PowerShell:**
```powershell
cd Database\StoredProcedures
.\Install-MultiProvider-Fixed.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "RagChatAppDB" `
    -GeminiApiKey "your-gemini-api-key" `
    -OpenAIApiKey "your-openai-api-key" `
    -TestAfterInstall
```

**Example** (using localhost with SQL Express):
```powershell
.\Install-MultiProvider-Fixed.ps1 `
    -ServerInstance "localhost\SQLEXPRESS" `
    -DatabaseName "RagChatAppDB" `
    -GeminiApiKey "AIzaSy..." `
    -TestAfterInstall
```

This installs:
- ✅ AES-256 encryption infrastructure for secure API key storage
- ✅ All CRUD stored procedures (Documents, Chunks, Embeddings)
- ✅ Multi-provider RAG search procedures
- ✅ Semantic cache management procedures

**Note**: Stored procedures are **optional**. The REST API works without them. Install only if you need SQL-based access.

### 1.6 (Optional) Install RAG Search Functionality

⚠️ **IMPORTANT**: RAG (Retrieval-Augmented Generation) search is **required** if you want to:
- Search documents using vector similarity
- Use the chat feature with document context
- Retrieve relevant document chunks for LLM responses

**Two installation options available:**

1. **CLR (Recommended for SQL Server 2016-2025 RC)**
   - Uses SQL CLR functions for vector similarity
   - Broad compatibility, production-ready
   - Requires CLR enabled

2. **VECTOR (For SQL Server 2025 RTM+)**
   - Uses native SQL Server 2025 VECTOR type
   - Better performance, future-ready
   - Requires SQL Server 2025 RTM or later

#### Quick Install: Interactive Installer (Recommended)

The interactive installer automatically detects your SQL Server version and recommends the best option:

```powershell
# Navigate to deployment package
cd C:\RagChatApp_Install

# Run interactive RAG installer
.\Install-RAG-Interactive.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "RagChatAppDB" `
    -DefaultProvider "Gemini"

# With API keys for testing (optional)
.\Install-RAG-Interactive.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "RagChatAppDB" `
    -GeminiApiKey "your-gemini-api-key" `
    -DefaultProvider "Gemini"
```

**What this does:**
1. ✅ Detects your SQL Server version
2. ✅ Tests for VECTOR type support
3. ✅ Recommends CLR or VECTOR installation
4. ✅ Installs the selected RAG implementation
5. ✅ Verifies the installation with tests

#### Manual Installation

**For CLR (SQL Server 2016-2025 RC)**:
```powershell
cd Database\StoredProcedures\CLR
.\Install-RAG-CLR.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "RagChatAppDB" `
    -DefaultProvider "Gemini"
```

**Example** (localhost with SQL Express):
```powershell
.\Install-RAG-CLR.ps1 `
    -ServerInstance "localhost\SQLEXPRESS" `
    -DatabaseName "RagChatAppDB" `
    -DefaultProvider "Gemini"
```

**For VECTOR (SQL Server 2025 RTM+)**:
```powershell
cd Database\StoredProcedures\VECTOR
.\Install-RAG-VECTOR.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "RagChatAppDB" `
    -DefaultProvider "Gemini"
```

**Example** (localhost with SQL Express):
```powershell
.\Install-RAG-VECTOR.ps1 `
    -ServerInstance "localhost\SQLEXPRESS" `
    -DatabaseName "RagChatAppDB" `
    -DefaultProvider "Gemini"
```

#### Verification

Test RAG search after installation:

```sql
USE [RagChatAppDB];

-- Test with existing data (if available)
EXEC SP_RAGSearch_MultiProvider
    @QueryText = 'your search query',
    @TopK = 5,
    @SimilarityThreshold = 0.7,
    @AIProvider = 'Gemini',
    @ApiKey = 'your-api-key-here';

-- Expected: JSON results with document chunks and similarity scores
```

**Detailed documentation**: See `README_RAG_INSTALLATION.md` for complete RAG installation guide.

**Note**: RAG installation is **optional but highly recommended**. Without it, document search and chat features will not work.

---

## Step 2: Application Deployment

### 2.1 Extract Application Files

```powershell
# Create application directory
New-Item -ItemType Directory -Path "C:\Program Files\RagChatApp" -Force

# Copy application files to installation directory
Copy-Item -Path "Application\*" -Destination "C:\Program Files\RagChatApp" -Recurse -Force
```

**Expected structure:**
```
C:\Program Files\RagChatApp\
├── RagChatApp_Server.exe
├── RagChatApp_Server.dll
├── appsettings.json
├── *.dll (dependencies)
└── wwwroot\ (if static files included)
```

### 2.2 Configure Connection String

Edit `C:\Program Files\RagChatApp\appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=RagChatAppDB;Integrated Security=true;TrustServerCertificate=true"
  },
  "AIProvider": {
    "DefaultProvider": "Gemini",
    "Gemini": {
      "ApiKey": "YOUR-GEMINI-API-KEY-HERE",
      "BaseUrl": "https://generativelanguage.googleapis.com/v1beta",
      "Model": "models/embedding-001"
    },
    "OpenAI": {
      "ApiKey": "YOUR-OPENAI-API-KEY-HERE",
      "BaseUrl": "https://api.openai.com/v1",
      "Model": "text-embedding-3-small"
    }
  },
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
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

**Connection string examples:**

```json
// Local SQL Server (Windows Authentication)
"DefaultConnection": "Server=localhost;Database=RagChatAppDB;Integrated Security=true;TrustServerCertificate=true"

// SQL Server with SQL Authentication
"DefaultConnection": "Server=localhost;Database=RagChatAppDB;User Id=rag_user;Password=SecurePassword123!;TrustServerCertificate=true"

// Remote SQL Server
"DefaultConnection": "Server=192.168.1.100;Database=RagChatAppDB;User Id=rag_user;Password=SecurePassword123!;TrustServerCertificate=true"

// Azure SQL Database
"DefaultConnection": "Server=tcp:yourserver.database.windows.net,1433;Database=RagChatAppDB;User Id=admin;Password=SecurePassword123!;Encrypt=True;TrustServerCertificate=False"
```

### 2.3 Test Application Manually

Before installing as a service, test that the application works:

```powershell
cd "C:\Program Files\RagChatApp"
.\RagChatApp_Server.exe
```

**Expected output:**
```
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://0.0.0.0:5000
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: https://0.0.0.0:5001
info: Microsoft.Hosting.Lifetime[0]
      Application started. Press Ctrl+C to shut down.
```

**Test the API:**
```powershell
# Test health endpoint
Invoke-RestMethod -Uri "http://localhost:5000/health"

# Test info endpoint
Invoke-RestMethod -Uri "http://localhost:5000/api/info"
```

**Expected response:**
```json
{
  "status": "Healthy",
  "database": "Connected",
  "version": "1.3.1"
}
```

Press **Ctrl+C** to stop the application.

✅ **Application configured correctly!** Ready for service installation.

---

## Step 3: Frontend Deployment (Optional)

The frontend is a static HTML/CSS/JavaScript application for document management and chat interface.

**Package location**: `Frontend/` directory in deployment package

### 3.1 Option 1: Simple Web Server (Development/Testing)

Using Node.js http-server (quick and easy):

```powershell
# Install http-server globally (one time)
npm install -g http-server

# Navigate to frontend directory
cd Frontend

# Run web server
http-server -p 3000 -c-1
```

Access at: **http://localhost:3000**

### 3.2 Option 2: IIS Deployment (Production - Recommended)

**1. Install IIS** (if not already installed):
- Control Panel → Programs → Turn Windows features on or off
- Check "Internet Information Services"
- Click OK and wait for installation

**2. Deploy frontend files**:

```powershell
# Create web root directory
New-Item -ItemType Directory -Path "C:\inetpub\wwwroot\RagChatApp" -Force

# Copy frontend files
Copy-Item -Path "Frontend\*" -Destination "C:\inetpub\wwwroot\RagChatApp" -Recurse -Force

# Import IIS module
Import-Module WebAdministration

# Create application pool
New-WebAppPool -Name "RagChatAppUI"

# Create website
New-Website -Name "RagChatAppUI" `
    -PhysicalPath "C:\inetpub\wwwroot\RagChatApp" `
    -ApplicationPool "RagChatAppUI" `
    -Port 80
```

Access at: **http://localhost** or **http://your-server-ip**

### 3.3 Configure Frontend API URL

If backend is on different port/server, update `Frontend/js/app.js`:

```javascript
// Find and update this line
const API_BASE_URL = 'http://localhost:5000';  // Change to your backend URL
```

### 3.4 Configure Backend CORS (if needed)

If frontend and backend are on different ports/domains, update backend `appsettings.json`:

```json
{
  "AllowedHosts": "*",
  "Cors": {
    "AllowedOrigins": [
      "http://localhost:3000",
      "http://localhost:80",
      "http://your-domain.com"
    ]
  }
}
```

**Or** use reverse proxy (recommended for production) to serve both on same domain.

### 3.5 Verify Frontend

Open browser and navigate to your frontend URL:
- Document upload page should load
- Check browser console (F12) for errors
- Test API connectivity by uploading a test document

**Common issues:**
- **CORS errors**: Configure backend AllowedOrigins
- **404 on API calls**: Check API_BASE_URL in app.js
- **Files not loading**: Check IIS permissions

✅ **Frontend deployed successfully!**

**See also**: `Frontend/README_DEPLOYMENT.md` for additional deployment options (Nginx, Docker, etc.)

---

## Step 4: Windows Service Setup (Optional)

### 4.1 Why Install as Windows Service?

**Benefits:**
- ✅ Automatic startup when server boots
- ✅ Runs in background (no console window)
- ✅ Automatic restart on failure
- ✅ Better security (runs under service account)
- ✅ Centralized management via Services console

### 4.2 Install as Windows Service (Using SC.EXE)

**Method 1: Using built-in sc.exe** (No additional tools required)

```powershell
# Run as Administrator
sc.exe create RagChatAppService `
    binPath= "C:\Program Files\RagChatApp\RagChatApp_Server.exe" `
    DisplayName= "RAG Chat Application Service" `
    start= auto `
    obj= "NT AUTHORITY\NetworkService"

# Set service description
sc.exe description RagChatAppService "RAG Chat Application - AI-powered document search and chat service"

# Set failure recovery options (restart on failure)
sc.exe failure RagChatAppService reset= 86400 actions= restart/60000/restart/60000/restart/60000
```

**Parameters explained:**
- `binPath`: Full path to application executable
- `start= auto`: Service starts automatically on boot
- `obj= NT AUTHORITY\NetworkService`: Run under Network Service account (secure)
- `reset= 86400`: Reset failure counter after 24 hours (86400 seconds)
- `actions= restart/60000`: Restart after 60 seconds if service fails

### 4.3 Alternative: Using NSSM (Non-Sucking Service Manager)

**NSSM** is a free tool that makes service management easier.

**Download NSSM:**
- Website: https://nssm.cc/download
- Extract to: `C:\Tools\nssm`

**Install service with NSSM:**

```powershell
# Run as Administrator
cd C:\Tools\nssm\win64

# Install service interactively (GUI)
.\nssm.exe install RagChatAppService

# Or use command line
.\nssm.exe install RagChatAppService "C:\Program Files\RagChatApp\RagChatApp_Server.exe"
.\nssm.exe set RagChatAppService AppDirectory "C:\Program Files\RagChatApp"
.\nssm.exe set RagChatAppService DisplayName "RAG Chat Application Service"
.\nssm.exe set RagChatAppService Description "RAG Chat Application - AI-powered document search"
.\nssm.exe set RagChatAppService Start SERVICE_AUTO_START
.\nssm.exe set RagChatAppService AppExit Default Restart
.\nssm.exe set RagChatAppService AppStdout "C:\Program Files\RagChatApp\logs\service-output.log"
.\nssm.exe set RagChatAppService AppStderr "C:\Program Files\RagChatApp\logs\service-error.log"
```

**NSSM advantages:**
- ✅ Easier configuration (GUI available)
- ✅ Built-in log file rotation
- ✅ Better process monitoring
- ✅ Environment variable support

### 4.4 Grant SQL Server Permissions to Service Account

**If using NT AUTHORITY\NetworkService:**

```sql
USE [master]
GO

-- Create login for Network Service
CREATE LOGIN [NT AUTHORITY\NETWORK SERVICE] FROM WINDOWS
GO

USE [RagChatAppDB]
GO

-- Create user and grant permissions
CREATE USER [NT AUTHORITY\NETWORK SERVICE] FOR LOGIN [NT AUTHORITY\NETWORK SERVICE]
GO

-- Grant necessary permissions
ALTER ROLE db_datareader ADD MEMBER [NT AUTHORITY\NETWORK SERVICE]
ALTER ROLE db_datawriter ADD MEMBER [NT AUTHORITY\NETWORK SERVICE]
GRANT EXECUTE TO [NT AUTHORITY\NETWORK SERVICE]
GO
```

**Or create dedicated service account** (recommended for production):

```sql
-- Create dedicated SQL login
CREATE LOGIN [rag_service_user] WITH PASSWORD = 'SecureServicePassword123!'
GO

USE [RagChatAppDB]
GO

CREATE USER [rag_service_user] FOR LOGIN [rag_service_user]
ALTER ROLE db_datareader ADD MEMBER [rag_service_user]
ALTER ROLE db_datawriter ADD MEMBER [rag_service_user]
GRANT EXECUTE TO [rag_service_user]
GO
```

Then update connection string in `appsettings.json`:
```json
"DefaultConnection": "Server=localhost;Database=RagChatAppDB;User Id=rag_service_user;Password=SecureServicePassword123!;TrustServerCertificate=true"
```

### 4.5 Start the Service

**Using Services console (services.msc):**
1. Press `Win + R`, type `services.msc`, press Enter
2. Find "RAG Chat Application Service"
3. Right-click → Start
4. Set Startup Type to "Automatic" if not already set

**Using PowerShell:**
```powershell
# Start service
Start-Service RagChatAppService

# Check status
Get-Service RagChatAppService

# Set to start automatically
Set-Service RagChatAppService -StartupType Automatic

# View service details
Get-Service RagChatAppService | Format-List *
```

**Expected output:**
```
Status              : Running
Name                : RagChatAppService
DisplayName         : RAG Chat Application Service
StartType           : Automatic
```

### 4.6 Configure Firewall (if remote access needed)

```powershell
# Allow HTTP traffic (port 5000)
New-NetFirewallRule -DisplayName "RAG Chat HTTP" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow

# Allow HTTPS traffic (port 5001)
New-NetFirewallRule -DisplayName "RAG Chat HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5001 -Action Allow
```

### 4.7 Service Management Commands

```powershell
# Start service
Start-Service RagChatAppService

# Stop service
Stop-Service RagChatAppService

# Restart service
Restart-Service RagChatAppService

# Check status
Get-Service RagChatAppService

# View service logs (if using NSSM)
Get-Content "C:\Program Files\RagChatApp\logs\service-output.log" -Tail 50

# Remove service (if needed)
sc.exe delete RagChatAppService
# OR with NSSM:
# nssm.exe remove RagChatAppService confirm
```

✅ **Windows Service installed!** Application will start automatically on boot.

---

## Step 5: Verification

### 5.1 Verify Service is Running

```powershell
# Check service status
Get-Service RagChatAppService

# Test API endpoints
Invoke-RestMethod -Uri "http://localhost:5000/health"
Invoke-RestMethod -Uri "http://localhost:5000/api/info"
```

### 5.2 Test Document Upload

```powershell
$file = "C:\Path\To\Test.pdf"
$uri = "http://localhost:5000/api/documents/upload"

$form = @{
    file = Get-Item -Path $file
}

Invoke-RestMethod -Uri $uri -Method POST -Form $form
```

### 5.3 Test Chat Functionality

```powershell
$body = @{
    message = "What are the system requirements?"
    maxChunks = 5
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:5000/api/chat/message" `
    -Method POST `
    -Body $body `
    -ContentType "application/json"
```

### 5.4 Check Application Logs

**If using NSSM:**
```powershell
Get-Content "C:\Program Files\RagChatApp\logs\service-output.log" -Tail 100
```

**If using sc.exe, check Event Viewer:**
1. Open Event Viewer (eventvwr.msc)
2. Navigate to: Windows Logs → Application
3. Look for events from source "RagChatAppService"

---

## Step 6: Maintenance

### 6.1 Database Backup

```sql
-- Full backup
BACKUP DATABASE [RagChatAppDB]
TO DISK = 'C:\Backup\RagChatAppDB_Full.bak'
WITH FORMAT, COMPRESSION, STATS = 10

-- Backup encryption certificate (if using encrypted API keys)
BACKUP CERTIFICATE RagApiKeyCertificate
    TO FILE = 'C:\Backup\RagApiKeyCertificate.cer'
    WITH PRIVATE KEY (
        FILE = 'C:\Backup\RagApiKeyCertificate.pvk',
        ENCRYPTION BY PASSWORD = 'YourSecureBackupPassword123!'
    )
```

### 6.2 Application Updates

```powershell
# 1. Stop service
Stop-Service RagChatAppService

# 2. Backup current version
Copy-Item "C:\Program Files\RagChatApp" "C:\Backup\RagChatApp_$(Get-Date -Format 'yyyyMMdd')" -Recurse

# 3. Extract new version
Expand-Archive -Path "RagChatApp_Update_vX.X.X.zip" -DestinationPath "C:\Program Files\RagChatApp" -Force

# 4. Preserve configuration
# (appsettings.json should not be overwritten, or merge changes manually)

# 5. Start service
Start-Service RagChatAppService

# 6. Verify
Invoke-RestMethod -Uri "http://localhost:5000/api/info"
```

### 6.3 Database Schema Updates

If new version includes database changes:

```powershell
# 1. Backup database first
sqlcmd -S localhost -d RagChatAppDB -Q "BACKUP DATABASE [RagChatAppDB] TO DISK = 'C:\Backup\RagChatAppDB_BeforeUpdate.bak'"

# 2. Run new schema script (idempotent - safe to rerun)
sqlcmd -S localhost -d RagChatAppDB -i "Database\01_DatabaseSchema.sql"

# 3. Verify migrations
sqlcmd -S localhost -d RagChatAppDB -Q "SELECT * FROM __EFMigrationsHistory ORDER BY MigrationId"
```

### 6.4 Performance Monitoring

```sql
-- Check database size
EXEC sp_spaceused

-- Check table sizes
SELECT
    t.NAME AS TableName,
    p.rows AS RowCounts,
    SUM(a.total_pages) * 8 AS TotalSpaceKB,
    SUM(a.used_pages) * 8 AS UsedSpaceKB
FROM sys.tables t
INNER JOIN sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.NAME NOT LIKE 'dt%' AND t.is_ms_shipped = 0 AND i.OBJECT_ID > 255
GROUP BY t.Name, p.Rows
ORDER BY TotalSpaceKB DESC

-- Check cache statistics
EXEC SP_GetSemanticCacheStats

-- Clean old cache entries
EXEC SP_CleanSemanticCache @MaxAgeHours = 1
```

---

## 🆘 Troubleshooting

### Service Won't Start

**Check Event Viewer:**
```powershell
Get-EventLog -LogName Application -Source RagChatAppService -Newest 10
```

**Common causes:**
- ❌ Wrong path to executable
- ❌ Missing .NET 9.0 Runtime
- ❌ Database connection failed
- ❌ Port already in use

**Solutions:**
```powershell
# Verify .NET runtime installed
dotnet --list-runtimes

# Test database connection
sqlcmd -S localhost -d RagChatAppDB -Q "SELECT DB_NAME()"

# Check if port is in use
netstat -ano | findstr :5000
```

### Database Connection Failed

```powershell
# Test connection string
sqlcmd -S "YourServer" -d "RagChatAppDB" -Q "SELECT @@VERSION"

# Check SQL Server service running
Get-Service | Where-Object {$_.Name -like "*SQL*"}
```

### API Returns 500 Errors

```powershell
# Check application logs
Get-Content "C:\Program Files\RagChatApp\logs\service-output.log" -Tail 100

# Or Event Viewer → Application logs
```

---

## 📞 Support Resources

- **Database Deployment Guide**: `Database\README_DEPLOYMENT.md`
- **Deployment Checklist**: `DEPLOYMENT_CHECKLIST.txt`
- **Database Schema**: `Documentation\rag-database-schema.md`
- **Configuration Guide**: `Documentation\setup-configuration-guide.md`

---

## 🎉 Installation Complete!

Your RAG Chat Application is now running as a Windows Service:

- ✅ **Database**: RagChatAppDB with complete schema
- ✅ **Service**: Auto-starts on boot, restarts on failure
- ✅ **API Endpoints**:
  - Health: http://localhost:5000/health
  - Info: http://localhost:5000/api/info
  - Swagger: http://localhost:5000/swagger
- ✅ **Frontend** (if deployed): http://localhost:5000

**Next steps:**
1. Deploy frontend application (if separate)
2. Configure reverse proxy (IIS/nginx) for production URLs
3. Setup SSL certificate for HTTPS
4. Configure scheduled database backups
5. Setup monitoring and alerting

---

**Last Updated**: October 1, 2025
**Version**: 1.0.0
**Status**: Production Ready ✅
