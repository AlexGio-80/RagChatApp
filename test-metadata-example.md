# RAG Chat App - Metadata Test Document

Questo documento di test dimostra l'utilizzo della nuova interfaccia di metadati per il caricamento di documenti.

## Funzionalità Implementate

### 1. 📝 Notes (Note del Documento)
- Campo di testo libero per note descrittive
- Visibile nell'interfaccia durante l'upload
- Salvato nel campo Notes della tabella DocumentChunks
- Genera embeddings separati per migliorare la ricerca

### 2. 🏷️ Tag Strutturati
I seguenti campi strutturati sono disponibili:
- **Autore**: Nome dell'autore del documento
- **Tipo**: Categoria del contenuto (es. documentation, code sample)
- **Licenza**: Tipo di licenza (es. MIT, Apache)
- **Linguaggi**: Linguaggi di programmazione (es. .NET, Python)
- **Servizi**: Servizi utilizzati (es. Azure SQL, OpenAI)
- **Tag Generici**: Tag liberi separati da virgole

### 3. 💾 JSON Personalizzato
Campo per JSON strutturato personalizzato che viene unito con i tag strutturati.

## Esempio di Metadata JSON
```json
{
    "author": "Davide Mauri",
    "languages": [".NET"],
    "license": "MIT",
    "services": ["Azure SQL"],
    "tags": ["Azure", "SQL", "Embeddings", "Vectorizer"],
    "type": "code sample",
    "priority": 1,
    "version": "2.0",
    "category": "AI/ML"
}
```

## Benefici per la Ricerca
Con questi metadati, la ricerca RAG può ora:
- Trovare documenti per autore
- Filtrare per tipo di contenuto
- Identificare documenti con tecnologie specifiche
- Migliorare la rilevanza delle risposte attraverso embeddings multi-campo

## Test della Funzionalità
1. Caricare questo documento tramite l'interfaccia web
2. Compilare i campi metadata con i dati dell'esempio sopra
3. Eseguire una chat query come "Trova documenti di Davide Mauri su Azure SQL"
4. Verificare che la ricerca utilizzi gli embeddings dei metadati per risultati più pertinenti