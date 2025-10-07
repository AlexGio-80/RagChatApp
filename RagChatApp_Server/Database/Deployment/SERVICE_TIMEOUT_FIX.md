# Fix del Timeout del Windows Service

## 🔧 Problema Identificato

**Errore**: "Il servizio non ha risposto alla richiesta di avvio o controllo nel tempo previsto"

**Causa**: Il file `Program.cs` **mancava** della configurazione per eseguire l'applicazione come Windows Service.

## ✅ Soluzione Applicata

Ho aggiunto questa riga critica a `Program.cs` (linea 11):

```csharp
var builder = WebApplication.CreateBuilder(args);

// Configure application to run as Windows Service
builder.Host.UseWindowsService();  // <-- AGGIUNTA QUESTA RIGA

// Add services to the container
builder.Services.AddControllers();
```

**Cosa fa**: `UseWindowsService()` configura l'applicazione ASP.NET Core per:
- Rispondere correttamente ai comandi del Service Control Manager
- Gestire gli eventi di avvio/arresto del servizio Windows
- Utilizzare Event Log per il logging invece della console
- Non bloccarsi in attesa di input dalla console

## 📦 Prossimi Passi Obbligatori

### 1. Ricompilare l'Applicazione (sul PC di sviluppo)

```powershell
cd C:\OSL\Claude\RagChatApp\RagChatApp_Server

# Clean completo
dotnet clean --configuration Release
Remove-Item -Path ".\bin" -Recurse -Force -ErrorAction SilentlyContinue

# Build e verifica
dotnet build --configuration Release

# Verificare che compili senza errori
```

### 2. Creare Nuovo Pacchetto di Deployment

```powershell
cd Database\Deployment

# Creare pacchetto self-contained con il fix
.\Create-DeploymentPackage.ps1 -SelfContained

# Output: RagChatApp_DeploymentPackage_YYYYMMDD_HHMMSS.zip (~60MB)
```

### 3. Copiare il Nuovo Pacchetto sul Server

```powershell
# Copiare il file ZIP sul server di produzione
# Esempio: copia in C:\Temp\
```

### 4. Sul Server: Fermare e Disinstallare il Servizio Vecchio

```powershell
# Apri PowerShell come Amministratore sul server

# Ferma il servizio se è in esecuzione
Stop-Service -Name "RagChatAppService" -ErrorAction SilentlyContinue

# Disinstalla il servizio
sc.exe delete RagChatAppService

# Verifica che sia stato rimosso
Get-Service -Name "RagChatAppService" -ErrorAction SilentlyContinue
# Dovrebbe dare errore "Cannot find service"
```

### 5. Sul Server: Estrarre il Nuovo Pacchetto

```powershell
# Rimuovi la vecchia installazione
$appPath = "C:\OSLAI-2025\OSL_RagChatApp\Application"
if (Test-Path $appPath) {
    Remove-Item -Path $appPath -Recurse -Force
}

# Estrai il nuovo ZIP
Expand-Archive -Path "C:\Temp\RagChatApp_DeploymentPackage_*.zip" `
               -DestinationPath "C:\OSLAI-2025\OSL_RagChatApp" `
               -Force

# Verifica che ci siano i file
Get-ChildItem $appPath
# Dovresti vedere RagChatApp_Server.exe, appsettings.json, e ~400 DLL
```

### 6. Sul Server: Configurare appsettings.json

```powershell
cd C:\OSLAI-2025\OSL_RagChatApp\Application

# Usa uno dei template forniti o modifica manualmente
# RACCOMANDATO: usa porta 8080 invece di 5000
Copy-Item "appsettings.PORT-8080.json" "appsettings.json" -Force

# Modifica con i tuoi valori
notepad appsettings.json
```

**Configurazione minima richiesta**:
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=RagChatAppDB;Integrated Security=true;TrustServerCertificate=true"
  },
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:8080"  // Usa 8080 invece di 5000
      }
    }
  },
  "AIProvider": {
    "DefaultProvider": "Gemini",
    "Gemini": {
      "ApiKey": "your-gemini-api-key-here"
    }
  }
}
```

### 7. Sul Server: Reinstallare il Windows Service

```powershell
# Assicurati di essere nella cartella Deployment
cd C:\OSLAI-2025\OSL_RagChatApp\DeploymentPackage

# Installa il servizio con il nuovo eseguibile
.\Install-WindowsService.ps1 `
    -ApplicationPath "C:\OSLAI-2025\OSL_RagChatApp\Application"

# Output atteso:
# ✅ Service created successfully
# ✅ Service started successfully
```

### 8. Verifica che il Servizio Funzioni

```powershell
# Verifica stato servizio
Get-Service -Name "RagChatAppService"
# Status dovrebbe essere "Running"

# Testa l'endpoint
Invoke-RestMethod -Uri "http://localhost:8080/health"
# Dovrebbe restituire: {"status":"Healthy","timestamp":"..."}

# Verifica Event Log
Get-EventLog -LogName Application -Source "RagChatAppService" -Newest 5
# Dovrebbe mostrare "Application started" senza errori
```

## 🔍 Diagnostica (se il servizio ancora non parte)

Se il servizio continua a non partire, esegui lo script diagnostico:

```powershell
cd C:\OSLAI-2025\OSL_RagChatApp\DeploymentPackage
.\Diagnose-WindowsService.ps1
```

Lo script verifica:
- ✅ Servizio esiste
- ✅ File applicazione presenti
- ✅ Errori recenti nell'Event Log
- ✅ Timeout configurato
- ✅ Test di avvio manuale

## ⏱️ Timeout del Servizio (Opzionale)

Se il database impiega molto tempo a migrare all'avvio, puoi aumentare il timeout:

```powershell
# Aumenta timeout a 120 secondi (default è 30)
reg add HKLM\SYSTEM\CurrentControlSet\Control `
    /v ServicesPipeTimeout `
    /t REG_DWORD `
    /d 120000 `
    /f

# RIAVVIA IL SERVER per applicare
Restart-Computer
```

## 📋 Checklist Completa

- [ ] ✅ Ricompilato RagChatApp_Server con Program.cs aggiornato
- [ ] ✅ Creato nuovo pacchetto deployment con `-SelfContained`
- [ ] ✅ Copiato ZIP sul server
- [ ] ✅ Fermato e disinstallato servizio vecchio
- [ ] ✅ Estratto nuovo pacchetto in `C:\OSLAI-2025\OSL_RagChatApp\Application`
- [ ] ✅ Configurato `appsettings.json` con connection string e API key
- [ ] ✅ Usato porta 8080 invece di 5000
- [ ] ✅ Installato nuovo servizio Windows
- [ ] ✅ Servizio parte con status "Running"
- [ ] ✅ Endpoint `/health` risponde correttamente
- [ ] ✅ Nessun errore nell'Event Log

## 🎯 Risultato Atteso

Dopo questi passaggi, il servizio dovrebbe:
- Partire senza timeout
- Rimanere in esecuzione
- Rispondere alle richieste HTTP
- Loggare correttamente nell'Event Log

Il timeout era causato dal fatto che l'applicazione **non sapeva** di essere un Windows Service. Ora, con `UseWindowsService()`, risponde correttamente al Service Control Manager.
