# 🔌 Offline Deployment Guide - Server Senza Internet

Questa guida è specifica per il deployment su **server isolati** senza connessione a internet.

---

## 🎯 Modalità di Deployment

Hai **2 opzioni** per il deployment offline:

### ✅ Opzione 1: Self-Contained (CONSIGLIATA per offline)

**Include tutto** - nessuna installazione runtime necessaria sul server.

```powershell
# Crea package self-contained (dal PC di sviluppo)
cd C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\Deployment
.\Create-DeploymentPackage.ps1 -SelfContained

# Output: Package ~150-200 MB (include .NET Runtime)
```

**Vantaggi**:
- ✅ Nessun prerequisito runtime sul server
- ✅ Deploy completamente offline
- ✅ Versione runtime garantita
- ✅ Nessuna dipendenza esterna

**Svantaggi**:
- ❌ Package più grande (~150-200 MB vs ~60 MB)
- ❌ Aggiornamenti runtime richiedono nuovo package

### ⚙️ Opzione 2: Framework-Dependent + Runtime Installer

**Include solo l'app** - devi installare .NET Runtime sul server.

```powershell
# 1. Crea package normale (dal PC di sviluppo)
.\Create-DeploymentPackage.ps1

# 2. Scarica .NET Runtime Installer (dal PC con internet)
# https://dotnet.microsoft.com/download/dotnet/9.0
# File: aspnetcore-runtime-9.0.x-win-x64.exe (~30 MB)

# 3. Copia entrambi i file sul server offline
```

**Vantaggi**:
- ✅ Package applicazione più piccolo (~60 MB)
- ✅ Runtime condiviso tra applicazioni
- ✅ Runtime aggiornabile indipendentemente

**Svantaggi**:
- ❌ Richiede installazione runtime sul server
- ❌ Due file da gestire

---

## 📦 Procedura Self-Contained (Raccomandato)

### Passo 1: Sul PC di Sviluppo (con internet)

```powershell
# Naviga alla cartella deployment
cd C:\OSL\Claude\RagChatApp\RagChatApp_Server\Database\Deployment

# Crea package self-contained completo
.\Create-DeploymentPackage.ps1 -SelfContained

# Output: RagChatApp_DeploymentPackage_YYYYMMDD_HHMMSS.zip
```

**Il package include**:
- ✅ Applicazione backend compilata
- ✅ .NET 9.0 Runtime (incluso!)
- ✅ Tutte le dipendenze
- ✅ Database scripts
- ✅ Frontend UI
- ✅ Documentazione completa
- ✅ Script di installazione

### Passo 2: Trasferimento al Server

```powershell
# Copia il file ZIP sul server offline via:
# - USB drive
# - Network share (se disponibile)
# - RDP copy/paste
# - Qualsiasi metodo sicuro

# Esempio: copia su USB
Copy-Item "RagChatApp_DeploymentPackage_20251006_HHMMSS.zip" -Destination "D:\" -Force
```

### Passo 3: Sul Server Offline

#### 3.1 Verifica Prerequisiti (opzionale ma raccomandato)

```powershell
# Estrai il package
Expand-Archive -Path "D:\RagChatApp_DeploymentPackage_20251006_HHMMSS.zip" -DestinationPath "C:\RagChatApp_Install"
cd C:\RagChatApp_Install

# Esegui verifica prerequisiti (come Administrator)
.\Check-Prerequisites.ps1

# Output:
# ✅ Windows: OK
# ✅ Administrator: OK
# ⚠️  .NET 9.0 Runtime: NOT FOUND (OK se usi self-contained!)
# ✅ SQL Server: OK
# ✅ Disk Space: OK
```

**Note**: Con self-contained, è normale che .NET Runtime non sia trovato - è incluso nel package!

#### 3.2 Setup Database

```sql
-- 1. Apri SQL Server Management Studio (SSMS)
-- 2. Connettiti al server

-- 3. Crea database
CREATE DATABASE RagChatAppDB;
GO

-- 4. Esegui schema script
USE RagChatAppDB;
GO
:r "C:\RagChatApp_Install\Database\01_DatabaseSchema.sql"
GO

-- 5. Verifica
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
-- Deve mostrare 8 tabelle
```

#### 3.3 Deploy Applicazione

```powershell
# 1. Crea directory installazione
New-Item -ItemType Directory -Path "C:\Program Files\RagChatApp" -Force

# 2. Copia applicazione self-contained
Copy-Item -Path "C:\RagChatApp_Install\Application\*" -Destination "C:\Program Files\RagChatApp" -Recurse -Force

# 3. Configura appsettings.json
notepad "C:\Program Files\RagChatApp\appsettings.json"
```

**Modifica in `appsettings.json`**:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=RagChatAppDB;Integrated Security=true;TrustServerCertificate=true"
  },
  "AIProvider": {
    "DefaultProvider": "Gemini",
    "Gemini": {
      "ApiKey": "LA-TUA-CHIAVE-API-GEMINI"
    }
  }
}
```

#### 3.4 Test Manuale

```powershell
# Testa l'applicazione prima di installarla come servizio
cd "C:\Program Files\RagChatApp"
.\RagChatApp_Server.exe

# Aspetta l'avvio (10-15 secondi)
# Output: "Now listening on: http://0.0.0.0:5000"

# In un'altra finestra PowerShell, testa:
Invoke-RestMethod -Uri "http://localhost:5000/health"
# Output: {"status":"Healthy","database":"Connected"}

# Se OK, premi Ctrl+C per fermare
```

#### 3.5 Installa Windows Service

```powershell
# Dal package estratto (come Administrator)
cd C:\RagChatApp_Install
.\Install-WindowsService.ps1 -ApplicationPath "C:\Program Files\RagChatApp"

# Lo script:
# ✅ Installa servizio Windows
# ✅ Configura auto-start
# ✅ Avvia servizio
# ✅ Testa endpoint
```

#### 3.6 Verifica Finale

```powershell
# Verifica servizio
Get-Service RagChatAppService
# Status: Running

# Testa API
Invoke-RestMethod "http://localhost:5000/health"
Invoke-RestMethod "http://localhost:5000/api/info"

# Apri Swagger
Start-Process "http://localhost:5000/swagger"
```

---

## 🔧 Procedura Framework-Dependent + Runtime Installer

Se preferisci usare questa modalità (package più piccolo):

### Passo 1: Sul PC con Internet

```powershell
# 1. Crea package normale
.\Create-DeploymentPackage.ps1

# 2. Scarica .NET Runtime Installer
# Vai a: https://dotnet.microsoft.com/download/dotnet/9.0
# Scarica: "ASP.NET Core Runtime 9.0.x - Windows x64 Installer"
# File: aspnetcore-runtime-9.0.x-win-x64.exe (~30 MB)
```

### Passo 2: Sul Server Offline

```powershell
# 1. Installa .NET Runtime (come Administrator)
.\aspnetcore-runtime-9.0.x-win-x64.exe

# Segui wizard installazione
# Riavvio non necessario

# 2. Verifica installazione
dotnet --list-runtimes
# Output deve includere: Microsoft.AspNetCore.App 9.0.x

# 3. Procedi con deployment normale (vedi QUICK_START_DEPLOYMENT.md)
```

---

## 🗄️ Opzionale: RAG Search Installation (Offline)

Se hai bisogno di RAG search (raccomandato per funzionalità chat):

```powershell
# Dal package estratto
cd C:\RagChatApp_Install

# Installa RAG (richiede API key - configurata in appsettings.json)
.\Install-RAG-Interactive.ps1 `
    -ServerInstance "localhost" `
    -DatabaseName "RagChatAppDB" `
    -GeminiApiKey "LA-TUA-CHIAVE-GEMINI" `
    -DefaultProvider "Gemini"
```

**Note**: Anche su server offline, l'app può funzionare. Le API calls (Gemini/OpenAI) richiedono internet solo al runtime, non durante l'installazione.

---

## ✅ Checklist Deployment Offline Completo

- [ ] Package self-contained creato (`-SelfContained`)
- [ ] Package copiato su server offline
- [ ] Package estratto in directory temporanea
- [ ] Check-Prerequisites eseguito (opzionale)
- [ ] Database creato
- [ ] Schema SQL eseguito (8 tabelle create)
- [ ] Applicazione copiata in `C:\Program Files\RagChatApp`
- [ ] `appsettings.json` configurato (connection string + API keys)
- [ ] Test manuale applicazione eseguito
- [ ] Windows Service installato
- [ ] Servizio avviato e verificato
- [ ] Health endpoint risponde
- [ ] (Opzionale) RAG search installato
- [ ] (Opzionale) Frontend deployato

---

## 🆘 Troubleshooting Offline

### Problema: "You must install .NET to run this application"

**Se usi self-contained**:
```powershell
# Verifica che sia effettivamente self-contained
cd "C:\Program Files\RagChatApp"
dir *.dll | measure
# Deve mostrare ~100+ file (include runtime)

# Verifica dimensione cartella
Get-ChildItem -Recurse | Measure-Object -Property Length -Sum
# Deve essere ~150+ MB se self-contained
# Se è ~60 MB, non è self-contained!
```

**Soluzione**: Ricrea package con `-SelfContained`:
```powershell
.\Create-DeploymentPackage.ps1 -SelfContained
```

### Problema: Database connection failed

```powershell
# Testa connessione SQL manualmente
sqlcmd -S localhost -d RagChatAppDB -Q "SELECT DB_NAME()"

# Se fallisce, verifica:
# 1. SQL Server service running
Get-Service | Where-Object {$_.Name -like "*SQL*"}

# 2. Connection string corretta in appsettings.json
notepad "C:\Program Files\RagChatApp\appsettings.json"
```

### Problema: Servizio non si avvia

```powershell
# Controlla Event Viewer
Get-EventLog -LogName Application -Source RagChatAppService -Newest 10

# Test manuale per vedere errori
cd "C:\Program Files\RagChatApp"
.\RagChatApp_Server.exe
# Leggi output errori
```

---

## 📊 Comparazione Modalità Deployment

| Caratteristica | Self-Contained | Framework-Dependent |
|----------------|-----------------|---------------------|
| **Dimensione package** | ~150-200 MB | ~60 MB |
| **Runtime richiesto** | ❌ No | ✅ Sì (.NET 9.0) |
| **File da trasferire** | 1 (ZIP) | 2 (ZIP + Installer) |
| **Setup server** | Più semplice | Richiede installazione runtime |
| **Aggiornamento runtime** | Richiede nuovo package | Aggiornabile separatamente |
| **Offline deployment** | ✅ Perfetto | ⚠️ Richiede installer |

---

## 🎯 Raccomandazioni

**Usa Self-Contained se**:
- ✅ Server completamente offline
- ✅ Nessun altro .NET app sul server
- ✅ Vuoi deployment più semplice
- ✅ Dimensione package non è problema

**Usa Framework-Dependent se**:
- ✅ Puoi installare runtime una volta
- ✅ Hai altre app .NET sul server
- ✅ Vuoi package più piccoli
- ✅ Vuoi aggiornare runtime separatamente

---

## 📚 Documentazione Aggiuntiva

- **Quick Start**: `QUICK_START_DEPLOYMENT.md`
- **Guida Completa**: `00_PRODUCTION_SETUP_GUIDE.md`
- **Prerequisiti**: `Check-Prerequisites.ps1`
- **Database**: `Database\README_DEPLOYMENT.md`

---

**Versione**: 1.0
**Ultimo aggiornamento**: Ottobre 2025
**Target**: Server Windows offline senza connettività internet
