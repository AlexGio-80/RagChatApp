# 🛠️ Fix Connettività Frontend-Backend - Guida Risoluzione Problemi

## Panoramica Problemi Comuni

Questa guida fornisce soluzioni sistematiche per i problemi di connettività più comuni tra frontend e backend nel sistema RAG Chat Application.

## Risoluzione Port Mismatch

### Problema: Port Mismatch tra Frontend e Backend

**Sintomi:**
- Errori di connessione "ERR_CONNECTION_REFUSED"
- Messaggi "Failed to fetch" nella console del browser
- API calls che falliscono con status 0

**Diagnosi:**

```javascript
// Controlla configurazione frontend
console.log('API_BASE_URL:', CONFIG.API_BASE_URL);

// Test connessione base
fetch(CONFIG.API_BASE_URL + '/health')
  .then(response => console.log('Health check status:', response.status))
  .catch(error => console.error('Connection error:', error));
```

**Soluzioni:**

### 1. Verifica Porte Backend

```bash
# Verifica processo in ascolto
netstat -an | findstr :7297
netstat -an | findstr :5000

# Verifica configurazione Kestrel
dotnet run --urls "https://localhost:7297;http://localhost:5000"
```

### 2. Aggiornamento Configurazione Frontend

```javascript
// js/app.js - Configurazione corretta
const CONFIG = {
    // Sviluppo locale
    API_BASE_URL: 'https://localhost:7297/api',

    // Oppure HTTP se non hai HTTPS
    // API_BASE_URL: 'http://localhost:5000/api',

    // Produzione
    // API_BASE_URL: 'https://api.yourcompany.com/api',
};
```

### 3. Configurazione launchSettings.json

```json
{
  "profiles": {
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": false,
      "applicationUrl": "https://localhost:7297;http://localhost:5000",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
```

### 4. Script Automatico per Verifica Porte

```powershell
# check-ports.ps1
param(
    [int]$HttpsPort = 7297,
    [int]$HttpPort = 5000
)

Write-Host "Verificando porte per RAG Chat API..."

# Test HTTPS port
$httpsTest = Test-NetConnection -ComputerName localhost -Port $HttpsPort -WarningAction SilentlyContinue
if ($httpsTest.TcpTestSucceeded) {
    Write-Host "✓ HTTPS Port $HttpsPort è raggiungibile" -ForegroundColor Green
} else {
    Write-Host "✗ HTTPS Port $HttpsPort NON è raggiungibile" -ForegroundColor Red
}

# Test HTTP port
$httpTest = Test-NetConnection -ComputerName localhost -Port $HttpPort -WarningAction SilentlyContinue
if ($httpTest.TcpTestSucceeded) {
    Write-Host "✓ HTTP Port $HttpPort è raggiungibile" -ForegroundColor Green
} else {
    Write-Host "✗ HTTP Port $HttpPort NON è raggiungibile" -ForegroundColor Red
}

# Test API endpoint
try {
    $response = Invoke-WebRequest -Uri "https://localhost:$HttpsPort/health" -UseBasicParsing -SkipCertificateCheck
    Write-Host "✓ API Health check: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "✗ API Health check fallito: $($_.Exception.Message)" -ForegroundColor Red
}
```

## HTTPS Redirection Issues

### Problema: Certificati HTTPS in Sviluppo

**Sintomi:**
- Avvisi certificato "NET::ERR_CERT_AUTHORITY_INVALID"
- Blocco richieste HTTPS
- Mixed content warnings

**Soluzioni:**

### 1. Trust Certificato Sviluppo .NET

```bash
# Installa certificato sviluppo
dotnet dev-certs https --trust

# Verifica certificato
dotnet dev-certs https --check

# Rigenera certificato se necessario
dotnet dev-certs https --clean
dotnet dev-certs https --trust
```

### 2. Configurazione Chrome per Sviluppo

```javascript
// Per bypass temporaneo in sviluppo, aggiungi in app.js
if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    // Configura per accettare certificati self-signed in sviluppo
    console.warn('Modalità sviluppo: certificati self-signed accettati');
}
```

### 3. Configurazione Kestrel per HTTPS

```csharp
// Program.cs - Configurazione HTTPS custom
builder.WebHost.ConfigureKestrel(options =>
{
    options.ListenLocalhost(5000); // HTTP
    options.ListenLocalhost(7297, listenOptions =>
    {
        listenOptions.UseHttps(); // HTTPS con certificato dev
    });
});
```

### 4. Configurazione per Produzione IIS

```xml
<!-- web.config per IIS -->
<system.webServer>
  <rewrite>
    <rules>
      <rule name="HTTPS Redirect" stopProcessing="true">
        <match url=".*" />
        <conditions>
          <add input="{HTTPS}" pattern="off" ignoreCase="true" />
        </conditions>
        <action type="Redirect" url="https://{HTTP_HOST}/{R:0}" redirectType="Permanent" />
      </rule>
    </rules>
  </rewrite>
</system.webServer>
```

## Configurazione CORS

### Problema: CORS Blocking

**Sintomi:**
- Errori "CORS policy has blocked the request"
- Preflight OPTIONS requests che falliscono
- Blocco API calls da domini diversi

**Diagnosi CORS:**

```javascript
// Test CORS preflight
fetch(CONFIG.API_BASE_URL + '/documents', {
    method: 'OPTIONS',
    headers: {
        'Origin': window.location.origin,
        'Access-Control-Request-Method': 'GET',
        'Access-Control-Request-Headers': 'Content-Type'
    }
})
.then(response => {
    console.log('CORS preflight response:', response.headers);
    console.log('Access-Control-Allow-Origin:', response.headers.get('Access-Control-Allow-Origin'));
})
.catch(error => console.error('CORS preflight error:', error));
```

**Soluzioni:**

### 1. Configurazione CORS Sviluppo

```csharp
// Program.cs - CORS permissivo per sviluppo
builder.Services.AddCors(options =>
{
    options.AddPolicy("DevelopmentCORS", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// In modalità sviluppo
if (app.Environment.IsDevelopment())
{
    app.UseCors("DevelopmentCORS");
}
```

### 2. Configurazione CORS Produzione

```csharp
// Program.cs - CORS sicuro per produzione
builder.Services.AddCors(options =>
{
    options.AddPolicy("ProductionCORS", policy =>
    {
        policy.WithOrigins(
                "https://www.yourcompany.com",
                "https://ragchat.yourcompany.com",
                "http://localhost:3000", // Per development locale
                "http://127.0.0.1:3000"
              )
              .WithMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
              .WithHeaders("Content-Type", "Authorization", "Accept")
              .AllowCredentials()
              .SetPreflightMaxAge(TimeSpan.FromMinutes(10));
    });
});

app.UseCors("ProductionCORS");
```

### 3. Debug CORS Middleware

```csharp
// Middleware per debug CORS
app.Use(async (context, next) =>
{
    var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();

    logger.LogInformation("Request: {Method} {Url} from Origin: {Origin}",
        context.Request.Method,
        context.Request.GetDisplayUrl(),
        context.Request.Headers["Origin"].FirstOrDefault() ?? "No Origin");

    await next();

    logger.LogInformation("Response: {StatusCode} with CORS headers: {CorsHeaders}",
        context.Response.StatusCode,
        string.Join(", ", context.Response.Headers
            .Where(h => h.Key.StartsWith("Access-Control"))
            .Select(h => $"{h.Key}={h.Value}")));
});
```

## Metodologia Debugging Network

### 1. Browser Developer Tools

```javascript
// Console script per debug network
function debugNetworkCall(url, options = {}) {
    console.group('🔍 Network Debug:', url);
    console.log('Request options:', options);

    const startTime = performance.now();

    return fetch(url, options)
        .then(response => {
            const endTime = performance.now();
            console.log('✓ Response received in', Math.round(endTime - startTime), 'ms');
            console.log('Status:', response.status, response.statusText);
            console.log('Headers:', Object.fromEntries(response.headers.entries()));
            console.groupEnd();
            return response;
        })
        .catch(error => {
            const endTime = performance.now();
            console.error('✗ Request failed after', Math.round(endTime - startTime), 'ms');
            console.error('Error:', error);
            console.groupEnd();
            throw error;
        });
}

// Usa per debug
debugNetworkCall(CONFIG.API_BASE_URL + '/health')
    .then(r => r.json())
    .then(data => console.log('Health data:', data));
```

### 2. Fiddler/Proxy Setup

```javascript
// Configurazione proxy per debugging
const proxyConfig = {
    // Per Fiddler
    proxy: 'http://127.0.0.1:8888',

    // Per Charles Proxy
    // proxy: 'http://127.0.0.1:8080'
};

// Override fetch per debugging con proxy
if (window.location.hostname === 'localhost') {
    const originalFetch = window.fetch;
    window.fetch = function(url, options = {}) {
        console.log('🌐 Fetch intercepted:', url, options);
        return originalFetch(url, options);
    };
}
```

### 3. Backend Network Logging

```csharp
// Startup.cs o Program.cs - HTTP logging
builder.Services.AddHttpLogging(logging =>
{
    logging.LoggingFields = HttpLoggingFields.RequestPropertiesAndHeaders |
                          HttpLoggingFields.ResponsePropertiesAndHeaders |
                          HttpLoggingFields.RequestBody |
                          HttpLoggingFields.ResponseBody;
    logging.RequestBodyLogLimit = 4096;
    logging.ResponseBodyLogLimit = 4096;
});

app.UseHttpLogging();
```

## Test di Verifica e Monitoring

### 1. Script Test Connettività Completo

```powershell
# test-connectivity.ps1
param(
    [string]$BackendUrl = "https://localhost:7297",
    [string]$FrontendPath = ".\RagChatApp_UI\index.html"
)

Write-Host "🔧 Test Connettività RAG Chat Application" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Test 1: Backend Health
Write-Host "`n1. Testing Backend Health..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-RestMethod -Uri "$BackendUrl/health" -Method GET -SkipCertificateCheck
    Write-Host "✓ Backend health: OK" -ForegroundColor Green
    Write-Host "   Response: $($healthResponse | ConvertTo-Json -Compress)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Backend health: FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: API Info
Write-Host "`n2. Testing API Info..." -ForegroundColor Yellow
try {
    $apiInfo = Invoke-RestMethod -Uri "$BackendUrl/api/info" -Method GET -SkipCertificateCheck
    Write-Host "✓ API Info: OK" -ForegroundColor Green
    Write-Host "   Mock Mode: $($apiInfo.MockMode)" -ForegroundColor Gray
} catch {
    Write-Host "✗ API Info: FAILED" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: CORS Preflight
Write-Host "`n3. Testing CORS Configuration..." -ForegroundColor Yellow
try {
    $corsHeaders = @{
        'Origin' = 'http://localhost:3000'
        'Access-Control-Request-Method' = 'GET'
        'Access-Control-Request-Headers' = 'Content-Type'
    }
    $corsResponse = Invoke-WebRequest -Uri "$BackendUrl/api/documents" -Method OPTIONS -Headers $corsHeaders -SkipCertificateCheck
    Write-Host "✓ CORS: OK" -ForegroundColor Green
    Write-Host "   Allow-Origin: $($corsResponse.Headers['Access-Control-Allow-Origin'])" -ForegroundColor Gray
} catch {
    Write-Host "✗ CORS: NEEDS CONFIGURATION" -ForegroundColor Yellow
    Write-Host "   This might be expected if CORS is strictly configured" -ForegroundColor Gray
}

# Test 4: Frontend File Access
Write-Host "`n4. Testing Frontend Files..." -ForegroundColor Yellow
if (Test-Path $FrontendPath) {
    Write-Host "✓ Frontend files: Found" -ForegroundColor Green

    # Check API configuration in frontend
    $jsContent = Get-Content ".\RagChatApp_UI\js\app.js" -Raw
    if ($jsContent -match 'API_BASE_URL.*?[''"]([^''"]+)[''"]') {
        $frontendApiUrl = $matches[1]
        Write-Host "   Frontend API URL: $frontendApiUrl" -ForegroundColor Gray

        if ($frontendApiUrl -eq "$BackendUrl/api") {
            Write-Host "✓ Frontend-Backend URL match: OK" -ForegroundColor Green
        } else {
            Write-Host "⚠ Frontend-Backend URL mismatch!" -ForegroundColor Yellow
            Write-Host "   Frontend expects: $frontendApiUrl" -ForegroundColor Red
            Write-Host "   Backend running on: $BackendUrl/api" -ForegroundColor Red
        }
    }
} else {
    Write-Host "✗ Frontend files: NOT FOUND" -ForegroundColor Red
}

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "🏁 Connectivity Test Complete" -ForegroundColor Cyan
```

### 2. Monitoring Dashboard JavaScript

```javascript
// monitoring.js - Dashboard per monitoring connettività
class ConnectivityMonitor {
    constructor() {
        this.status = {
            backend: 'unknown',
            api: 'unknown',
            lastCheck: null
        };
        this.checkInterval = 30000; // 30 secondi
        this.init();
    }

    init() {
        this.createStatusWidget();
        this.startMonitoring();
    }

    createStatusWidget() {
        const widget = document.createElement('div');
        widget.id = 'connectivity-status';
        widget.style.cssText = `
            position: fixed;
            top: 10px;
            right: 10px;
            background: rgba(0,0,0,0.8);
            color: white;
            padding: 10px;
            border-radius: 5px;
            font-family: monospace;
            font-size: 12px;
            z-index: 10000;
        `;
        document.body.appendChild(widget);
    }

    async checkConnectivity() {
        const results = {
            backend: await this.testBackend(),
            api: await this.testAPI(),
            timestamp: new Date().toISOString()
        };

        this.updateStatus(results);
        return results;
    }

    async testBackend() {
        try {
            const response = await fetch(`${CONFIG.API_BASE_URL.replace('/api', '')}/health`, {
                method: 'GET',
                timeout: 5000
            });
            return response.ok ? 'online' : 'error';
        } catch {
            return 'offline';
        }
    }

    async testAPI() {
        try {
            const response = await fetch(`${CONFIG.API_BASE_URL}/info`, {
                method: 'GET',
                timeout: 5000
            });
            return response.ok ? 'online' : 'error';
        } catch {
            return 'offline';
        }
    }

    updateStatus(results) {
        const widget = document.getElementById('connectivity-status');
        const backendColor = results.backend === 'online' ? '#4CAF50' : '#f44336';
        const apiColor = results.api === 'online' ? '#4CAF50' : '#f44336';

        widget.innerHTML = `
            <div>🏥 Backend: <span style="color: ${backendColor}">${results.backend.toUpperCase()}</span></div>
            <div>🔌 API: <span style="color: ${apiColor}">${results.api.toUpperCase()}</span></div>
            <div>🕐 ${new Date(results.timestamp).toLocaleTimeString()}</div>
        `;
    }

    startMonitoring() {
        this.checkConnectivity(); // Check immediato
        setInterval(() => this.checkConnectivity(), this.checkInterval);
    }
}

// Avvia monitoring se in development
if (window.location.hostname === 'localhost') {
    new ConnectivityMonitor();
}
```

### 3. Automated Health Checks

```bash
#!/bin/bash
# health-check.sh per Linux/WSL

BACKEND_URL="https://localhost:7297"
MAX_RETRIES=3
RETRY_DELAY=5

check_endpoint() {
    local url=$1
    local name=$2
    local retries=0

    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -k -s -f "$url" > /dev/null; then
            echo "✓ $name: OK"
            return 0
        fi

        retries=$((retries + 1))
        echo "⚠ $name: Retry $retries/$MAX_RETRIES"
        sleep $RETRY_DELAY
    done

    echo "✗ $name: FAILED after $MAX_RETRIES attempts"
    return 1
}

echo "🔍 RAG Chat Health Check"
echo "========================"

check_endpoint "$BACKEND_URL/health" "Backend Health"
check_endpoint "$BACKEND_URL/api/info" "API Info"
check_endpoint "$BACKEND_URL/api/documents" "Documents API"

echo "========================"
echo "🏁 Health Check Complete"
```

Questa guida fornisce una metodologia completa per diagnosticare e risolvere i problemi di connettività più comuni nel sistema RAG Chat Application, con script automatici per test e monitoring continuo.