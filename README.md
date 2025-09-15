# 📚 RAG Chat Application

Una applicazione di chat basata su RAG (Retrieval-Augmented Generation) che permette di caricare documenti e chattare con l'AI utilizzando il contenuto come contesto.

## 🏗️ Architettura

- **RagChatApp_Server** (.NET 9.0): Backend API con gestione documenti e chat AI
- **RagChatApp_UI** (HTML/CSS/JS): Frontend responsivo con design glassmorphism

## ✨ Caratteristiche Principali

### 📄 Gestione Documenti
- Upload multiplo file supportati (.txt, .pdf, .doc, .docx)
- Indicizzazione testo diretto
- Chunking intelligente basato su header markdown
- Preservazione della struttura del documento
- Lista documenti con informazioni dettagliate

### 💬 Chat AI
- Chat in tempo reale con AI
- Visualizzazione fonti nei risultati
- Configurazione parametri di ricerca
- Supporto modalità mock per sviluppo

### 🔧 Tecnologie
- .NET 9.0 con Entity Framework Core
- SQL Server con supporto vettori (VARBINARY per embeddings)
- Integrazione Azure OpenAI
- Frontend responsivo con glassmorphism design
- Rate limiting configurabile
- CORS abilitato

## 🚀 Setup e Configurazione

### Prerequisiti
- .NET 9.0 SDK
- SQL Server (locale o remoto)
- Azure OpenAI Service (opzionale, supporta modalità mock)

### 1. Database Setup

Aggiorna la stringa di connessione in `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=YOUR_SERVER;Encrypt=False;Integrated Security=True;Initial Catalog=OSL_AI"
  }
}
```

### 2. Server Setup

```bash
cd RagChatApp_Server
dotnet restore
dotnet ef database update
dotnet run
```

Il server sarà disponibile su `https://localhost:7297`

### 3. Frontend Setup

1. Aggiorna l'URL dell'API in `js/app.js`:
```javascript
const CONFIG = {
    API_BASE_URL: 'https://localhost:7297/api',
    // ...
};
```

2. Apri `index.html` in un browser o usa un server web locale

### 4. Configurazione Azure OpenAI (Opzionale)

Aggiorna `appsettings.json`:

```json
{
  "AzureOpenAI": {
    "Endpoint": "https://your-resource.openai.azure.com/",
    "ApiKey": "your-api-key-here",
    "EmbeddingModel": "text-embedding-ada-002",
    "ChatModel": "gpt-4"
  },
  "MockMode": {
    "Enabled": false
  }
}
```

## 📡 API Endpoints

### Documenti
- `POST /api/documents/upload` - Caricamento file
- `POST /api/documents/index-text` - Indicizzazione testo diretto
- `PUT /api/documents/{id}` - Aggiornamento documento
- `DELETE /api/documents/{id}` - Cancellazione documento
- `GET /api/documents` - Lista documenti

### Chat
- `POST /api/chat` - Chat con AI
- `GET /api/chat/info` - Informazioni servizio AI

### Sistema
- `GET /health` - Health check
- `GET /api/info` - Informazioni API

## 🔄 Modalità Mock

Per sviluppo e test, l'applicazione supporta una modalità mock che:
- Simula la generazione di embeddings
- Usa ricerca testuale semplice invece di similarity search
- Genera risposte mock basate sui documenti trovati

Attiva la modalità mock in `appsettings.json`:
```json
{
  "MockMode": {
    "Enabled": true
  }
}
```

## 📊 Caratteristiche Tecniche

### Chunking Intelligente
- Spezzettamento basato su header markdown
- Chunk massimi di 1000 caratteri
- Preservazione della struttura del documento
- Conservazione header e contenuto

### Sicurezza
- Rate limiting configurato su tutti gli endpoint
- Validazione input con Data Annotations
- Protezione SQL injection con Entity Framework
- CORS configurabile

### Performance
- Operazioni asincrone
- Background processing per documenti
- Indici database ottimizzati
- Connection pooling

## 🎨 UI Features

### Design
- Glassmorphism moderno con gradiente
- Navigazione a tab responsiva
- Drag & drop per upload file
- Toast notifications

### Chat Interface
- Messaggi scrollabili
- Visualizzazione fonti
- Configurazione parametri di ricerca
- Input con supporto Enter per invio

### Document Management
- Lista documenti con stato processing
- Informazioni dettagliate (dimensione, data, chunk count)
- Azioni di gestione (cancellazione)

## 🔧 Sviluppo

### Struttura Progetto

```
RagChatApp/
├── RagChatApp_Server/          # Backend .NET 9.0
│   ├── Controllers/            # API Controllers
│   ├── Data/                   # Entity Framework DbContext
│   ├── DTOs/                   # Data Transfer Objects
│   ├── Models/                 # Entity Models
│   └── Services/               # Business Logic
├── RagChatApp_UI/              # Frontend
│   ├── css/                    # Styles
│   ├── js/                     # JavaScript
│   └── index.html              # Main HTML
├── CLAUDE.md                   # Guida Claude Code
└── README.md                   # Questo file
```

### Testing API

Usa Swagger UI disponibile su `https://localhost:7297/swagger` in modalità development.

### Rate Limiting

Tutti gli endpoint hanno rate limiting configurato:
- GlobalLimiter: 100 requests per minuto per IP/utente

### Logging

L'applicazione usa structured logging con `ILogger`:
- Informazioni operative
- Errori con stack trace
- Performance metrics

## 🚨 Troubleshooting

### Problemi Comuni

1. **Errore connessione database**
   - Verifica stringa di connessione
   - Assicurati che SQL Server sia in esecuzione
   - Esegui `dotnet ef database update`

2. **CORS Error nel browser**
   - Verifica che il server sia in esecuzione
   - Controlla l'URL dell'API nel frontend

3. **File upload fallisce**
   - Verifica dimensione file (max 50MB)
   - Controlla tipo file supportato
   - Verifica spazio disco

4. **Azure OpenAI non funziona**
   - Verifica API key e endpoint
   - Attiva modalità mock per test
   - Controlla logs del server

### Logs

I logs sono disponibili nella console del server e includono:
- Upload e processing documenti
- Generazione embeddings
- Chat requests/responses
- Errori e performance

## 📝 Note di Sviluppo

- Il progetto segue i principi SOLID e clean architecture
- Tutti gli endpoint API hanno documentazione XML
- Rate limiting obbligatorio per sicurezza
- Supporto completo per modalità mock
- Design responsivo per mobile
- Comprehensive error handling e logging

## 🔄 Aggiornamenti Futuri

Possibili miglioramenti:
- Autenticazione utenti
- Multi-tenancy
- Vector search ottimizzato
- Supporto più formati file
- Real-time notifications
- Deployment containerizzato

---

Per supporto o segnalazione bug, consultare la documentazione del progetto o contattare il team di sviluppo.