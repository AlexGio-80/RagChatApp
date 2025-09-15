# 🔧 Guida Setup Completa - RAG Chat Application

## Panoramica Setup

Questa guida fornisce istruzioni dettagliate per configurare e deployare il sistema RAG Chat Application in diversi ambienti.

## Prerequisiti Sistema

### Software Richiesto

- **Windows 10/11** o **Windows Server 2019+**
- **.NET 9.0 SDK** - [Download](https://dotnet.microsoft.com/download/dotnet/9.0)
- **SQL Server 2019+** (Express, Standard, Enterprise)
- **Visual Studio 2022** o **VS Code** (opzionale, per sviluppo)
- **IIS 10+** (per deployment produzione)

### Hardware Minimo

**Sviluppo:**
- RAM: 8GB
- Storage: 10GB liberi
- CPU: 2 core

**Produzione:**
- RAM: 16GB+
- Storage: 100GB+ (dipende dal volume documenti)
- CPU: 4+ core
- Network: Connessione stabile per Azure OpenAI

## Configurazione Azure OpenAI Service

### 1. Creazione Risorsa Azure

```bash
# Azure CLI commands
az login

# Crea resource group
az group create --name rg-ragchat --location "West Europe"

# Crea Azure OpenAI resource
az cognitiveservices account create \
  --name ragchat-openai \
  --resource-group rg-ragchat \
  --location "West Europe" \
  --kind OpenAI \
  --sku S0
```

### 2. Deployment Modelli

```bash
# Deploy text-embedding-ada-002
az cognitiveservices account deployment create \
  --name ragchat-openai \
  --resource-group rg-ragchat \
  --deployment-name text-embedding-ada-002 \
  --model-name text-embedding-ada-002 \
  --model-version "2" \
  --model-format OpenAI \
  --scale-settings-scale-type "Standard"

# Deploy GPT-4
az cognitiveservices account deployment create \
  --name ragchat-openai \
  --resource-group rg-ragchat \
  --deployment-name gpt-4 \
  --model-name gpt-4 \
  --model-version "0613" \
  --model-format OpenAI \
  --scale-settings-scale-type "Standard"
```

### 3. Configurazione Chiavi API

```powershell
# Recupera endpoint e chiavi
$resourceGroup = "rg-ragchat"
$accountName = "ragchat-openai"

# Endpoint
$endpoint = az cognitiveservices account show --name $accountName --resource-group $resourceGroup --query "properties.endpoint" --output tsv

# API Key
$apiKey = az cognitiveservices account keys list --name $accountName --resource-group $resourceGroup --query "key1" --output tsv

Write-Host "Endpoint: $endpoint"
Write-Host "API Key: $apiKey"
```

## Database SQL Server (Locale, Remoto, Azure)

### Opzione 1: SQL Server Locale

#### Installazione SQL Server Express

```powershell
# Download SQL Server Express
Invoke-WebRequest -Uri "https://download.microsoft.com/download/6/b/3/6b3adcfc-7060-4de6-b84e-0419f13f4fe1/SQLEXPR_x64_ENU.exe" -OutFile "SQLEXPR_x64_ENU.exe"

# Installazione silenziosa
.\SQLEXPR_x64_ENU.exe /QUIET /ACTION=Install /FEATURES=SQLEngine /INSTANCENAME=MSSQLSERVER01 /SQLSYSADMINACCOUNTS="BUILTIN\Administrators" /IACCEPTSQLSERVERLICENSETERMS
```

#### Configurazione Database

```sql
-- Crea database
CREATE DATABASE [OSL_AI];
GO

USE [OSL_AI];
GO

-- Configura per produzione
ALTER DATABASE [OSL_AI] SET RECOVERY FULL;
ALTER DATABASE [OSL_AI] SET AUTO_UPDATE_STATISTICS ON;
ALTER DATABASE [OSL_AI] SET AUTO_CREATE_STATISTICS ON;

-- Crea utente applicazione (opzionale)
CREATE LOGIN [ragchat_app] WITH PASSWORD = 'ComplexPassword123!';
CREATE USER [ragchat_app] FOR LOGIN [ragchat_app];
ALTER ROLE db_owner ADD MEMBER [ragchat_app];
```

### Opzione 2: Azure SQL Database

```bash
# Crea Azure SQL Server
az sql server create \
  --name ragchat-sql-server \
  --resource-group rg-ragchat \
  --location "West Europe" \
  --admin-user sqladmin \
  --admin-password "ComplexPassword123!"

# Configura firewall
az sql server firewall-rule create \
  --server ragchat-sql-server \
  --resource-group rg-ragchat \
  --name AllowAllAzure \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Crea database
az sql db create \
  --server ragchat-sql-server \
  --resource-group rg-ragchat \
  --name OSL_AI \
  --edition Standard \
  --compute-model Provisioned \
  --family Gen5 \
  --capacity 10
```

### Connection String Examples

```json
{
  "ConnectionStrings": {
    // SQL Server Locale
    "DefaultConnection": "Data Source=localhost\\MSSQLSERVER01;Initial Catalog=OSL_AI;Integrated Security=True;Encrypt=False",

    // SQL Server con autenticazione
    "DefaultConnection": "Data Source=localhost\\MSSQLSERVER01;Initial Catalog=OSL_AI;User ID=ragchat_app;Password=ComplexPassword123!;Encrypt=False",

    // Azure SQL Database
    "DefaultConnection": "Server=tcp:ragchat-sql-server.database.windows.net,1433;Initial Catalog=OSL_AI;User ID=sqladmin;Password=ComplexPassword123!;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  }
}
```

## CORS e Networking

### Configurazione CORS per Sviluppo

```csharp
// Program.cs - Sviluppo
builder.Services.AddCors(options =>
{
    options.AddPolicy("Development", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

app.UseCors("Development");
```

### Configurazione CORS per Produzione

```csharp
// Program.cs - Produzione
builder.Services.AddCors(options =>
{
    options.AddPolicy("Production", policy =>
    {
        policy.WithOrigins(
                "https://www.yourcompany.com",
                "https://ragchat.yourcompany.com"
              )
              .WithMethods("GET", "POST", "PUT", "DELETE")
              .WithHeaders("Content-Type", "Authorization", "Accept")
              .AllowCredentials();
    });
});

app.UseCors("Production");
```

### Configurazione Firewall Windows

```powershell
# Apri porta per API (5000, 7297)
New-NetFirewallRule -DisplayName "RAG Chat API HTTP" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow
New-NetFirewallRule -DisplayName "RAG Chat API HTTPS" -Direction Inbound -Protocol TCP -LocalPort 7297 -Action Allow

# Verifica regole
Get-NetFirewallRule -DisplayName "*RAG Chat*"
```

## Environment Specifici (Dev/Prod)

### appsettings.Development.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Information"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=localhost\\MSSQLSERVER01;Initial Catalog=OSL_AI_Dev;Integrated Security=True;Encrypt=False"
  },
  "AzureOpenAI": {
    "Endpoint": "https://ragchat-openai-dev.openai.azure.com/",
    "ApiKey": "dev-api-key-here",
    "EmbeddingModel": "text-embedding-ada-002",
    "ChatModel": "gpt-4"
  },
  "MockMode": {
    "Enabled": true
  },
  "AllowedHosts": "*"
}
```

### appsettings.Production.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning",
      "RagChatApp_Server": "Information"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Server=tcp:ragchat-sql-server.database.windows.net,1433;Initial Catalog=OSL_AI;User ID=sqladmin;Password=ComplexPassword123!;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  },
  "AzureOpenAI": {
    "Endpoint": "https://ragchat-openai.openai.azure.com/",
    "ApiKey": "production-api-key-here",
    "EmbeddingModel": "text-embedding-ada-002",
    "ChatModel": "gpt-4"
  },
  "MockMode": {
    "Enabled": false
  },
  "AllowedHosts": "ragchat.yourcompany.com"
}
```

## Docker Deployment

### Dockerfile per Backend

```dockerfile
# RagChatApp_Server/Dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["RagChatApp_Server.csproj", "."]
RUN dotnet restore "RagChatApp_Server.csproj"
COPY . .
WORKDIR "/src"
RUN dotnet build "RagChatApp_Server.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "RagChatApp_Server.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "RagChatApp_Server.dll"]
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  ragchat-api:
    build:
      context: ./RagChatApp_Server
      dockerfile: Dockerfile
    ports:
      - "5000:80"
      - "5001:443"
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ConnectionStrings__DefaultConnection=Server=sql-server;Database=OSL_AI;User Id=sa;Password=YourPassword123!;TrustServerCertificate=true;
    depends_on:
      - sql-server
    networks:
      - ragchat-network

  sql-server:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      - ACCEPT_EULA=Y
      - SA_PASSWORD=YourPassword123!
      - MSSQL_PID=Express
    ports:
      - "1433:1433"
    volumes:
      - sql-data:/var/opt/mssql
    networks:
      - ragchat-network

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./RagChatApp_UI:/usr/share/nginx/html
      - ./certs:/etc/nginx/certs
    depends_on:
      - ragchat-api
    networks:
      - ragchat-network

volumes:
  sql-data:

networks:
  ragchat-network:
    driver: bridge
```

### nginx.conf

```nginx
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    upstream api {
        server ragchat-api:80;
    }

    server {
        listen 80;
        server_name localhost;

        # Frontend
        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri $uri/ /index.html;
        }

        # API Proxy
        location /api/ {
            proxy_pass http://api/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Health check
        location /health {
            proxy_pass http://api/health;
        }
    }
}
```

## IIS Deployment (Windows)

### Configurazione IIS

```powershell
# Abilita IIS features
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole, IIS-WebServer, IIS-CommonHttpFeatures, IIS-HttpErrors, IIS-HttpLogging, IIS-HttpRedirect, IIS-ApplicationDevelopment, IIS-NetFxExtensibility45, IIS-HealthAndDiagnostics, IIS-HttpLogging, IIS-Security, IIS-RequestFiltering, IIS-Performance, IIS-WebServerManagementTools, IIS-ManagementConsole, IIS-IIS6ManagementCompatibility, IIS-Metabase, IIS-ASPNET45

# Installa .NET Hosting Bundle
Invoke-WebRequest -Uri "https://download.microsoft.com/download/dotnet-hosting-bundle" -OutFile "dotnet-hosting-bundle.exe"
.\dotnet-hosting-bundle.exe /quiet
```

### web.config per IIS

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <location path="." inheritInChildApplications="false">
    <system.webServer>
      <handlers>
        <add name="aspNetCore" path="*" verb="*" modules="AspNetCoreModuleV2" resourceType="Unspecified" />
      </handlers>
      <aspNetCore processPath="dotnet"
                  arguments=".\RagChatApp_Server.dll"
                  stdoutLogEnabled="false"
                  stdoutLogFile=".\logs\stdout"
                  hostingModel="inprocess" />

      <!-- Security headers -->
      <httpProtocol>
        <customHeaders>
          <add name="X-Content-Type-Options" value="nosniff" />
          <add name="X-Frame-Options" value="DENY" />
          <add name="X-XSS-Protection" value="1; mode=block" />
        </customHeaders>
      </httpProtocol>

      <!-- Request limits -->
      <security>
        <requestFiltering>
          <requestLimits maxAllowedContentLength="52428800" /> <!-- 50MB -->
        </requestFiltering>
      </security>
    </system.webServer>
  </location>
</configuration>
```

## Troubleshooting Comune

### Problemi Database

```powershell
# Test connessione database
sqlcmd -S "localhost\MSSQLSERVER01" -E -Q "SELECT @@VERSION"

# Verifica servizi SQL Server
Get-Service -Name "*SQL*"

# Avvia servizio SQL Server
Start-Service -Name "MSSQL$MSSQLSERVER01"
```

### Problemi .NET

```bash
# Verifica versione .NET
dotnet --version

# Verifica runtime installati
dotnet --list-runtimes

# Pulisci e rebuilda
dotnet clean
dotnet restore
dotnet build
```

### Problemi Azure OpenAI

```powershell
# Test API Azure OpenAI
$headers = @{
    "api-key" = "your-api-key-here"
    "Content-Type" = "application/json"
}

$body = @{
    "input" = "test"
    "model" = "text-embedding-ada-002"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://your-resource.openai.azure.com/openai/deployments/text-embedding-ada-002/embeddings?api-version=2023-05-15" -Method POST -Headers $headers -Body $body
```

### Log Analysis

```powershell
# Leggi logs applicazione
Get-Content "logs\app.log" -Tail 50

# Monitor eventi Windows
Get-EventLog -LogName Application -Source "IIS*" -Newest 10

# Monitor performance
Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 10
```

### Monitoring Produzione

```json
// appsettings.Production.json - Logging avanzato
{
  "Serilog": {
    "MinimumLevel": "Information",
    "WriteTo": [
      {
        "Name": "File",
        "Args": {
          "path": "logs/app-.log",
          "rollingInterval": "Day",
          "retainedFileCountLimit": 30
        }
      },
      {
        "Name": "Console"
      }
    ]
  }
}
```

## Script di Deployment Automatico

### deploy.ps1

```powershell
param(
    [string]$Environment = "Development",
    [string]$ConnectionString = "",
    [string]$AzureOpenAIKey = ""
)

Write-Host "Deploying RAG Chat Application to $Environment environment..."

# Backup database if production
if ($Environment -eq "Production") {
    Write-Host "Creating database backup..."
    sqlcmd -Q "BACKUP DATABASE [OSL_AI] TO DISK = 'C:\Backups\OSL_AI_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak'"
}

# Build application
Write-Host "Building application..."
dotnet clean
dotnet restore
dotnet build --configuration Release

# Update database
Write-Host "Updating database..."
dotnet ef database update --configuration Release

# Publish application
Write-Host "Publishing application..."
dotnet publish --configuration Release --output "publish\"

# Update configuration
if ($ConnectionString -ne "") {
    Write-Host "Updating connection string..."
    $config = Get-Content "publish\appsettings.json" | ConvertFrom-Json
    $config.ConnectionStrings.DefaultConnection = $ConnectionString
    $config | ConvertTo-Json -Depth 10 | Set-Content "publish\appsettings.json"
}

Write-Host "Deployment completed successfully!"
```

Questa guida fornisce una configurazione completa per tutti gli scenari di deployment del sistema RAG Chat Application, dalla configurazione di sviluppo locale fino al deployment in produzione con Docker e IIS.