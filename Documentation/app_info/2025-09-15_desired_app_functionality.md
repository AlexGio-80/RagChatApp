# 2025-09-15 - Desired App Functionality

## Project Overview
Create a RAG (Retrieval-Augmented Generation) chat application that allows users to upload documents and interact with AI using document content as context.

## Core Requirements

### Document Management
- **File Upload Support**: .txt, .pdf, .doc, .docx files
- **Text Indexing**: Direct text input without file upload
- **File Size Limit**: Maximum 50MB per file
- **Document Processing**: Extract text content and create searchable chunks
- **Document CRUD**: Create, Read, Update, Delete operations
- **Status Tracking**: Processing status (Pending, Processing, Completed, Failed)

### Intelligent Document Chunking
- **Header-Based Splitting**: Use markdown headers as natural break points
- **Size Limits**: Maximum 1000 characters per chunk
- **Structure Preservation**: Maintain document hierarchy and context
- **Header Context**: Preserve both header and content between headers
- **Metadata Storage**: Track chunk index, creation time, and relationships

### AI Integration
- **Azure OpenAI Service**: Integration for embeddings and chat completions
- **Vector Embeddings**: Generate 1536-dimension embeddings for similarity search
- **Mock Mode**: Development mode that simulates AI responses
- **RAG Implementation**: Retrieve relevant chunks and augment AI responses
- **Source Attribution**: Show which documents contributed to responses

### Chat Functionality
- **Real-time Chat**: Interactive messaging interface
- **Configurable Parameters**:
  - Maximum chunks to include (1-10)
  - Similarity threshold (0.1-1.0)
- **Source Display**: Show relevant document chunks with similarity scores
- **Response Formatting**: Maintain original formatting where possible
- **Multiple Occurrences**: Separate results by chunk/context found

### Database Design
- **SQL Server**: Primary database with vector support
- **Document Table**: Store file metadata and full content
- **DocumentChunk Table**: Store processed chunks with embeddings
- **Vector Storage**: VARBINARY(MAX) for 1536-dimension embeddings
- **Cascade Delete**: Remove chunks when parent document is deleted
- **Performance Indexes**: Optimize for search and retrieval

### API Endpoints
```
POST /api/documents/upload      - File upload
POST /api/documents/index-text  - Direct text indexing
PUT /api/documents/{id}         - Update document
DELETE /api/documents/{id}      - Delete document
GET /api/documents              - List all documents
POST /api/chat                  - Chat with AI
GET /api/chat/info             - Service information
GET /health                     - Health check
GET /api/info                   - API information
```

### Frontend Requirements
- **Responsive Design**: Modern glassmorphism interface
- **Tab Navigation**: Document Management / Chat AI
- **Drag & Drop**: File upload with visual feedback
- **Document List**: Show processing status and metadata
- **Chat Interface**: Real-time messaging with source attribution
- **Settings**: Configurable chat parameters
- **Toast Notifications**: User feedback system
- **Mobile Support**: Responsive design for all devices

### Security & Performance
- **Rate Limiting**: 100 requests/minute per IP
- **Input Validation**: Comprehensive validation with Data Annotations
- **SQL Injection Protection**: Parameterized queries via Entity Framework
- **CORS Configuration**: Proper cross-origin resource sharing
- **Background Processing**: Async document processing
- **Error Handling**: Comprehensive try-catch with logging
- **Structured Logging**: ILogger with proper context

### Development Features
- **Mock Mode**: Work without Azure OpenAI for development
- **Swagger Documentation**: Auto-generated API documentation
- **Health Checks**: System health monitoring
- **Configuration**: Environment-specific settings
- **Database Migrations**: Entity Framework migrations
- **Development Tools**: Hot reload, debugging support

## Success Criteria

### Functional
- ✅ Users can upload supported document types
- ✅ Text is extracted and chunked intelligently
- ✅ Embeddings are generated and stored
- ✅ Chat provides relevant responses with sources
- ✅ Mock mode works without external dependencies
- ✅ All CRUD operations function correctly

### Non-Functional
- ✅ Response time < 5 seconds for chat
- ✅ File upload completes within reasonable time
- ✅ UI is responsive on mobile devices
- ✅ System handles multiple concurrent users
- ✅ Error messages are user-friendly
- ✅ System recovers gracefully from failures

### Quality
- ✅ Code follows SOLID principles
- ✅ Comprehensive error handling
- ✅ Structured logging throughout
- ✅ Rate limiting prevents abuse
- ✅ Input validation prevents security issues
- ✅ Documentation is complete and accurate

## Constraints

### Technical
- Must use .NET 9.0 for backend
- Must use SQL Server for database
- Must support Azure OpenAI integration
- Must have mock mode for development
- Must follow rate limiting requirements
- Must implement proper CORS

### Business
- Support Italian language interface
- Maintain document formatting when possible
- Provide clear source attribution
- Handle multiple file types seamlessly
- Ensure data privacy and security

### Performance
- Maximum 50MB file size
- Response time targets for chat
- Concurrent user support
- Database query optimization
- Memory usage optimization

## Implementation Priority

### Phase 1 (MVP)
1. Basic document upload and storage
2. Text extraction for supported formats
3. Simple chunking algorithm
4. Mock AI responses
5. Basic chat interface

### Phase 2 (Enhanced)
1. Azure OpenAI integration
2. Vector embeddings and similarity search
3. Intelligent chunking with headers
4. Source attribution in responses
5. Advanced UI features

### Phase 3 (Production)
1. Performance optimization
2. Comprehensive error handling
3. Security hardening
4. Monitoring and logging
5. Production deployment

This specification serves as the foundation for implementing a robust, scalable RAG chat application with comprehensive document management and AI integration capabilities.