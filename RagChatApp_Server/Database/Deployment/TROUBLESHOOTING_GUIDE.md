# Guida Completa al Troubleshooting - RagChatApp Deployment

## 📚 Indice

1. [Problemi di Deployment](#problemi-di-deployment)
2. [Problemi del Windows Service](#problemi-del-windows-service)
3. [Problemi di Configurazione](#problemi-di-configurazione)
4. [Problemi di Database](#problemi-di-database)
5. [Problemi di Rete](#problemi-di-rete)
6. [Strumenti Diagnostici](#strumenti-diagnostici)

---

## 1. Problemi di Deployment

### ❌ Pacchetto troppo piccolo (60MB invece di 160MB)

**Sintomo**: Il pacchetto ZIP creato è circa 60MB

**Diagnosi**:
```powershell
.\Debug-Package.ps1
```

**Spiegazione**:
- ✅ **60MB è CORRETTO** per un pacchetto self-contained **compresso**
- Quando estratto, diventa ~155MB con 400+ DLL
- La compressione ZIP riduce le dimensioni di ~60%

**Verifica**:
```powershell
.\Verify-Zip.ps1 -ZipPath ".\RagChatApp_DeploymentPackage_*.zip"
# Dovrebbe mostrare:
# - ZIP: ~60MB
# - Estratto: ~155MB
# - DLL: 400+
# - System.*.dll: 180+
```

**Se veramente mancano le DLL**:
```powershell
# Forza rebuild completo
.\Create-DeploymentPackage.ps1 -SelfContained

# Se ancora problemi, pulisci manualmente
Remove-Item "..\..\bin" -Recurse -Force
Remove-Item "..\..\obj" -Recurse -Force
dotnet clean --configuration Release
.\Create-DeploymentPackage.ps1 -SelfContained
```

### ❌ .NET Runtime mancante sul server

**Sintomo**:
```
Framework: 'Microsoft.AspNetCore.App', version '9.0.0' (x64) was not found
```

**Soluzione 1**: Usa self-contained deployment (include runtime)
```powershell
.\Create-DeploymentPackage.ps1 -SelfContained
```

**Soluzione 2**: Installa .NET 9.0 Runtime sul server
```powershell
# Scarica installer da:
https://dotnet.microsoft.com/download/dotnet/9.0

# Installa ASP.NET Core Runtime 9.0
```

---

## 2. Problemi del Windows Service

### ❌ Timeout all'avvio del servizio

**Sintomo**:
```
Il servizio non ha risposto alla richiesta di avvio o controllo nel tempo previsto
```

**Causa 1**: Program.cs manca di `UseWindowsService()` ✅ **RISOLTO**

**Verifica**:
```powershell
.\Diagnose-WindowsService.ps1
```

**Fix applicato**: Aggiunto `builder.Host.UseWindowsService();` a Program.cs (linea 11)

**Richiede**: Ricompilare e redistribuire l'applicazione (vedi SERVICE_TIMEOUT_FIX.md)

---

**Causa 2**: Database migration troppo lenta

**Soluzione**: Aumenta timeout del servizio
```powershell
# Timeout a 120 secondi
reg add HKLM\SYSTEM\CurrentControlSet\Control /v ServicesPipeTimeout /t REG_DWORD /d 120000 /f

# RIAVVIA IL SERVER
Restart-Computer
```

---

**Causa 3**: Errori di configurazione bloccano l'avvio

**Diagnostica Event Log**:
```powershell
Get-EventLog -LogName Application -Source "RagChatAppService" -Newest 10 |
    Format-Table TimeGenerated, EntryType, Message -AutoSize
```

Cerca errori relativi a:
- Connection string non valida
- API key mancante
- Porta già in uso
- File mancanti

---

### ❌ Servizio si ferma subito dopo l'avvio

**Diagnostica**:
```powershell
# Avvia servizio e guarda Event Log in tempo reale
Start-Service -Name "RagChatAppService"
Get-EventLog -LogName Application -Newest 1 -Source "RagChatAppService"
```

**Cause comuni**:
1. **Database non raggiungibile**: Verifica connection string
2. **Porta in uso**: Cambia porta in appsettings.json
3. **File mancanti**: Verifica che tutti i file siano estratti

---

### ❌ Servizio non si installa

**Sintomo**:
```
sc.exe create failed
```

**Verifica permessi**:
```powershell
# Verifica di essere Administrator
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
# Deve restituire: True
```

**Verifica file eseguibile**:
```powershell
Test-Path "C:\OSLAI-2025\OSL_RagChatApp\Application\RagChatApp_Server.exe"
# Deve restituire: True
```

---

## 3. Problemi di Configurazione

### ❌ Errore JSON syntax in appsettings.json

**Sintomo**:
```
System.Text.Json.JsonReaderException: '"' is invalid after a value. Expected either ',', '}', or ']'. LineNumber: 31
```

**Diagnostica**:
```powershell
.\Validate-AppSettings.ps1 -FilePath "C:\Path\To\appsettings.json"
```

Lo script mostra:
- ✅ Numero di riga esatto dell'errore
- ✅ Contesto (righe prima/dopo)
- ✅ Suggerimenti per il fix

**Errori comuni**:
1. **Virgola mancante**:
   ```json
   "Key1": "value1"   // ❌ manca virgola
   "Key2": "value2"
   ```
   Dovrebbe essere:
   ```json
   "Key1": "value1",  // ✅ virgola aggiunta
   "Key2": "value2"
   ```

2. **Virgola extra**:
   ```json
   "Key": "value",  // ❌ virgola extra prima di }
   }
   ```

3. **Backslash non escapato** (nei path Windows):
   ```json
   "Path": "C:\Temp"  // ❌ Sbagliato
   "Path": "C:\\Temp" // ✅ Corretto
   "Path": "C:/Temp"  // ✅ Alternativa
   ```

**Usa template corretti**:
```powershell
# HTTP-only (niente HTTPS)
Copy-Item "appsettings.HTTP-ONLY.json" "appsettings.json"

# Porta 8080
Copy-Item "appsettings.PORT-8080.json" "appsettings.json"

# Template completo
Copy-Item "appsettings.TEMPLATE.json" "appsettings.json"
```

---

### ❌ Certificato HTTPS mancante

**Sintomo**:
```
Unable to configure HTTPS endpoint. No server certificate was specified
```

**Soluzione 1**: Rimuovi HTTPS (network interno)
```powershell
.\Fix-HttpsConfiguration.ps1 -Action DisableHttps -AppSettingsPath "C:\Path\appsettings.json"
```

**Soluzione 2**: Usa template HTTP-only
```powershell
Copy-Item "appsettings.HTTP-ONLY.json" "appsettings.json"
```

**Soluzione 3**: Genera certificato di sviluppo (solo per testing!)
```powershell
.\Fix-HttpsConfiguration.ps1 -Action GenerateDevCert
# NON usare in produzione!
```

**Soluzione 4**: Usa certificato produzione
```json
{
  "Kestrel": {
    "Endpoints": {
      "Https": {
        "Url": "https://0.0.0.0:443",
        "Certificate": {
          "Path": "C:\\Certificates\\mycert.pfx",
          "Password": "your-cert-password"
        }
      }
    }
  }
}
```

---

## 4. Problemi di Database

### ❌ Connection string non valida

**Sintomo**:
```
A network-related or instance-specific error occurred while establishing a connection to SQL Server
```

**Verifica connection string**:
```powershell
# Test connessione SQL
sqlcmd -S "localhost" -d "RagChatAppDB" -Q "SELECT 1"

# Con autenticazione SQL
sqlcmd -S "localhost" -U "sa" -P "password" -d "RagChatAppDB" -Q "SELECT 1"
```

**Formati connection string corretti**:

**Windows Authentication** (raccomandato):
```json
"DefaultConnection": "Server=localhost;Database=RagChatAppDB;Integrated Security=true;TrustServerCertificate=true"
```

**SQL Authentication**:
```json
"DefaultConnection": "Server=localhost;Database=RagChatAppDB;User Id=sa;Password=YourPassword;TrustServerCertificate=true"
```

**Named Instance**:
```json
"DefaultConnection": "Server=localhost\\SQLEXPRESS;Database=RagChatAppDB;Integrated Security=true;TrustServerCertificate=true"
```

**Server remoto**:
```json
"DefaultConnection": "Server=192.168.1.100,1433;Database=RagChatAppDB;Integrated Security=true;TrustServerCertificate=true"
```

---

### ❌ Database non esiste

**Soluzione**: L'app crea automaticamente il database all'avvio

Se preferisci crearlo manualmente:
```sql
-- Esegui in SQL Server Management Studio
CREATE DATABASE RagChatAppDB;
GO

-- Esegui schema script
USE RagChatAppDB;
GO
:r "C:\OSLAI-2025\OSL_RagChatApp\DeploymentPackage\Database\01_DatabaseSchema.sql"
GO
```

---

### ❌ Migration fallisce

**Sintomo nell'Event Log**:
```
An error occurred during database migration
```

**Diagnostica**:
1. Verifica permessi database:
   ```sql
   -- L'utente deve avere db_owner o almeno db_ddladmin + db_datareader + db_datawriter
   EXEC sp_helpuser 'domain\serviceaccount'
   ```

2. Applica schema manualmente:
   ```sql
   USE RagChatAppDB;
   :r "01_DatabaseSchema.sql"
   ```

3. Verifica migrazioni applicate:
   ```sql
   SELECT * FROM __EFMigrationsHistory ORDER BY MigrationId;
   -- Dovrebbe mostrare 3 migrazioni
   ```

---

## 5. Problemi di Rete

### ❌ Porta 5000 in uso (Error 10013)

**Sintomo**:
```
System.Net.Sockets.SocketException (10013): Tentativo di accesso al socket con modalità non consentite
```

**Diagnostica**:
```powershell
.\Fix-PortConflict.ps1 -Port 5000
```

Lo script mostra:
- ✅ Quale processo sta usando la porta
- ✅ Se la porta è riservata da Windows
- ✅ Porte alternative disponibili

**Soluzione 1**: Usa porta alternativa
```powershell
# Usa template con porta 8080
Copy-Item "appsettings.PORT-8080.json" "appsettings.json"
```

**Soluzione 2**: Ferma processo che usa la porta
```powershell
# Trova processo
Get-NetTCPConnection -LocalPort 5000 | Select-Object OwningProcess

# Ferma processo (ATTENZIONE!)
Stop-Process -Id <PID> -Force
```

**Soluzione 3**: Se la porta è riservata da Windows (Hyper-V)
```powershell
# Usa SEMPRE una porta diversa (es. 8080)
# Non puoi liberare porte riservate da Windows
```

---

### ❌ Firewall blocca le connessioni

**Verifica**:
```powershell
# Testa localmente prima
Invoke-RestMethod -Uri "http://localhost:8080/health"

# Se funziona localmente ma non dalla rete, è firewall
```

**Soluzione**: Crea regola firewall
```powershell
# Consenti porta 8080 in entrata
New-NetFirewallRule -DisplayName "RagChatApp HTTP" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 8080 `
    -Action Allow `
    -Profile Domain,Private

# Verifica regola creata
Get-NetFirewallRule -DisplayName "RagChatApp HTTP"
```

---

### ❌ CORS blocca richieste dal frontend

**Sintomo** (browser console):
```
Access to fetch at 'http://server:8080/api/...' from origin 'http://frontend:3000' has been blocked by CORS policy
```

**Verifica configurazione CORS** in appsettings.json:
```json
{
  "AllowedOrigins": ["http://localhost:3000", "http://192.168.1.100"]
}
```

**Nel Program.cs** (già configurato):
```csharp
app.UseCors("AllowAll");  // Permette tutte le origini
```

---

## 6. Strumenti Diagnostici

### 🔍 Check-Prerequisites.ps1
Verifica prerequisiti server:
```powershell
.\Check-Prerequisites.ps1
```

Controlla:
- Windows OS
- PowerShell 5.1+
- .NET 9.0 Runtime (se non self-contained)
- SQL Server disponibile
- Spazio disco (almeno 500MB)
- Permessi Administrator

---

### 🔍 Validate-AppSettings.ps1
Valida sintassi JSON:
```powershell
.\Validate-AppSettings.ps1 -FilePath "C:\Path\appsettings.json"
```

Mostra:
- ✅ Errori di sintassi con numero di riga
- ✅ Contesto dell'errore
- ✅ Offre di creare backup e usare template

---

### 🔍 Diagnose-WindowsService.ps1
Diagnostica completa del servizio:
```powershell
.\Diagnose-WindowsService.ps1 `
    -ServiceName "RagChatAppService" `
    -ApplicationPath "C:\OSLAI-2025\OSL_RagChatApp\Application"
```

Verifica:
- ✅ Servizio esiste e stato
- ✅ File applicazione presenti (EXE, DLL, appsettings.json)
- ✅ Errori recenti nell'Event Log
- ✅ Configurazione timeout servizio
- ✅ Test di avvio manuale (5 secondi)

Fornisce raccomandazioni specifiche.

---

### 🔍 Fix-HttpsConfiguration.ps1
Gestione configurazione HTTPS:
```powershell
# Mostra info HTTPS corrente
.\Fix-HttpsConfiguration.ps1 -Action ShowInfo -AppSettingsPath "path\appsettings.json"

# Rimuovi HTTPS endpoint
.\Fix-HttpsConfiguration.ps1 -Action DisableHttps -AppSettingsPath "path\appsettings.json"

# Genera certificato sviluppo
.\Fix-HttpsConfiguration.ps1 -Action GenerateDevCert
```

---

### 🔍 Fix-PortConflict.ps1
Diagnostica conflitti di porta:
```powershell
.\Fix-PortConflict.ps1 -Port 5000
```

Mostra:
- ✅ Processo che usa la porta
- ✅ Porte riservate da Windows
- ✅ Regole firewall esistenti
- ✅ Porte alternative disponibili (8080, 8081, 9000, ecc.)

---

### 🔍 Debug-Package.ps1 e Verify-Zip.ps1
Verifica pacchetto deployment:
```powershell
# Quick check
.\Debug-Package.ps1

# Analisi completa del ZIP
.\Verify-Zip.ps1 -ZipPath ".\RagChatApp_DeploymentPackage_*.zip"
```

Verifica:
- ✅ Dimensione ZIP vs estratto
- ✅ Numero di DLL (dovrebbe essere 400+)
- ✅ Presenza System.*.dll (conferma self-contained)
- ✅ Presenza file critici (EXE, appsettings, database scripts)

---

## 📋 Checklist Diagnostica Completa

Quando qualcosa non funziona, esegui in ordine:

1. **Prerequisites**:
   ```powershell
   .\Check-Prerequisites.ps1
   ```

2. **Package**:
   ```powershell
   .\Debug-Package.ps1
   .\Verify-Zip.ps1 -ZipPath ".\RagChatApp_*.zip"
   ```

3. **Configuration**:
   ```powershell
   .\Validate-AppSettings.ps1 -FilePath "C:\App\appsettings.json"
   ```

4. **Network**:
   ```powershell
   .\Fix-PortConflict.ps1 -Port 8080
   ```

5. **Service**:
   ```powershell
   .\Diagnose-WindowsService.ps1
   ```

6. **Event Log**:
   ```powershell
   Get-EventLog -LogName Application -Source "RagChatAppService" -Newest 10
   ```

7. **Database**:
   ```powershell
   sqlcmd -S localhost -d RagChatAppDB -Q "SELECT * FROM __EFMigrationsHistory"
   ```

---

## 🆘 Contatti e Supporto

Se nessuna di queste soluzioni funziona:

1. **Raccogli log completi**:
   ```powershell
   Get-EventLog -LogName Application -Source "RagChatAppService" -Newest 50 > "C:\Temp\service_logs.txt"
   ```

2. **Esporta configurazione** (RIMUOVI API KEYS PRIMA!):
   ```powershell
   Get-Content "C:\App\appsettings.json" > "C:\Temp\config_sanitized.json"
   ```

3. **Diagnostica completa**:
   ```powershell
   .\Diagnose-WindowsService.ps1 > "C:\Temp\diagnostic_report.txt"
   ```

Invia questi file per analisi dettagliata.
