# 🚀 Quick Start - Production Deployment Guide

**Tempo stimato**: 15-30 minuti per deployment completo

---

## 📦 Passo 1: Creare il Package di Deployment (5 min)

Dalla cartella `RagChatApp_Server\Database\Deployment`, esegui:

```powershell
# Package completo (Backend + Frontend + Database)
.\Create-DeploymentPackage.ps1

# O solo Backend e Database (senza frontend)
.\Create-DeploymentPackage.ps1 -IncludeFrontend:$false

# Package solo database (senza applicazione)
.\Create-DeploymentPackage.ps1 -IncludeApplication:$false
```

**Output**: File ZIP `RagChatApp_DeploymentPackage_YYYYMMDD_HHMMSS.zip`

---

## 🗄️ Passo 2: Setup Database (5 min)

### 2.1 Crea il Database

```sql
-- In SQL Server Management Studio (SSMS)
CREATE DATABASE RagChatAppDB;
GO
```

### 2.2 Esegui lo Schema Script

Dal package estratto, apri `Database\01_DatabaseSchema.sql` in SSMS e esegui (F5).

**Verifica**:
```sql
-- Deve mostrare 8 tabelle
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
```

---

## ⚙️ Passo 3: Deploy Applicazione Backend (5-10 min)

### 3.1 Copia i File

```powershell
# Crea directory installazione
New-Item -ItemType Directory -Path "C:\Program Files\RagChatApp" -Force

# Copia applicazione
Copy-Item -Path "Application\*" -Destination "C:\Program Files\RagChatApp" -Recurse -Force
```

### 3.2 Configura Connection String

Modifica `C:\Program Files\RagChatApp\appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=RagChatAppDB;Integrated Security=true;TrustServerCertificate=true"
  },
  "AIProvider": {
    "DefaultProvider": "Gemini",
    "Gemini": {
      "ApiKey": "LA-TUA-CHIAVE-GEMINI-QUI"
    }
  }
}
```

**💡 Alternative Connection Strings**:

```json
// SQL Authentication (utente SQL)
"DefaultConnection": "Server=localhost;Database=RagChatAppDB;User Id=rag_user;Password=Password123!;TrustServerCertificate=true"

// Server remoto
"DefaultConnection": "Server=192.168.1.100;Database=RagChatAppDB;User Id=rag_user;Password=Password123!;TrustServerCertificate=true"
```

### 3.3 Test Manuale

```powershell
cd "C:\Program Files\RagChatApp"
.\RagChatApp_Server.exe

# Aspetta che l'app si avvii (10-15 secondi)
# Output: "Now listening on: http://0.0.0.0:5000"

# In un'altra finestra PowerShell, testa:
Invoke-RestMethod -Uri "http://localhost:5000/health"

# Se OK, premi Ctrl+C per fermare
```

---

## 🖥️ Passo 4: Installa come Windows Service (5 min)

```powershell
# Dal package estratto, esegui come Administrator:
cd C:\Path\To\ExtractedPackage
.\Install-WindowsService.ps1 -ApplicationPath "C:\Program Files\RagChatApp"

# Lo script:
# ✅ Installa il servizio Windows
# ✅ Configura auto-start
# ✅ Avvia il servizio
# ✅ Testa gli endpoint
```

**Verifica servizio**:
```powershell
Get-Service RagChatAppService
# Status dovrebbe essere "Running"
```

---

## 🌐 Passo 5 (Opzionale): Deploy Frontend (5 min)

### Opzione A: IIS (Produzione - Consigliato)

```powershell
# Copia frontend
Copy-Item -Path "Frontend\*" -Destination "C:\inetpub\wwwroot\RagChatApp" -Recurse -Force

# Crea sito IIS
Import-Module WebAdministration
New-WebAppPool -Name "RagChatAppUI"
New-Website -Name "RagChatAppUI" `
    -PhysicalPath "C:\inetpub\wwwroot\RagChatApp" `
    -ApplicationPool "RagChatAppUI" `
    -Port 80
```

**Accedi a**: http://localhost

### Opzione B: Server Semplice (Sviluppo/Test)

```powershell
cd Frontend
npm install -g http-server
http-server -p 3000 -c-1
```

**Accedi a**: http://localhost:3000

---

## 🔍 Passo 6 (Opzionale): Installa RAG Search (5 min)

⚠️ **Richiesto per**: Ricerca documenti, chat AI con contesto

```powershell
# Dal package estratto, esegui:
.\Install-RAG-Interactive.ps1 `
    -ServerInstance "localhost" `
    -DatabaseName "RagChatAppDB" `
    -GeminiApiKey "LA-TUA-CHIAVE-GEMINI-QUI" `
    -DefaultProvider "Gemini"

# Lo script:
# ✅ Rileva versione SQL Server
# ✅ Raccomanda CLR o VECTOR
# ✅ Installa implementazione RAG
# ✅ Verifica installazione
```

---

## ✅ Verifica Finale

### Test Endpoint API
```powershell
# Health check
Invoke-RestMethod -Uri "http://localhost:5000/health"
# Output: {"status":"Healthy","database":"Connected"}

# Info applicazione
Invoke-RestMethod -Uri "http://localhost:5000/api/info"
# Output: {"version":"1.3.1","provider":"Gemini"}

# Swagger UI
Start-Process "http://localhost:5000/swagger"
```

### Test Upload Documento (dalla UI o Swagger)
1. Apri http://localhost:5000/swagger
2. Trova POST `/api/documents/upload`
3. Carica un PDF di test
4. Verifica che lo status diventi "Completed"

### Test Chat (dalla UI)
1. Apri il frontend
2. Vai alla sezione Chat
3. Scrivi: "Cosa contiene questo documento?"
4. Verifica risposta AI con chunks rilevanti

---

## 🔧 Troubleshooting Rapido

### Problema: Servizio non si avvia

```powershell
# Verifica .NET Runtime installato
dotnet --list-runtimes
# Deve mostrare: Microsoft.AspNetCore.App 9.0.x

# Controlla Event Viewer
Get-EventLog -LogName Application -Source RagChatAppService -Newest 10
```

### Problema: Errore connessione database

```powershell
# Testa connessione SQL
sqlcmd -S localhost -d RagChatAppDB -Q "SELECT DB_NAME()"

# Verifica SQL Server service
Get-Service | Where-Object {$_.Name -like "*SQL*"}
```

### Problema: CORS Error (frontend → backend)

Nel `appsettings.json` backend, aggiungi:

```json
{
  "Cors": {
    "AllowedOrigins": [
      "http://localhost:3000",
      "http://localhost"
    ]
  }
}
```

Poi riavvia il servizio:
```powershell
Restart-Service RagChatAppService
```

---

## 📋 Checklist Deployment Completo

- [ ] ✅ Database creato e schema applicato
- [ ] ✅ Application backend copiata in `C:\Program Files\RagChatApp`
- [ ] ✅ Connection string e API keys configurate
- [ ] ✅ Test manuale applicazione eseguito
- [ ] ✅ Windows Service installato e avviato
- [ ] ✅ Health endpoint risponde correttamente
- [ ] ✅ (Opzionale) Frontend deployato su IIS o server
- [ ] ✅ (Opzionale) RAG Search installato
- [ ] ✅ Test upload documento completato
- [ ] ✅ Test chat AI completato

---

## 📚 Documentazione Dettagliata

Se hai bisogno di dettagli o opzioni avanzate:

- **Guida Completa**: `00_PRODUCTION_SETUP_GUIDE.md` (nel package)
- **Database**: `Database\README_DEPLOYMENT.md`
- **RAG Installation**: `README_RAG_INSTALLATION.md`
- **Package Creation**: `README_PACKAGE_CREATION.md`
- **Stored Procedures**: `Database\StoredProcedures\README.md`

---

## 🎯 Comandi Utili Post-Deploy

```powershell
# Gestione servizio
Get-Service RagChatAppService              # Status
Start-Service RagChatAppService            # Avvia
Stop-Service RagChatAppService             # Ferma
Restart-Service RagChatAppService          # Riavvia

# Test API
Invoke-RestMethod "http://localhost:5000/health"
Invoke-RestMethod "http://localhost:5000/api/info"
Invoke-RestMethod "http://localhost:5000/api/documents"

# Apertura interfacce
Start-Process "http://localhost:5000/swagger"      # API Swagger
Start-Process "http://localhost"                   # Frontend (se IIS)

# Backup database
sqlcmd -S localhost -d RagChatAppDB -Q "BACKUP DATABASE [RagChatAppDB] TO DISK = 'C:\Backup\RagChatAppDB.bak' WITH COMPRESSION"
```

---

## 📞 Supporto

In caso di problemi:

1. **Controlla Event Viewer**: `eventvwr.msc` → Windows Logs → Application
2. **Consulta log servizio**: `C:\Program Files\RagChatApp\logs\` (se usi NSSM)
3. **Leggi documentazione dettagliata**: Vedi sezione "Documentazione Dettagliata" sopra
4. **Verifica prerequisiti**: .NET 9.0 Runtime, SQL Server 2019+

---

**Versione**: 1.0
**Ultimo aggiornamento**: Ottobre 2025
**Compatibilità**: .NET 9.0, SQL Server 2019+, Windows Server 2016+
