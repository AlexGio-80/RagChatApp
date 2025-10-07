# Guida al Sistema di Logging - RagChatApp

## 📋 Panoramica

RagChatApp utilizza **Serilog** per un sistema di logging completo e strutturato con supporto per:
- ✅ Log su file con rotazione giornaliera
- ✅ Log su console con formattazione colorata
- ✅ Logging automatico di richieste/risposte HTTP
- ✅ Log strutturati con proprietà
- ✅ Enrichment con info ambiente (machine, thread, ecc.)
- ✅ Retention automatica (30 giorni per log normali, 90 per errori)

## 📁 Struttura dei File di Log

```
RagChatApp_Server/
└── Logs/
    ├── ragchatapp-20251007.log          # Log generale del giorno
    ├── ragchatapp-errors-20251007.log   # Solo errori del giorno
    ├── ragchatapp-20251006.log          # Log del giorno precedente
    └── ...
```

### Caratteristiche File Log
- **Rolling Interval**: Giornaliero (nuovo file ogni giorno)
- **Retention**: 30 giorni per log generali, 90 giorni per errori
- **Max Size**: 100MB per file (crea nuovo file se superato)
- **Formato**: Timestamp completo + Level + SourceContext + ThreadId + Message

## 🎯 Livelli di Log

```csharp
LogLevel.Trace       // Dettagli tecnici molto granulari (disabilitato di default)
LogLevel.Debug       // Informazioni di debug per sviluppo
LogLevel.Information // Eventi normali dell'applicazione
LogLevel.Warning     // Situazioni inusuali ma non critiche
LogLevel.Error       // Errori gestibili
LogLevel.Critical    // Errori critici che richiedono attenzione immediata
```

### Configurazione Livelli (appsettings.json)

```json
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Debug",
      "Override": {
        "Microsoft": "Information",
        "Microsoft.AspNetCore": "Warning",
        "Microsoft.EntityFrameworkCore": "Warning",
        "System": "Information"
      }
    }
  }
}
```

## 🔧 Come Usare il Logging nei Servizi

### 1. Iniettare ILogger

```csharp
public class MyService
{
    private readonly ILogger<MyService> _logger;

    public MyService(ILogger<MyService> logger)
    {
        _logger = logger;
    }
}
```

### 2. Log di Ingresso/Uscita Metodi

```csharp
public async Task<Document> ProcessDocumentAsync(int documentId)
{
    _logger.LogInformation("➡️  Entering ProcessDocumentAsync - DocumentId: {DocumentId}", documentId);

    try
    {
        // ... logica del metodo ...

        _logger.LogInformation("✅ Completed ProcessDocumentAsync - DocumentId: {DocumentId} | Duration: {Duration}ms",
            documentId, stopwatch.ElapsedMilliseconds);

        return result;
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "❌ Error in ProcessDocumentAsync - DocumentId: {DocumentId}", documentId);
        throw;
    }
}
```

### 3. Logging Strutturato con Proprietà

```csharp
// ✅ CORRETTO - Structured logging
_logger.LogInformation("Processing document {FileName} with size {FileSize} bytes",
    document.FileName, document.FileSize);

// ❌ SBAGLIATO - String interpolation (perde proprietà strutturate)
_logger.LogInformation($"Processing document {document.FileName} with size {document.FileSize} bytes");
```

### 4. Scope Logging per Correlazione

```csharp
using (_logger.BeginScope("DocumentId: {DocumentId}", documentId))
{
    _logger.LogInformation("Starting processing");
    // ... altre operazioni ...
    _logger.LogInformation("Generating embeddings");
    // Tutte le log in questo scope avranno DocumentId come proprietà
}
```

### 5. Log con Timing

```csharp
var stopwatch = Stopwatch.StartNew();

try
{
    // ... operazione ...

    stopwatch.Stop();
    _logger.LogInformation("Operation completed in {Duration}ms", stopwatch.ElapsedMilliseconds);
}
catch (Exception ex)
{
    stopwatch.Stop();
    _logger.LogError(ex, "Operation failed after {Duration}ms", stopwatch.ElapsedMilliseconds);
    throw;
}
```

## 🌐 Logging Automatico HTTP

Il middleware `RequestResponseLoggingMiddleware` logga automaticamente:

### Request Log
```
[10:15:30 INF] ➡️  REQUEST [a1b2c3d4] GET http://localhost:5000/api/documents?status=completed | ContentType: none | ContentLength: unknown
```

### Response Log
```
[10:15:31 INF] ✅ RESPONSE [a1b2c3d4] GET /api/documents | Status: 200 | Duration: 45ms
```

### Slow Request Warning
```
[10:15:35 WRN] 🐌 SLOW REQUEST [e5f6g7h8] POST /api/documents/upload took 3542ms
```

### Request Failed
```
[10:15:32 ERR] ❌ REQUEST FAILED [i9j0k1l2] POST /api/chat | Duration: 156ms
System.InvalidOperationException: AI provider not configured
```

## 📊 Esempio di Log File

```log
[2025-10-07 10:15:30.123 +02:00] [INF] [RagChatApp_Server.Program] [1] === Starting RagChatApp Server ===
[2025-10-07 10:15:31.456 +02:00] [INF] [Microsoft.Hosting.Lifetime] [1] Now listening on: http://localhost:5000
[2025-10-07 10:15:32.789 +02:00] [INF] [RagChatApp_Server.Middleware.RequestResponseLoggingMiddleware] [8] ➡️  REQUEST [a1b2c3d4] GET http://localhost:5000/api/documents | ContentType: none | ContentLength: unknown
[2025-10-07 10:15:32.890 +02:00] [INF] [RagChatApp_Server.Services.DocumentProcessingService] [8] Extracting text from file: report.pdf, Type: application/pdf
[2025-10-07 10:15:33.125 +02:00] [INF] [RagChatApp_Server.Services.DocumentProcessingService] [8] Extracted 15234 characters from PDF with 12 headers detected
[2025-10-07 10:15:33.250 +02:00] [INF] [RagChatApp_Server.Middleware.RequestResponseLoggingMiddleware] [8] ✅ RESPONSE [a1b2c3d4] GET /api/documents | Status: 200 | Duration: 461ms
```

## 🔍 Query sui Log

### Cerca Errori
```bash
# Windows PowerShell
Select-String -Path "Logs\ragchatapp-*.log" -Pattern "\[ERR\]" | Select-Object -Last 20

# Linux/Mac
grep '\[ERR\]' Logs/ragchatapp-*.log | tail -20
```

### Cerca Request Lente
```bash
Select-String -Path "Logs\ragchatapp-*.log" -Pattern "SLOW REQUEST"
```

### Cerca per RequestId
```bash
Select-String -Path "Logs\ragchatapp-*.log" -Pattern "\[a1b2c3d4\]"
```

### Cerca Operazioni su Documento Specifico
```bash
Select-String -Path "Logs\ragchatapp-*.log" -Pattern "DocumentId: 123"
```

## ⚙️ Configurazione Avanzata

### Cambio Livello di Log (senza rebuild)

Modifica `appsettings.json` e riavvia l'applicazione:

```json
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information"  // Debug → Information per produzione
    }
  }
}
```

### Aggiungere Sink Aggiuntivi

Esempio: Aggiungere Elasticsearch o Seq

```json
{
  "Serilog": {
    "WriteTo": [
      { "Name": "Console" },
      { "Name": "File", "Args": { ... } },
      {
        "Name": "Seq",
        "Args": { "serverUrl": "http://localhost:5341" }
      }
    ]
  }
}
```

### Filtering per Namespace

```json
{
  "Serilog": {
    "MinimumLevel": {
      "Override": {
        "RagChatApp_Server.Services.DocumentProcessingService": "Debug",
        "RagChatApp_Server.Services.AIProviders": "Information"
      }
    }
  }
}
```

## 🚨 Best Practices

### ✅ DO

1. **Usa structured logging**
   ```csharp
   _logger.LogInformation("User {UserId} performed action {ActionName}", userId, action);
   ```

2. **Log ingresso/uscita metodi critici**
   ```csharp
   _logger.LogInformation("➡️  Entering {MethodName}", nameof(ProcessDocument));
   ```

3. **Log timing per operazioni lente**
   ```csharp
   _logger.LogInformation("Operation took {Duration}ms", stopwatch.ElapsedMilliseconds);
   ```

4. **Usa scope per correlazione**
   ```csharp
   using (_logger.BeginScope("OrderId: {OrderId}", orderId)) { ... }
   ```

5. **Log eccezioni con contesto**
   ```csharp
   _logger.LogError(ex, "Failed to process document {DocumentId}", documentId);
   ```

### ❌ DON'T

1. **Non usare string interpolation**
   ```csharp
   // ❌ Sbagliato
   _logger.LogInformation($"User {userId} logged in");

   // ✅ Corretto
   _logger.LogInformation("User {UserId} logged in", userId);
   ```

2. **Non loggare informazioni sensibili**
   ```csharp
   // ❌ Sbagliato
   _logger.LogInformation("User password: {Password}", password);
   ```

3. **Non loggare in loop senza throttling**
   ```csharp
   // ❌ Sbagliato - genera migliaia di log
   foreach (var item in items)
   {
       _logger.LogInformation("Processing {Item}", item);
   }

   // ✅ Corretto - log aggregato
   _logger.LogInformation("Processing {Count} items", items.Count);
   ```

4. **Non usare log per debug in produzione**
   ```csharp
   // ❌ Sbagliato - troppo verboso
   _logger.LogDebug("Variable x = {X}, y = {Y}, z = {Z}", x, y, z);
   ```

## 📈 Monitoring

### Verifica Salute Logging

```powershell
# Verifica file recenti
Get-ChildItem "Logs" -Filter "ragchatapp-*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Conta errori oggi
(Select-String -Path "Logs\ragchatapp-$(Get-Date -Format 'yyyyMMdd').log" -Pattern "\[ERR\]").Count

# Ultimi 10 errori
Select-String -Path "Logs\ragchatapp-errors-*.log" -Pattern "\[ERR\]" | Select-Object -Last 10
```

### Cleanup Manuale Log Vecchi

```powershell
# Rimuovi log più vecchi di 90 giorni
Get-ChildItem "Logs" -Filter "*.log" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-90) } | Remove-Item
```

## 🐛 Troubleshooting

### Problema: File di log non vengono creati

**Soluzione**: Verifica permessi sulla cartella Logs
```powershell
New-Item -ItemType Directory -Path "Logs" -Force
```

### Problema: Log troppo verbosi

**Soluzione**: Aumenta MinimumLevel in appsettings.json
```json
"MinimumLevel": { "Default": "Information" }
```

### Problema: File di log troppo grandi

**Soluzione**: I file hanno un limite di 100MB e rotazione giornaliera automatica. Se necessario, riduci:
```json
"fileSizeLimitBytes": 52428800  // 50MB invece di 100MB
```

## 📚 Risorse

- **Serilog Documentation**: https://serilog.net/
- **Structured Logging**: https://messagetemplates.org/
- **ASP.NET Core Logging**: https://docs.microsoft.com/en-us/aspnet/core/fundamentals/logging/

---

**Ultimo Aggiornamento**: 7 Ottobre 2025
**Versione Serilog**: 9.0.0
