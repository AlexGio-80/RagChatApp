# 📦 RagChatApp - Deployment Package Creation

Questa cartella contiene gli strumenti per creare package di deployment completi per RagChatApp.

---

## 🚀 Quick Start - Crea Package

### Opzione 1: Package Self-Contained (per server OFFLINE) ⭐

**Consigliato per server senza internet** - Include .NET Runtime nel package.

```powershell
.\Create-DeploymentPackage.ps1 -SelfContained

# Output: RagChatApp_DeploymentPackage_YYYYMMDD_HHMMSS.zip (~160 MB)
```

### Opzione 2: Package Framework-Dependent (per server online)

**Richiede .NET 9.0 Runtime sul server** - Package più piccolo.

```powershell
.\Create-DeploymentPackage.ps1

# Output: RagChatApp_DeploymentPackage_YYYYMMDD_HHMMSS.zip (~60 MB)
```

---

## 📋 File in Questa Cartella

### Script di Creazione Package
- **`Create-DeploymentPackage.ps1`** - Script principale per creare deployment package
  - Supporta modalità self-contained e framework-dependent
  - Include backend, frontend, database, documentazione
  - Crea ZIP pronto per il trasferimento

### Script di Deployment (inclusi nel package)
- **`Install-WindowsService.ps1`** - Installa l'app come Windows Service
- **`Install-RAG-Interactive.ps1`** - Installa RAG search (CLR o VECTOR)
- **`Check-Prerequisites.ps1`** - Verifica prerequisiti sul server target

### Database
- **`01_DatabaseSchema.sql`** - Schema database completo (auto-generato, idempotente)

### Documentazione
- **`README.md`** - Questo file
- **`QUICK_START_DEPLOYMENT.md`** 🇮🇹 - Guida rapida deployment (15-30 min)
- **`OFFLINE_DEPLOYMENT_GUIDE.md`** 🇮🇹 - Guida per server offline (self-contained)
- **`00_PRODUCTION_SETUP_GUIDE.md`** - Guida completa setup produzione
- **`README_DEPLOYMENT.md`** - Guida dettagliata database deployment
- **`README_PACKAGE_CREATION.md`** - Guida alla creazione package (questo processo)
- **`README_RAG_INSTALLATION.md`** - Guida installazione RAG search

---

## 🎯 Quale Modalità di Deployment Usare?

### ✅ Self-Contained - Quando Usarlo

**Ideale per**:
- ✅ Server senza connessione internet
- ✅ Server isolati/air-gapped
- ✅ Deployment su server dove non puoi installare prerequisiti
- ✅ Garantire versione runtime specifica

**Caratteristiche**:
- **Dimensione**: ~160 MB
- **Prerequisiti server**: Solo SQL Server
- **Setup**: Più semplice (no runtime install)
- **File da trasferire**: 1 (solo ZIP)

**Crea con**:
```powershell
.\Create-DeploymentPackage.ps1 -SelfContained
```

### ⚙️ Framework-Dependent - Quando Usarlo

**Ideale per**:
- ✅ Server con accesso internet
- ✅ Server dove .NET è già installato
- ✅ Deployment multipli sullo stesso server
- ✅ Package size importante

**Caratteristiche**:
- **Dimensione**: ~60 MB
- **Prerequisiti server**: SQL Server + .NET 9.0 Runtime
- **Setup**: Richiede installazione runtime
- **File da trasferire**: 1 (ZIP) o 2 (ZIP + Runtime Installer)

**Crea con**:
```powershell
.\Create-DeploymentPackage.ps1
```

---

## 📦 Cosa Include il Package

Entrambe le modalità includono:

```
RagChatApp_DeploymentPackage_YYYYMMDD_HHMMSS.zip
├── Application/                           # Backend compilato
│   ├── RagChatApp_Server.exe             # Eseguibile
│   ├── RagChatApp_Server.dll             # Applicazione
│   ├── appsettings.json                  # Config template (no credentials)
│   └── *.dll                             # Dipendenze + Runtime (se self-contained)
│
├── Frontend/                              # UI HTML/CSS/JS
│   ├── index.html
│   ├── css/
│   ├── js/
│   └── README_DEPLOYMENT.md
│
├── Database/
│   ├── 01_DatabaseSchema.sql             # Schema completo
│   ├── README_DEPLOYMENT.md
│   ├── StoredProcedures/                 # SQL Interface (opzionale)
│   │   ├── Install-MultiProvider.ps1
│   │   ├── CLR/                          # RAG implementation (SQL Server 2016+)
│   │   └── VECTOR/                       # RAG implementation (SQL Server 2025+)
│   └── Encryption/                       # AES-256 encryption scripts
│
├── Documentation/
│   ├── rag-database-schema.md
│   └── setup-configuration-guide.md
│
├── 00_PRODUCTION_SETUP_GUIDE.md          # Guida completa (ENG)
├── QUICK_START_DEPLOYMENT.md             # Guida rapida (ITA) ⭐
├── OFFLINE_DEPLOYMENT_GUIDE.md           # Guida offline (ITA)
├── README_RAG_INSTALLATION.md            # Guida RAG
├── DEPLOYMENT_CHECKLIST.txt              # Checklist verifica
├── Check-Prerequisites.ps1               # Verifica prerequisiti
├── Install-WindowsService.ps1            # Service installer
└── Install-RAG-Interactive.ps1           # RAG installer
```

---

## 🔧 Opzioni Avanzate Create-DeploymentPackage.ps1

```powershell
# Package completo (default)
.\Create-DeploymentPackage.ps1

# Self-contained per offline deployment
.\Create-DeploymentPackage.ps1 -SelfContained

# Solo database (no applicazione)
.\Create-DeploymentPackage.ps1 -IncludeApplication:$false

# Solo backend (no frontend)
.\Create-DeploymentPackage.ps1 -IncludeFrontend:$false

# Solo REST API (no stored procedures)
.\Create-DeploymentPackage.ps1 -IncludeStoredProcedures:$false

# Custom output location
.\Create-DeploymentPackage.ps1 -OutputPath "C:\Releases\RagChatApp_v1.3.1"

# Skip build (usa binari esistenti)
.\Create-DeploymentPackage.ps1 -SkipBuild

# Combinazioni
.\Create-DeploymentPackage.ps1 -SelfContained -IncludeFrontend:$false -OutputPath ".\Release_Offline"
```

---

## 📝 Processo di Deployment (Overview)

### Sul PC di Sviluppo

1. **Crea package**:
   ```powershell
   .\Create-DeploymentPackage.ps1 -SelfContained  # o senza -SelfContained
   ```

2. **Trasferisci ZIP** al server di produzione

### Sul Server di Produzione

1. **Estrai package**
2. **Verifica prerequisiti**: `.\Check-Prerequisites.ps1`
3. **Setup database**: Esegui `Database\01_DatabaseSchema.sql`
4. **Deploy applicazione**: Copia in `C:\Program Files\RagChatApp`
5. **Configura**: Modifica `appsettings.json`
6. **Test manuale**: `.\RagChatApp_Server.exe`
7. **Installa servizio**: `.\Install-WindowsService.ps1`
8. **(Opzionale) RAG**: `.\Install-RAG-Interactive.ps1`

**Tempo totale**: 15-30 minuti

---

## 📚 Guide di Deployment - Quale Leggere?

### Per Deploy Rapido (Server Online)
➡️ **`QUICK_START_DEPLOYMENT.md`** (Italiano, 15-30 min)

### Per Server Offline/Isolati
➡️ **`OFFLINE_DEPLOYMENT_GUIDE.md`** (Italiano, include self-contained)

### Per Setup Completo con Tutte le Opzioni
➡️ **`00_PRODUCTION_SETUP_GUIDE.md`** (Inglese, dettagliato)

### Per Solo Database
➡️ **`Database\README_DEPLOYMENT.md`**

### Per Capire Questo Processo
➡️ **`README_PACKAGE_CREATION.md`**

---

## 🆘 Troubleshooting Creazione Package

### Errore: "Application build failed"

```powershell
# Test build manualmente
cd ..\..\
dotnet build --configuration Release

# Se OK, retry package
cd Database\Deployment
.\Create-DeploymentPackage.ps1
```

### Package Troppo Grande (>250 MB)

Normale per self-contained (~160 MB). Se più grande:
- Verifica test files non inclusi
- Controlla dependencies non necessarie

### "Published application not found" con -SkipBuild

```powershell
# Prima pubblica manualmente
cd ..\..\
dotnet publish --configuration Release

# Poi crea package
cd Database\Deployment
.\Create-DeploymentPackage.ps1 -SkipBuild
```

---

## 🎯 Best Practices

### ✅ Prima di Creare Package
- [ ] Build locale funzionante (`dotnet build`)
- [ ] Test applicazione localmente
- [ ] Database migrations aggiornate
- [ ] Documenti aggiornati
- [ ] Nessuna credenziale in appsettings.json (template automatico)

### ✅ Naming Convention
```powershell
# Usa versioning
.\Create-DeploymentPackage.ps1 -OutputPath ".\Release_v1.3.1"

# O date
.\Create-DeploymentPackage.ps1 -OutputPath ".\Release_2025-10-06"
```

### ✅ Testing Package
1. Estrai ZIP in directory temporanea
2. Verifica presenza file chiave
3. Test su VM pulita (opzionale ma raccomandato)
4. Documenta eventuali problemi trovati

### ✅ Distribuzione
- Usa ZIP per trasferimento
- Hash verificabile: `Get-FileHash -Algorithm SHA256 RagChatApp_*.zip`
- Mantieni versioni precedenti archiviate (ultimi 3-5 release)

---

## 📊 Dimensioni Package (Reference)

| Tipo | App Files | Total Size | Runtime |
|------|-----------|------------|---------|
| **Framework-Dependent** | ~140 files | ~60 MB | No (richiesto su server) |
| **Self-Contained** | ~470 files | ~160 MB | Sì (incluso) |

---

## 🔄 Aggiornamento Schema Database

Quando modifichi il database:

```powershell
# 1. Crea migration (ambiente dev)
cd ..\..\
dotnet ef migrations add MigrationName

# 2. Aggiorna schema script per deployment
dotnet ef migrations script --idempotent --output "Database\Deployment\01_DatabaseSchema.sql"

# 3. Crea nuovo package
cd Database\Deployment
.\Create-DeploymentPackage.ps1 -SelfContained
```

Lo script `01_DatabaseSchema.sql` è **idempotente** - safe to rerun!

---

## 📞 Supporto

- **Issues deployment**: Vedi guide specifiche sopra
- **Build problems**: `dotnet build --verbosity detailed`
- **Prerequisiti**: Esegui `Check-Prerequisites.ps1` sul server target

---

**Versione**: 2.0
**Ultimo aggiornamento**: Ottobre 2025
**Compatibilità**: .NET 9.0, Windows Server 2016+, SQL Server 2019+
