# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RagChatApp - An advanced RAG (Retrieval-Augmented Generation) chat application that allows users to upload documents and chat with AI using the content as context. The system features multi-field embedding search, intelligent document processing, comprehensive SQL interface alongside REST API, and **AES-256 encrypted API key storage**.

**Latest Update**: October 2, 2025 - Complete deployment package with RAG installation (CLR/VECTOR choice), interactive installer, and unified production installation guide.

## Architecture

- **RagChatApp_Server** (.NET 9.0): Enhanced backend API with advanced document processing and dual interface (REST + SQL)
- **RagChatApp_UI** (HTML/CSS/JS): Frontend for document management and chat interface

### Key Technologies
- .NET 9.0 with Entity Framework Core
- SQL Server with advanced vector storage (4 separate embedding tables)
- PdfPig for superior PDF text extraction
- Azure OpenAI integration with multi-field embedding generation
- Comprehensive SQL stored procedure interface
- Responsive frontend with glassmorphism design

### Enhanced Core Features
- **Advanced Document Processing**: Enhanced PDF processing with PdfPig, intelligent chunking, structure detection
- **Multi-Field Embeddings**: Content, HeaderContext, Notes, Details embeddings for enhanced search
- **Cosine Similarity Vector Search**: In-memory vector search with multi-field embedding support, proper similarity scoring
- **Document Opening from Chat**: Click-to-open document feature in chat sources with clipboard fallback
- **Dual Interface**: Complete REST API + SQL stored procedures for external access
- **🔐 AES-256 Encrypted API Keys**: Automatic encryption with SQL Server built-in security (NEW v1.3.1)
- **Automated Installer**: PowerShell script for one-command setup with encryption
- **Semantic Caching**: 1-hour TTL caching system for improved performance
- **Configurable Search**: MaxChunksForLLM parameter (default 10, max 50)
- **Enhanced Metadata**: Document paths, user notes, JSON details support
- **Mock service mode**: For development without OpenAI API

### Database Schema (Enhanced)
```
Documents
├─ Path (NEW): Document URL/path for linking
└─ (existing fields)

DocumentChunks
├─ Notes (NEW): User-added notes
├─ Details (NEW): JSON metadata
├─ UpdatedAt (NEW): Track modifications
└─ (existing fields, removed old Embedding)

Embedding Tables (NEW - 4 separate tables):
├─ DocumentChunkContentEmbeddings
├─ DocumentChunkHeaderContextEmbeddings
├─ DocumentChunkNotesEmbeddings
└─ DocumentChunkDetailsEmbeddings

SemanticCache (NEW):
└─ 1-hour TTL search result caching
```

## Development Commands

### 🚀 Running the Application

**Backend Server (RagChatApp_Server)**:
```bash
cd RagChatApp_Server
dotnet restore              # Restore NuGet packages
dotnet build                # Build the project
dotnet run                  # Run the server (includes auto-database migration)
```
- **Default URL**: `https://localhost:7297`
- **Swagger UI**: `https://localhost:7297/swagger`
- **Health Check**: `https://localhost:7297/health`

**Frontend (RagChatApp_UI)**:
```bash
cd RagChatApp_UI

# Option 1: Using npm (recommended for development)
npm install      # Install development server dependencies
npm start        # Start development server on http://localhost:3000

# Option 2: Direct file access
# Open index.html directly in browser (limited functionality due to CORS)

# Option 3: Using live-server (if installed globally)
npx live-server --port=3000 --entry-file=index.html
```
- **Development URL**: `http://localhost:3000`
- **Static files**: HTML/CSS/JS (no build process required)

### 🗄️ Database Management

**Important**: Database migrations now run automatically on server startup!

**Manual Commands** (for development only):
```bash
# View migration status
dotnet ef migrations list

# Create new migration (when models change)
dotnet ef migrations add MigrationName

# Remove last migration (if not applied)
dotnet ef migrations remove

# Manual database update (not needed - auto-migrates on startup)
dotnet ef database update

# Reset database (development only)
dotnet ef database drop --force
dotnet run  # Will recreate with auto-migration
```

### 🧪 Testing Commands

```bash
# Build verification
dotnet build

# Unit tests (when implemented)
dotnet test

# API testing with curl
curl -X GET "https://localhost:7297/health"
curl -X GET "https://localhost:7297/api/info"
```

### 🔧 Development Tools

**Package Management**:
```bash
# Add new package
dotnet add package PackageName

# List installed packages
dotnet list package

# Update packages
dotnet restore
```

**Project Structure**:
```bash
# View project structure (Windows)
tree /F RagChatApp_Server
tree /F RagChatApp_UI

# Alternative with PowerShell
Get-ChildItem -Recurse -Name
```

## 🚀 Production Deployment

### 📦 Creating Deployment Package

For production deployment where .NET development environment is **not available**:

```powershell
# Navigate to deployment folder
cd RagChatApp_Server/Database/Deployment

# Create complete deployment package (with compiled binaries)
.\Create-DeploymentPackage.ps1

# Output: RagChatApp_DeploymentPackage_YYYYMMDD_HHMMSS.zip
```

**Package includes**:
- ✅ **Compiled application binaries** (.exe + dependencies) - Ready to run
- ✅ `appsettings.json` template - No credentials, ready to configure
- ✅ `01_DatabaseSchema.sql` - Complete database schema (idempotent, safe to rerun)
- ✅ `Install-WindowsService.ps1` - Automated Windows Service installer
- ✅ `Install-RAG-Interactive.ps1` - Interactive RAG installer (CLR/VECTOR choice)
- ✅ `00_PRODUCTION_SETUP_GUIDE.md` - **Single comprehensive installation guide**
- ✅ Stored procedures (optional, for SQL interface)
- ✅ RAG implementations (CLR + VECTOR with installers and docs)
- ✅ Encryption scripts (optional, for encrypted API keys)
- ✅ Deployment checklist and documentation

**Package options**:
```powershell
# Full package (default - recommended)
.\Create-DeploymentPackage.ps1

# Database only (no application binaries)
.\Create-DeploymentPackage.ps1 -IncludeApplication:$false

# REST API only (no stored procedures)
.\Create-DeploymentPackage.ps1 -IncludeStoredProcedures:$false

# Custom output location
.\Create-DeploymentPackage.ps1 -OutputPath "C:\Releases\RagChatApp_v1.3.1"
```

**See**: `Database/Deployment/README_PACKAGE_CREATION.md` for full documentation

### 🗄️ Production Database Setup

**Quick Start** (REST API only):
```sql
-- 1. Create database
CREATE DATABASE RagChatAppDB;
GO

-- 2. Run schema script (idempotent - safe to rerun)
USE RagChatAppDB;
:r "01_DatabaseSchema.sql"
GO

-- 3. Verify installation
SELECT * FROM __EFMigrationsHistory ORDER BY MigrationId;
-- Should show 3 migrations applied
```

**Full Installation** (REST API + SQL Interface + RAG):
```powershell
# 1. Run schema script (as above)

# 2. Install stored procedures with encryption
cd Database/StoredProcedures
.\Install-MultiProvider.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "RagChatAppDB" `
    -GeminiApiKey "your-key" `
    -OpenAIApiKey "your-key" `
    -TestAfterInstall

# 3. Install RAG search (interactive - auto-detects CLR/VECTOR)
cd ../..
.\Install-RAG-Interactive.ps1 `
    -ServerInstance "YOUR_SERVER\INSTANCE" `
    -DatabaseName "RagChatAppDB" `
    -DefaultProvider "Gemini"

# 4. Backup encryption certificate (CRITICAL!)
# See Database/Deployment/README_DEPLOYMENT.md
```

### 🔍 RAG Installation (CLR vs VECTOR)

The application supports two RAG search implementations:

**CLR (Recommended - SQL Server 2016+)**:
- Uses SQL CLR functions for vector similarity
- Production-ready and stable
- Works with SQL Server 2016-2025 RC

**VECTOR (Future - SQL Server 2025 RTM+)**:
- Uses native VECTOR type
- Better performance
- Requires SQL Server 2025 RTM (not yet available)

**Interactive installer** (auto-detects best option):
```powershell
.\Install-RAG-Interactive.ps1 `
    -ServerInstance "localhost\SQLEXPRESS" `
    -DatabaseName "RagChatAppDB" `
    -DefaultProvider "Gemini"
```

**Manual installation** (CLR):
```powershell
cd Database/StoredProcedures/CLR
.\Install-RAG-CLR.ps1 `
    -ServerInstance "localhost\SQLEXPRESS" `
    -DatabaseName "RagChatAppDB"
```

**See**: `README_RAG_INSTALLATION.md` for detailed comparison and troubleshooting

### ⚙️ Application Configuration

Update `appsettings.json` (production):
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=YOUR_SERVER;Database=RagChatAppDB;User Id=YOUR_USER;Password=YOUR_PASSWORD;TrustServerCertificate=True;"
  },
  "AIProvider": {
    "DefaultProvider": "Gemini",
    "Gemini": {
      "ApiKey": "your-gemini-api-key",
      "BaseUrl": "https://generativelanguage.googleapis.com/v1beta",
      "Model": "models/embedding-001"
    }
  }
}
```

**Security Best Practice** - Use environment variables:
```bash
# Linux/Mac
export ConnectionStrings__DefaultConnection="Server=...;Database=...;"
export AIProvider__Gemini__ApiKey="your-key"

# Windows PowerShell
$env:ConnectionStrings__DefaultConnection="Server=...;Database=...;"
$env:AIProvider__Gemini__ApiKey="your-key"
```

### 🔄 Database Updates (Production)

When deploying new versions with schema changes:

```bash
# 1. Generate new schema script (from dev environment)
cd RagChatApp_Server
dotnet ef migrations script --idempotent --output "Database/Deployment/01_DatabaseSchema.sql"

# 2. In production (no .NET needed)
# Run the updated script - it's idempotent!
sqlcmd -S SERVER -d RagChatAppDB -i "01_DatabaseSchema.sql"
```

**Or use auto-migration** (if .NET runtime available):
```bash
# Application will auto-migrate on startup
dotnet RagChatApp_Server.dll
# Checks __EFMigrationsHistory and applies pending migrations
```

### 📋 Deployment Documentation

- **Complete Guide**: `Database/Deployment/README_DEPLOYMENT.md`
- **Deployment Checklist**: Generated with deployment package
- **Database Schema**: `/Documentation/DatabaseSchemas/rag-database-schema.md`
- **Configuration**: `/Documentation/ConfigurationGuides/setup-configuration-guide.md`

### 📋 Pre-Deployment Checklist

Before deploying or committing:
```bash
# 1. Build check
dotnet build

# 2. Clean and rebuild
dotnet clean
dotnet build

# 3. Test auto-migration (reset database)
dotnet ef database drop --force
dotnet run  # Should auto-migrate

# 4. Verify endpoints
curl -X GET "https://localhost:7297/health"
curl -X GET "https://localhost:7297/api/info"
```

## 🚨 MANDATORY API DEVELOPMENT CHECKLIST

**Before deploying any new API endpoint, verify ALL items below:**

### ✅ Security Requirements (NON-NEGOTIABLE)

- [ ] **Rate Limiting Configured**: Every endpoint MUST have rate limiting policy configured
  - **MANDATORY**: If no specific policy is mentioned, automatically assign `GlobalLimiter` policy
  - Apply `[EnableRateLimiting("GlobalLimiter")]` to controllers without explicit rate limiting
  - Custom policies should only be used when specifically required (e.g., stricter limits for sensitive endpoints)
- [ ] **Authentication Considered**: Determine if endpoint needs `[Authorize]` attribute
- [ ] **Input Validation**: All inputs are validated with appropriate `[Required]`, `[EmailAddress]`, etc.
- [ ] **SQL Injection Protection**: Use parameterized queries (Dapper prevents this automatically)
- [ ] **Cross-Site Scripting (XSS)**: Sanitize any user input that could be rendered

### ✅ Multi-Tenant Requirements

- [ ] **TenantId Context**: All database operations include appropriate tenant isolation
- [ ] **Tenant Authorization**: Verify user has access to resources within their tenant
- [ ] **Data Leakage Prevention**: Ensure users cannot access other tenants' data

### ✅ Error Handling & Logging

- [ ] **Structured Logging**: Use `ILogger` with proper log levels and context
- [ ] **Exception Handling**: Wrap operations in try-catch with appropriate error responses
- [ ] **PII Protection**: Don't log sensitive information (passwords, tokens, personal data)

### ✅ Performance & Scalability

- [ ] **Async Operations**: Use `async/await` for all I/O operations
- [ ] **Database Efficiency**: Optimize queries, avoid N+1 problems
- [ ] **Memory Management**: Dispose resources properly, avoid memory leaks

### ✅ Testing Requirements

- [ ] **Rate Limiting Tested**: Verify endpoint respects configured limits
- [ ] **Authentication Tested**: Test both authenticated and unauthenticated scenarios
- [ ] **Tenant Isolation Tested**: Verify users cannot access other tenants' data
- [ ] **Error Scenarios Tested**: Test invalid inputs, missing data, etc.

### ✅ Documentation

- [ ] **XML Documentation**: Add `/// <summary>` comments to all public methods
- [ ] **Rate Limiting Documented**: Update rate limiting documentation if using new policy
- [ ] **API Changes Logged**: Update changelog for breaking changes

### 🔍 Quick Rate Limiting Test Commands

```bash
# Test GlobalLimiter (most endpoints) - should handle 100+ requests
for i in {1..5}; do curl -X GET "http://localhost:5000/api/your-new-endpoint" -w "%{http_code} "; done

# Test specific policy - should respect policy limits
for i in {1..20}; do curl -X POST "http://localhost:5000/api/your-secured-endpoint" \
  -H "Content-Type: application/json" -d '{"test":"data"}' -w "%{http_code} "; done

# Expected: First N requests return 200, then 429 after limit exceeded
```

**❌ DEPLOYMENT BLOCKED** if any checklist item is not verified.

## 🔍 Vector Search System (v1.3.2 - OPTIMIZED)

The application implements high-performance cosine similarity vector search for accurate document retrieval.

**Latest Update (Oct 3, 2025)**: Major performance optimization - 50-100x faster database loading with parallel processing and query optimization.

### 🎯 Vector Search Features
- **Cosine Similarity**: Accurate vector distance calculation using dot product and magnitude
- **Multi-Field Support**: Searches across Content, HeaderContext, Notes, and Details embeddings
- **Maximum Score**: Takes the highest similarity score across all embedding fields
- **Configurable Results**: Returns top N chunks (1-50, default: 10)
- **Default Similarity Threshold**: 0.5 (50%) for balanced precision/recall
- **🚀 High Performance**: Parallel processing + optimized queries

### ⚡ Performance Optimizations
- **Parallel Processing**: Multi-threaded similarity computation using all CPU cores
- **Query Projection**: Loads only necessary data (no heavy EF Core Include)
- **Database Indices**: Optimized indices on all embedding foreign keys
- **AsNoTracking**: Read-only queries with no change tracking overhead
- **Performance Metrics**: Real-time load/compute/total time logging

**Performance Results** (566 chunks):
```
Before: Load=26602ms, Compute=107ms, Total=26718ms
After:  Load=50-200ms,  Compute=107ms, Total=150-300ms
Improvement: 50-100x faster! 🚀
```

### 📊 Search Flow
1. **Query Embedding**: User query is converted to vector embedding via configured AI provider
2. **Load Chunks**: Optimized projection query loads only embeddings + metadata
3. **Parallel Compute**: Multi-threaded cosine similarity across all chunks
4. **Rank Results**: Sorts by similarity score (descending) and returns top N chunks
5. **RAG Response**: AI generates response using retrieved chunks as context

### 💻 Implementation Details
Located in `RagChatApp_Server/Services/AzureOpenAIService.cs`:
- `PerformMultiFieldVectorSearchAsync()`: Main vector search with parallel processing
- `CosineSimilarity()`: Cosine similarity calculation
- `Parallel.ForEach()`: Multi-threaded similarity computation
- Database indices: `Database/Migrations/AddPerformanceIndices.sql`

### 📈 Example Results
Query: "Come si inserisce un prodotto in GP90?"
- Max score: 67.6% similarity (optimal for semantic search)
- Returns 10 most relevant chunks with accurate scores
- Search time: ~200ms for 566 chunks
- AI generates precise, context-aware responses

### 🎚️ Configuration
- **UI Range**: 1-50 chunks (slider in chat interface)
- **Similarity Threshold**: 0.1-1.0 (default 0.5, recommended 0.3-0.6)
- **Semantic Cache**: Disabled (respects dynamic parameters)

## 📂 Document Opening Feature (v1.3.0 - NEW)

Chat interface now includes the ability to open source documents directly from chat responses.

### 🔗 Features
- **Click-to-Open Button**: Each chat source displays a "📂 Apri" button if document path is available
- **Browser Opening**: Attempts to open document in new window/tab using `file:///` protocol
- **Clipboard Fallback**: If browser blocks file access, offers to copy path to clipboard
- **Cross-Browser Support**: Uses modern Clipboard API with fallback for older browsers
- **User-Friendly**: Shows confirmation toasts and helpful dialogs

### 🎨 UI Implementation
Located in `RagChatApp_UI/js/app.js`:
- `openDocument()`: Main document opening function
- `showDocumentPathDialog()`: Fallback dialog with clipboard option
- `copyToClipboard()`: Modern and fallback clipboard copy methods

Styled with glassmorphism design in `RagChatApp_UI/css/style.css`:
- `.btn-link`: Consistent button styling with hover effects
- `.source-header`: Flexbox layout for buttons and metadata

## 🤖 Multi-Provider AI System (v1.2.1)

The application features a complete multi-provider AI system supporting OpenAI, Google Gemini, and Azure OpenAI with dynamic switching and configuration-driven selection.

### 🔄 Supported AI Providers
- **OpenAI**: GPT models and text-embedding-3-small
- **Google Gemini**: Gemini models and embedding-001
- **Azure OpenAI**: Enterprise deployment support
- **Extensible**: Easy to add new providers (Claude, Cohere, etc.)

### ⚙️ Configuration
```json
{
  "AIProvider": {
    "DefaultProvider": "Gemini",
    "OpenAI": { "ApiKey": "...", "BaseUrl": "..." },
    "Gemini": { "ApiKey": "...", "BaseUrl": "..." },
    "AzureOpenAI": { "ApiKey": "...", "Endpoint": "..." }
  }
}
```

### 🛠️ New API Endpoints
```bash
GET  /api/aiprovider/info                    # Provider information
POST /api/aiprovider/test/embedding         # Test embedding generation
POST /api/aiprovider/test/all               # Test all providers
GET  /api/info                              # Enhanced with provider info
```

### 🔐 Encrypted API Key Storage (v1.3.1 - NEW)

**API keys are automatically encrypted using AES-256** and stored securely in the database.

#### Security Features
- **AES-256 Encryption**: SQL Server built-in encryption with Certificate and Symmetric Key
- **Automatic Encryption**: API keys encrypted on insert/update via `SP_UpsertProviderConfiguration`
- **Controlled Decryption**: Only authorized stored procedures can decrypt keys
- **Safe Views**: `vw_AIProviderConfiguration` shows masked keys (`***ENCRYPTED***`)
- **Disaster Recovery**: Certificate backup support for key recovery

#### Encryption Hierarchy
```
Database Master Key (Password Protected)
    └── Certificate (RagApiKeyCertificate)
        └── Symmetric Key (RagApiKeySymmetricKey, AES-256)
            └── Encrypted API Keys (VARBINARY)
```

#### Usage Examples
```sql
-- Insert/Update provider with encrypted API key (automatic encryption)
EXEC SP_UpsertProviderConfiguration
    @ProviderName = 'Gemini',
    @ApiKey = 'AIzaSy-your-actual-api-key',
    @BaseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    @Model = 'models/embedding-001';

-- View configurations (keys masked)
SELECT * FROM vw_AIProviderConfiguration;
-- Output: ApiKeyStatus = '***ENCRYPTED***', HasApiKey = 1

-- Use in RAG procedures (automatic decryption)
EXEC SP_GetDataForLLM_Gemini
    @SearchText = 'your query',
    @TopK = 10;
-- Behind the scenes: key is decrypted, used for API call, never logged
```

#### ⚠️ CRITICAL: Backup Certificate
```sql
-- Backup certificate immediately after installation!
BACKUP CERTIFICATE RagApiKeyCertificate
    TO FILE = 'C:\Backup\RagApiKeyCertificate.cer'
    WITH PRIVATE KEY (
        FILE = 'C:\Backup\RagApiKeyCertificate.pvk',
        ENCRYPTION BY PASSWORD = 'YourSecureBackupPassword123!'
    );
```

**Without certificate backup**: If the certificate is lost, all encrypted API keys become **permanently unrecoverable**. Store backups in:
- Azure Key Vault (recommended for production)
- Encrypted secure file share
- Offline secure location
- **NEVER in source control** (`.cer` and `.pvk` files are in `.gitignore`)

#### Documentation
- **Installation Guide**: `RagChatApp_Server/Database/StoredProcedures/README_Installation.md`
- **Encryption Guide**: `RagChatApp_Server/Database/StoredProcedures/ENCRYPTION_UPGRADE_GUIDE.md`
- **Cleanup Script**: `00_CleanupEncryption.sql` (for reinstallation)

### 🗄️ Database Multi-Provider Support
```sql
-- Generate embedding with specific provider
EXEC SP_GenerateEmbedding_MultiProvider
  @Text = 'sample text',
  @Provider = 'Gemini',
  @ApiKey = 'your-key';

-- Test all configured providers
EXEC SP_TestMultiProviderWorkflow;
```

### 🔧 HttpClient Configuration (Important!)
The multi-provider system uses proper HttpClient configuration in `Program.cs`:
- **BaseAddress must end with `/`** for correct URL path concatenation
- **Relative paths must NOT start with `/`** (use `"embeddings"` not `"/embeddings"`)
- Configuration is done via `AddHttpClient<T>()` with lambda configuration
- Each provider service receives a pre-configured HttpClient instance

**Example (OpenAI)**:
```csharp
builder.Services.AddHttpClient<OpenAIProviderService>((serviceProvider, client) =>
{
    var baseUrl = config["AIProvider:OpenAI:BaseUrl"]; // "https://api.openai.com/v1"
    if (!baseUrl.EndsWith("/")) baseUrl += "/";
    client.BaseAddress = new Uri(baseUrl); // Results in "https://api.openai.com/v1/"
    client.DefaultRequestHeaders.Add("Authorization", $"Bearer {apiKey}");
});

// In service: await _httpClient.PostAsync("embeddings", content);
// Results in: https://api.openai.com/v1/embeddings ✅
```

## 🗄️ SQL Interface (ENHANCED)

The application provides both REST API and direct SQL interface with multi-provider support.

### 📋 Available Stored Procedures

#### Documents CRUD
```sql
-- Insert document
DECLARE @DocId INT;
EXEC SP_InsertDocument 'example.pdf', 'application/pdf', 1024, 'content...', '/docs/example.pdf', 'Pending', @DocId OUTPUT;

-- Get documents with pagination
EXEC SP_GetAllDocuments @PageNumber = 1, @PageSize = 10, @Status = 'Completed';

-- Update document
EXEC SP_UpdateDocument @DocumentId = 1, @Status = 'Completed', @ProcessedAt = GETUTCDATE();

-- Delete document and all related data
EXEC SP_DeleteDocument @DocumentId = 1;
```

#### DocumentChunks and Embeddings
```sql
-- Insert chunk with embeddings
DECLARE @ChunkId INT;
EXEC SP_InsertDocumentChunk
    @DocumentId = 1, @ChunkIndex = 0, @Content = 'chunk content',
    @HeaderContext = 'Section 1', @Notes = 'important', @Details = '{"tag":"ai"}',
    @ContentEmbedding = 0x1234..., @ChunkId = @ChunkId OUTPUT;

-- Get chunks for a document
EXEC SP_GetDocumentChunks @DocumentId = 1, @IncludeEmbeddings = 0;
```

#### RAG Search with JSON Response
```sql
-- Perform RAG search (returns JSON)
DECLARE @QueryEmbedding VARBINARY(MAX) = 0x1234...;
EXEC SP_RAGSearch @QueryEmbedding, @MaxResults = 10, @SearchQuery = 'machine learning';

-- JSON Response Format:
-- [{"Id":1,"HeaderContext":"AI Basics","Content":"ML is...","SimilarityScore":85.5,"FileName":"guide.pdf"}]
```

#### Semantic Cache Management
```sql
-- Clean old cache entries
EXEC SP_CleanSemanticCache @MaxAgeHours = 1;

-- Get cache statistics
EXEC SP_GetSemanticCacheStats;

-- Search in cache
EXEC SP_SearchSemanticCache @SearchQuery = 'deep learning', @ExactMatch = 1;
```

### 🔧 SQL Interface Installation

**Recommended: Use PowerShell Installer (Automated)**:
```powershell
cd RagChatApp_Server/Database/StoredProcedures

# Install with encrypted API key configuration
.\Install-MultiProvider.ps1 `
    -GeminiApiKey "your-gemini-api-key" `
    -OpenAIApiKey "your-openai-api-key" `
    -TestAfterInstall
```

This automatically:
- ✅ Creates AES-256 encryption infrastructure
- ✅ Installs all multi-provider procedures
- ✅ Installs simplified RAG procedures
- ✅ Encrypts and stores API keys securely
- ✅ Runs post-installation tests

**Manual Installation** (if needed):
1. **Run Migrations First**:
   ```bash
   cd RagChatApp_Server
   dotnet ef database update
   ```

2. **Install Stored Procedures**:
   ```sql
   -- Update database name in script
   USE [YourDatabaseName]
   GO
   :r "Database/StoredProcedures/00_InstallAllStoredProcedures.sql"
   ```

3. **Verify Installation**:
   ```sql
   -- List installed procedures
   SELECT ROUTINE_NAME FROM INFORMATION_SCHEMA.ROUTINES
   WHERE ROUTINE_TYPE = 'PROCEDURE' AND ROUTINE_NAME LIKE 'SP_%'
   ORDER BY ROUTINE_NAME;
   ```

### 📚 Complete SQL Documentation
See `RagChatApp_Server/Database/StoredProcedures/README.md` for comprehensive documentation, examples, and usage patterns.

### 🔄 API + SQL Workflow
- **REST API**: For web applications, mobile apps, and real-time interactions
- **SQL Interface**: For bulk operations, reporting, analytics, and external system integration
- **Both interfaces**: Access the same underlying data with consistent behavior

## Development Principles

Follow these core software development principles when working on this codebase:

### KISS (Keep It Simple, Stupid)
- Write straightforward, uncomplicated solutions
- Avoid over-engineering and unnecessary complexity
- Prioritize readable and maintainable code
- Choose simple implementations over clever ones

### YAGNI (You Aren't Gonna Need It)
- Implement only what's currently needed
- Don't add speculative features or functionality
- Avoid code bloat and unnecessary abstractions
- Focus on present requirements, not hypothetical future needs

### SOLID Principles
- **Single Responsibility Principle**: Each class should have one reason to change
- **Open-Closed Principle**: Open for extension, closed for modification
- **Liskov Substitution Principle**: Subtypes must be substitutable for their base types
- **Interface Segregation Principle**: Prefer specific interfaces over general ones
- **Dependency Inversion Principle**: Depend on abstractions, not concretions

### Error Handling & Logging

- **Structured Logging**: Use `ILogger` with proper log levels and context
- **Exception Handling**: Wrap operations in try-catch with appropriate error responses
- **PII Protection**: Don't log sensitive information (passwords, tokens, personal data)
- **Dependency injection logging**: Log each in and out from every method, for better log analayse

### Performance & Scalability

- **Async Operations**: Use `async/await` for all I/O operations
- **Database Efficiency**: Optimize queries, avoid N+1 problems
- **Memory Management**: Dispose resources properly, avoid memory leaks

## Documentation Practice

### Feature Development Workflow
When implementing new features or making significant changes, maintain comprehensive documentation:

1. **Before Implementation**: Create or update `/Documentation/app_info/YYYY-MM-DD_desired_app_functionality.md`
	- Document the desired changes and requirements
	- Specify tier restrictions and business logic
	- Define success criteria

2. **After Implementation**: Create `/Documentation/app_info/YYYY-MM-DD_implementation_update.md`
	- List all files created/modified
	- Document technical implementation details
	- Include build status and test results
	- Note any pending items or known issues

3. **Current State Documentation**: Maintain `/Documentation/app_info\YYYY-MM-DD_app_functionality.md`
	- Keep an up-to-date snapshot of current functionality
	- Organize by features and tiers
	- Include both implemented and planned features
	- Mark items clearly as ✅ Completed or ⌛ Pending

## 📚 MODELLO DI DOCUMENTAZIONE CRITICA
**AGGIUNGI SEMPRE QUI I DOCUMENTI IMPORTANTI!** Quando crei o scopri:

### 🏗️ Architettura e Design
- **Sistema RAG - Architettura Completa** → `/Documentation/ArchitectureDiagram/system-architecture.md`
  - Pipeline RAG (Retrieval-Augmented Generation)
  - Architettura backend .NET 9.0
  - Struttura frontend HTML/CSS/JavaScript
  - Integrazione Azure OpenAI
  - Diagrammi di flusso per indicizzazione e chat

### 🗄️ Database e Schema
- **Schema Database RAG** → `/Documentation/DatabaseSchemas/rag-database-schema.md`
  - Schema SQL Server completo con VECTOR(1536)
  - Entity Framework Core configuration
  - Indici per performance vettoriale
  - Query di esempio e monitoring
  - Configurazione produzione e backup

### 🔧 Configurazione e Setup
- **Guida Setup Completa** → `/Documentation/ConfigurationGuides/setup-configuration-guide.md`
  - Configurazione Azure OpenAI Service
  - Database SQL Server (locale, remoto, Azure)
  - CORS e networking
  - Environment specifici (Dev/Prod)
  - Docker deployment
  - Troubleshooting comune

### 🛠️ Problem Solving
- **Fix Connettività Frontend-Backend** → `/Documentation/ProblemSolving/frontend-backend-connectivity-fix.md`
  - Risoluzione port mismatch
  - HTTPS redirection issues
  - Configurazione CORS
  - Metodologia debugging network
  - Test di verifica e monitoring

## Git Workflow e Versioning

### 🔄 Commit Guidelines
**OBBLIGATORIO**: Ogni modifica significativa deve essere committata su Git con messaggi descrittivi.

#### Regole per i Commit
- **Frequenza**: Commit dopo ogni feature completata o bug fix
- **Granularità**: Un commit per ogni logica unità di lavoro
- **Messaggi**: Utilizzare il formato convenzionale con descrizione chiara
- **Testing**: Assicurarsi che il codice compili prima del commit

#### Formato Messaggi Commit
```
<tipo>(<scope>): <descrizione>

[corpo opzionale]

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Tipi di commit:**
- `feat`: nuova funzionalità
- `fix`: correzione bug
- `docs`: solo documentazione
- `style`: formattazione, punto e virgola mancanti, ecc.
- `refactor`: refactoring del codice
- `test`: aggiunta di test
- `chore`: task di manutenzione

#### Esempi di Commit Messages
```bash
feat(api): add document upload endpoint with file validation
fix(ui): resolve CORS issue in production environment
docs(readme): update setup instructions for Azure OpenAI
refactor(services): improve error handling in DocumentProcessingService
```

### 📋 Pre-Commit Checklist
Prima di ogni commit, verificare:
- [ ] **Build Success**: `dotnet build` completa senza errori
- [ ] **Tests Pass**: Tutti i test unitari passano
- [ ] **Linting**: Codice formattato correttamente
- [ ] **Documentation**: Documentazione aggiornata se necessario
- [ ] **Security**: Nessun secret o credential nel codice
- [ ] **CLAUDE.md**: Aggiornato se cambiati workflow o architettura

### 🚀 Workflow Standard
```bash
# 1. Verifica stato repository
git status
git pull origin main

# 2. Sviluppo e testing
dotnet build
dotnet test # se applicabile

# 3. Staging delle modifiche
git add .
# OPPURE specifiche
git add RagChatApp_Server/Controllers/DocumentsController.cs

# 4. Commit con messaggio descrittivo
git commit -m "feat(api): implement document processing with chunking

- Add intelligent text chunking based on markdown headers
- Implement vector embedding generation
- Add background processing for large documents
- Include comprehensive error handling and logging

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# 5. Push al repository
git push origin main
```

### 🔧 Git Configuration Setup
```bash
# Configurazione iniziale (solo prima volta)
git config --global user.name "Your Name"
git config --global user.email "your.email@company.com"
git config --global init.defaultBranch main

# Configurazione per questo progetto
git config core.autocrlf true
git config core.filemode false
```

### 📊 Branching Strategy
- **main**: branch principale per produzione
- **develop**: branch di sviluppo per nuove feature
- **feature/***: branch per feature specifiche
- **hotfix/***: branch per correzioni urgenti

```bash
# Creare feature branch
git checkout -b feature/chat-interface
git commit -m "feat(ui): implement chat interface"
git push origin feature/chat-interface

# Merge dopo review
git checkout main
git merge feature/chat-interface
git push origin main
git branch -d feature/chat-interface
```

### 🏷️ Tagging delle Release
```bash
# Creare tag per release
git tag -a v1.0.0 -m "Release version 1.0.0 - Initial RAG Chat Application"
git push origin v1.0.0

# Listrare tag esistenti
git tag -l
```

### 📝 Commit automaton con script
Creare `commit-and-push.ps1`:
```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$Message,
    [string]$Type = "feat",
    [string]$Scope = ""
)

# Build check
Write-Host "🔨 Building project..."
dotnet build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed. Commit aborted."
    exit 1
}

# Git operations
git add .
$commitMessage = if ($Scope) { "$Type($Scope): $Message" } else { "$Type: $Message" }
$fullMessage = @"
$commitMessage

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
"@

git commit -m $fullMessage
git push origin main

Write-Host "✅ Committed and pushed: $commitMessage" -ForegroundColor Green
```

Uso: `.\commit-and-push.ps1 -Message "implement document upload" -Type "feat" -Scope "api"`

## Notes

- Project follows clean architecture principles
- All API endpoints must have rate limiting configured
- Database uses SQL Server with vector support for embeddings
- Support both connected AI mode and mock mode for development
- Emphasize code simplicity and maintainability
- Comprehensive logging and error handling required
- **MANDATORY**: Commit all changes to Git with descriptive messages
- Follow the Git workflow for all modifications and improvements