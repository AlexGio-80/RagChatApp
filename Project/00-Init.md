# Chat RAG model
Lo scopo di questa implementazione è quello di realizzare una chat sfruttando la tecnologia RAG per interrogare dei documenti importati su un database SQL-2025 per poter sfruttare i vettori per le ricerche.
Il progetto si compone di una servizio di BE per la gestione del domain e di un FE scritto in Angular per la UI.

## Inizializzazione progetto
### Documentazione per CLAUDE.md
Alla creazione del progetto implementare il CLAUDE.md con il contenuto dei seguenti file per le regole di gestione del progetto
1. **Api development**: `C:\OSL\Claude\docs\API_DEVELOPMENT.md`
1. **Development principles**: `C:\OSL\Claude\docs\DEVELOPMENT_PRINCIPLES.md`
1. **Documentation practice**: `C:\OSL\Claude\docs\DOCUMENTATION_PRACTICE.md`
1. **Critical documentation**: `C:\OSL\Claude\docs\CRITICAL_DOCUMENTATION.md`

## Architettura

- **RagChatApp_Server** (.NET 9.0): Backend API con gestione documenti e chat AI
- **RagChatApp_UI** (HTML/CSS/JS): Frontend per gestione documenti e interfaccia chat

### RagChatApp_Server ✅

1. **Database SQL Server**
   - Tabelle Documents e DocumentChunks
   - Campo VECTOR(1536) per embeddings (implementato come VARBINARY)
   - Gestione relazioni con cascade delete
   - esempio di stringa di connessione: Data Source=DEV-ALEX\\MSSQLSERVER01;Encrypt=False;Integrated Security=True;User ID=OSL\\a.giovanelli;Initial Catalog=OSL_AI

2. **Chunking Intelligente**
   - Spezzettamento basato su header markdown
   - Chunk massimi di 1000 caratteri
   - Preservazione della struttura del documento
   - Conservare sia l'header sia il contenuto del testo tra un'header e l'altro

3. **API Endpoints**
   - `POST /api/documents/upload` - Caricamento file (.txt, .pdf, .doc, .docx)
   - `POST /api/documents/index-text` - Indicizzazione testo diretto
   - `PUT /api/documents/{id}` - Aggiornamento documento
   - `DELETE /api/documents/{id}` - Cancellazione documento
   - `GET /api/documents` - Lista documenti
   - `POST /api/chat` - Chat con AI

4. **Integrazione Azure OpenAI**
   - Generazione embeddings per similarity search
   - Chat completions con contesto RAG
   - API HTTP personalizzata per massima compatibilità   

5. **Servizio di mock**
    - Prevedere una modalità di esecuzione del progetto in modalità mock che non usa l'integrazione con l'AI, ma che simula a BE la ricerca e restituisce i risultati al FE come se fosse una AI.

Sia in modalità collegata alla AI, sia in modalità mock a fronte di una ricerca deve essere restituito tutto il contenuto delle corrispondenze trovato, deve essere visualizzato mantenendo la formattazione originale ove possibile e deve essere suddiviso per occorenze trovate (es. di ricerca. Quali sono i requisiti di sistema? -> ricerca trova corrispondenze in due chunk, uno nel contesto e uno nel titolo, quindi il risultato sarà di due blocchi di risposta, uno contenente il testo dell'occorrenza trovata nell'header, e uno con il testo dell'occorenza trovata nel testo)

### RagChatApp_UI ✅

1. **Interfaccia Responsiva**
   - Design moderno con gradiente e glassmorphism
   - Navigazione a tab (Gestione Documenti / Chat AI)
   - Drag & drop per upload file

2. **Gestione Documenti**
   - Upload multiplo file supportati
   - Indicizzazione testo diretto
   - Lista documenti con informazioni dettagliate
   - Cancellazione documenti

3. **Chat Interface**
   - Chat in tempo reale con AI
   - Visualizzazione fonti nei risultati
   - Input con supporto Enter per invio
   - Messaggi scrollabili
