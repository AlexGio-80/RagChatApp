# 🏗️ Sistema RAG - Architettura Completa

## Panoramica Architetturale

Il sistema RAG Chat App è progettato come un'applicazione a tre livelli con separazione delle responsabilità e architettura scalabile.

## Diagramma Architetturale

```
┌─────────────────────────────────────────────────────────────────┐
│                        RAG CHAT APPLICATION                     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                        │
├─────────────────────────────────────────────────────────────────┤
│                     RagChatApp_UI                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Document      │  │   Chat          │  │   Settings      │ │
│  │   Management    │  │   Interface     │  │   Panel         │ │
│  │                 │  │                 │  │                 │ │
│  │ • File Upload   │  │ • Real-time     │  │ • AI Config     │ │
│  │ • Drag & Drop   │  │   Messaging     │  │ • Parameters    │ │
│  │ • Text Input    │  │ • Source        │  │ • Mode Toggle   │ │
│  │ • Doc List      │  │   Attribution   │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  Technologies: HTML5, CSS3, JavaScript ES6+, Glassmorphism     │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ├── HTTPS/REST API
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API GATEWAY LAYER                         │
├─────────────────────────────────────────────────────────────────┤
│                    ASP.NET Core 9.0                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Documents     │  │   Chat          │  │   System        │ │
│  │   Controller    │  │   Controller    │  │   Endpoints     │ │
│  │                 │  │                 │  │                 │ │
│  │ • Upload        │  │ • Chat POST     │  │ • Health        │ │
│  │ • Index Text    │  │ • Get Info      │  │ • API Info      │ │
│  │ • CRUD Ops      │  │                 │  │ • Swagger       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  Middleware: Rate Limiting, CORS, Authentication, Logging      │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ├── Dependency Injection
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BUSINESS LOGIC LAYER                      │
├─────────────────────────────────────────────────────────────────┤
│                       Service Layer                            │
│  ┌──────────────────────────────┐  ┌──────────────────────────┐ │
│  │   Document Processing        │  │   Azure OpenAI Service   │ │
│  │   Service                    │  │                          │ │
│  │                              │  │ • Embeddings Generation │ │
│  │ • Text Extraction            │  │ • Chat Completions      │ │
│  │   - PDF (iText7)             │  │ • Similarity Search     │ │
│  │   - Word (OpenXml)           │  │ • Mock Mode Support     │ │
│  │   - Plain Text               │  │                          │ │
│  │ • Intelligent Chunking       │  │                          │ │
│  │   - Header Detection         │  │                          │ │
│  │   - Size Optimization        │  │                          │ │
│  │   - Context Preservation     │  │                          │ │
│  └──────────────────────────────┘  └──────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ├── Entity Framework Core
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                        DATA ACCESS LAYER                       │
├─────────────────────────────────────────────────────────────────┤
│                    Entity Framework Core                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   DbContext     │  │   Repositories  │  │   Migrations    │ │
│  │                 │  │                 │  │                 │ │
│  │ • Configuration │  │ • Async Ops     │  │ • Schema Mgmt   │ │
│  │ • Relationships │  │ • LINQ Queries  │  │ • Versioning    │ │
│  │ • Indexes       │  │ • Change Track  │  │ • Rollback      │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ├── SQL Server Connection
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                       PERSISTENCE LAYER                        │
├─────────────────────────────────────────────────────────────────┤
│                       SQL Server Database                      │
│  ┌──────────────────────────────┐  ┌──────────────────────────┐ │
│  │        Documents             │  │      DocumentChunks      │ │
│  │                              │  │                          │ │
│  │ • Id (PK)                    │  │ • Id (PK)                │ │
│  │ • FileName                   │  │ • DocumentId (FK)        │ │
│  │ • ContentType                │  │ • ChunkIndex             │ │
│  │ • Size                       │  │ • Content                │ │
│  │ • Content (Full Text)        │  │ • HeaderContext          │ │
│  │ • Status                     │  │ • Embedding (VARBINARY) │ │
│  │ • UploadedAt                 │  │ • CreatedAt              │ │
│  │ • ProcessedAt                │  │                          │ │
│  └──────────────────────────────┘  └──────────────────────────┘ │
│                                                                 │
│  Indexes: FileName, Status, UploadedAt, DocumentId, ChunkIndex │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ├── External Integration
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                       EXTERNAL SERVICES                        │
├─────────────────────────────────────────────────────────────────┤
│                      Azure OpenAI Service                      │
│  ┌──────────────────────────────┐  ┌──────────────────────────┐ │
│  │     Embeddings API           │  │     Chat Completions     │ │
│  │                              │  │                          │ │
│  │ • text-embedding-ada-002     │  │ • GPT-4                  │ │
│  │ • 1536 dimensions            │  │ • Context Window         │ │
│  │ • Batch Processing           │  │ • Temperature Control    │ │
│  │ • Rate Limiting              │  │ • Token Management       │ │
│  └──────────────────────────────┘  └──────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Pipeline RAG (Retrieval-Augmented Generation)

### 1. Document Ingestion Pipeline

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Upload    │───▶│   Extract   │───▶│   Chunk     │───▶│   Embed     │
│   Document  │    │   Text      │    │   Content   │    │   Vectors   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ • Validate  │    │ • PDF       │    │ • Headers   │    │ • OpenAI    │
│ • File Type │    │ • Word      │    │ • Max 1000  │    │ • 1536 dim  │
│ • Size      │    │ • Plain     │    │ • Context   │    │ • Store DB  │
│ • Security  │    │ • Error     │    │ • Index     │    │ • Async     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### 2. Query Processing Pipeline

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   User      │───▶│   Query     │───▶│   Vector    │───▶│   Retrieve  │
│   Question  │    │   Embedding │    │   Search    │    │   Chunks    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ • Validate  │    │ • OpenAI    │    │ • Cosine    │    │ • Top K     │
│ • Sanitize  │    │ • Same      │    │ • Similarity│    │ • Threshold │
│ • Preproc   │    │ • Model     │    │ • Ranking   │    │ • Metadata  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### 3. Response Generation Pipeline

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Build     │───▶│   Generate  │───▶│   Format    │───▶│   Return    │
│   Context   │    │   Response  │    │   Sources   │    │   Complete  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ • Relevant  │    │ • GPT-4     │    │ • Citations │    │ • Response  │
│ • Chunks    │    │ • Context   │    │ • Score     │    │ • Sources   │
│ • Headers   │    │ • Prompt    │    │ • Document  │    │ • Metadata  │
│ • Sources   │    │ • Stream    │    │ • Preview   │    │ • Complete  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## Architettura Backend .NET 9.0

### Struttura dei Progetti

```
RagChatApp_Server/
├── Controllers/           # API Endpoints
│   ├── DocumentsController.cs
│   └── ChatController.cs
├── Services/             # Business Logic
│   ├── IDocumentProcessingService.cs
│   ├── DocumentProcessingService.cs
│   ├── IAzureOpenAIService.cs
│   └── AzureOpenAIService.cs
├── Models/               # Entity Models
│   ├── Document.cs
│   └── DocumentChunk.cs
├── DTOs/                 # Data Transfer Objects
│   ├── DocumentUploadRequest.cs
│   ├── ChatRequest.cs
│   └── DocumentResponse.cs
├── Data/                 # Data Access
│   └── RagChatDbContext.cs
└── Program.cs            # Application Configuration
```

### Dependency Injection Configuration

```csharp
// Services Registration
builder.Services.AddDbContext<RagChatDbContext>()
builder.Services.AddScoped<IDocumentProcessingService, DocumentProcessingService>()
builder.Services.AddScoped<IAzureOpenAIService, AzureOpenAIService>()
builder.Services.AddHttpClient<IAzureOpenAIService, AzureOpenAIService>()

// Middleware Pipeline
app.UseCors("AllowAll")
app.UseRateLimiter()
app.UseHttpsRedirection()
app.MapControllers()
```

## Struttura Frontend HTML/CSS/JavaScript

### Component Architecture

```
RagChatApp_UI/
├── index.html            # Main Application Shell
├── css/
│   └── style.css         # Glassmorphism Styling
├── js/
│   └── app.js            # Application Logic
└── assets/               # Static Resources
```

### JavaScript Module Structure

```javascript
// Application State Management
const AppState = {
    currentTab: 'documents',
    documents: [],
    isLoading: false,
    chatMessages: []
}

// Event Handling System
- Tab Navigation
- File Upload (Drag & Drop)
- Document Management
- Chat Interface
- Settings Configuration
```

## Integrazione Azure OpenAI

### Authentication Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   API Key   │───▶│   Headers   │───▶│   Request   │
│   Config    │    │   Bearer    │    │   Azure     │
└─────────────┘    └─────────────┘    └─────────────┘
```

### Endpoint Configuration

- **Embeddings**: `/openai/deployments/text-embedding-ada-002/embeddings`
- **Chat**: `/openai/deployments/gpt-4/chat/completions`
- **API Version**: `2023-05-15`

### Mock Mode Implementation

```csharp
public bool IsMockMode => _configuration.GetValue<bool>("MockMode:Enabled", false);

// Mock Embedding Generation
private byte[] GenerateMockEmbedding(string text)
{
    var hash = text.GetHashCode();
    var random = new Random(hash);
    var embedding = new float[1536];
    for (int i = 0; i < embedding.Length; i++)
    {
        embedding[i] = (float)(random.NextDouble() * 2 - 1);
    }
    return ConvertFloatArrayToByteArray(embedding);
}
```

## Diagrammi di Flusso

### Flusso Indicizzazione Documenti

```
┌─────────────┐
│   START     │
└─────┬───────┘
      │
      ▼
┌─────────────┐    NO    ┌─────────────┐
│  File Valid │─────────▶│   Error     │
│     ?       │          │   Message   │
└─────┬───────┘          └─────────────┘
      │ YES
      ▼
┌─────────────┐
│   Extract   │
│    Text     │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│   Create    │
│   Chunks    │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│  Generate   │
│ Embeddings  │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│   Store     │
│   Database  │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│     END     │
└─────────────┘
```

### Flusso Chat Interaction

```
┌─────────────┐
│   User      │
│   Message   │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│  Generate   │
│  Query      │
│  Embedding  │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│   Vector    │
│   Search    │
│   Similar   │
│   Chunks    │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│   Build     │
│   Context   │
│   From      │
│   Chunks    │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│   Generate  │
│   AI        │
│   Response  │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│   Format    │
│   With      │
│   Sources   │
└─────┬───────┘
      │
      ▼
┌─────────────┐
│   Return    │
│   Complete  │
│   Response  │
└─────────────┘
```

## Caratteristiche Architetturali

### Scalabilità
- **Microservizi Ready**: Separazione netta delle responsabilità
- **Stateless API**: Ogni richiesta è indipendente
- **Background Processing**: Operazioni asincrone
- **Connection Pooling**: Gestione efficiente delle connessioni

### Resilienza
- **Error Handling**: Gestione completa degli errori
- **Retry Logic**: Politiche di retry per servizi esterni
- **Circuit Breaker**: Protezione da cascading failures
- **Health Checks**: Monitoraggio dello stato dei servizi

### Sicurezza
- **Rate Limiting**: Prevenzione abuse
- **Input Validation**: Validazione completa degli input
- **SQL Injection Protection**: Query parametrizzate
- **CORS Configuration**: Controllo accessi cross-origin

### Performance
- **Async/Await**: Operazioni non bloccanti
- **Database Indexing**: Query ottimizzate
- **Caching Strategy**: Cache degli embeddings
- **Resource Management**: Garbage collection ottimizzata

Questa architettura fornisce una base solida per un sistema RAG scalabile, sicuro e performante, con separazione chiara delle responsabilità e facilità di manutenzione.