# Chat RAG model
Lo scopo di questa implementazione è quello di ottenere dei chunck coerenti con le domande che vengono fatte nella chat per poterle dare poi in pasto al LLM in modo che dia le risposte all'utente finale.

## Inizializzazione progetto
### Documentazione per CLAUDE.md
Alla creazione del progetto implementare il CLAUDE.md con il contenuto dei seguenti file per le regole di gestione del progetto
1. **Api development**: `C:\OSL\Claude\docs\API_DEVELOPMENT.md`
1. **Development principles**: `C:\OSL\Claude\docs\DEVELOPMENT_PRINCIPLES.md`
1. **Documentation practice**: `C:\OSL\Claude\docs\DOCUMENTATION_PRACTICE.md`
1. **Critical documentation**: `C:\OSL\Claude\docs\CRITICAL_DOCUMENTATION.md`

### RagChatApp_Server ✅
!!!IMPORTANTE!!!: Tutte le implementazioni nuove e anche quelle già esistenti andranno replicate tramite stored procedure di SQL che replicheranno i comportamenti delle API, o che si interfacceranno con esse, l'importante è che io possa inserire, cancellare, modificare documenti, e fare qualunquen operazione consentita tramite le API anche da stored procedure. E cosa più importante sarà necessario avere una stored che mi restituirà un json con l'elenco dei risultati della ricerca dei chunck per il modello LLM che risponderà poi alla chat.

1. **Caricamento dei documenti a database**
	- Le funzioni di Insert/Delete/Update dei documenti dovranno essere fruibili sia via rest API, sia da database.
	- La funzione di Update di un documento, dovrà cancellare tutti i chunck e gli embedding relativi e ricrearli
	- L'import di documenti di tipo testo dovrà ragionare come fa già ora con i markdow per separare i chunck ove possibile
	- L'import di documenti di tipo pdf dovrebbe separare i chunck seguendo la seguente logica
		-- Usa una libreria C# come PdfPig per estrarre il testo grezzo.
		-- Normalizza il testo: Rimuovi doppi spazi, interruzioni di riga non necessarie, ecc.
		-- Applica una strategia di chunking:
			--- Se puoi identificare la struttura (es. paragrafi, sezioni basate su pattern di testo), usala.
			--- Altrimenti, dividi per dimensione fissa (es. 750 token / 3000 caratteri) con una sovrapposizione (es. 10-20%).
		-- Il salvataggio degli HeaderContext andrà fatto solo se si riesce a individuare la struttura dei paragrafi e/o sezioni, altrimenti se ci si basa sulle dimensioni non salveremo l'Header (stesso ragionamento per i file di testo).
	
1. **Database SQL Server**
	- implementare nella tabella Documents il path o url del documento per passarlo poi nei dati di uscita in modo che si possa aggiungere come link (o più link in caso il risultato provenga da più documenti) al risultato da restituire per la chat.
	- nella tabella DocumentChuncks implementare le colonne:
		-- Notes dove posso inserire delle note quando carico il documento, o quando lo modifico
		-- Details dove verrà salvato un Json con dei dettagli aggiuntivi per le ricerche con dei dati imputabili nella form di caricamento (esempio di Json 
		{
			"author": "Davide Mauri",
			"languages": [".NET"],
			"license": "MIT",
			"services": ["Azure SQL"],
			"tags": ["Azure", "SQL", "Embeddings", "Vectorizer"],
			"type": "code sample"
		}
	- Nella tabella DocumentChunks andrà tolta la colonna Embedding e andranno create quattro nuove tabelle che hanno una relazione diretta 1:1 con il record della DocumentChunks, dove salverò gli Embedding per Content, HeaderContext, Notes e Details, quindi le tabelle da fare saranno:
		-- DocumentChunkContents_Embedding
		-- DocumentChunkHeaderContext_Embedding
		-- DocumentChunkNotes_Embedding
		-- DocumentChunkDetails_Embedding
	in ognuna di queste tabelle avrò un campo di riferimento (fk) alla DocumentChunks, un campo Embedding contentente l'embedding del realtivo campo della tabella principale, una data di inserimento e una data di aggiornamento del record.
	- Gestione relazioni con cascade delete
	- Implementiamo una tabella SemanticCache per tenere traccia delle ultime ricerche fatte nell'ultima ora dove salveremo
		-- la stringa della riceca effettuata
		-- il Content del risultato con percentuale più vicina alla ricerca effettuata
		-- l'Embedding del Conten del risultato con percentuale più vicina alla ricerca effettuata
		-- la data di inserimento nella tabella Semanti
		- Se serve implementare nelle tabelle indici FullText

2. **Logiche di recupero degli embeddings**
Qui di seguito elenco l'ordine delle operazioni da fare per ottenere i risultati da restituire all'LLM sotto forma di Json
	- Cancellare dalla tabella SemanticCache i dati più vecchi di un'ora
	- Verificare nella tabella SemanticCache se la ricerca è già stata fatta e in quel caso restituire il Content e non proseguire con la ricerca
	- implementare un parametro nell'appsettings per definire il numero massimo di chunck da recuperare per passarli all'LLM. Se il parametro non è specificato di default vale 50; Nell'appsettings il default sarà 10; Se il valore indicato nell'appsettings è maggiore di 50 usare 50.
	- Quando viene fatta la ricerca negli embedding deve essere preso in considarazione quello con distanza dal coseno più lontana da 1 tenedo conto del valore delle quattro tabelle dove vengono salvati gli embedding del Content, delle Notes e dei Details. in SQL la cosa si può configurare così per fare un'esempio pratico
		set @k = coalesce(@k, 50)         
		select top(@k) 
			dc.id,
			[Content], [HeaderContext], [notes], [details], 
			least(
				vector_distance('cosine', dcce.[embedding], @qv), 
				vector_distance('cosine', ehc.[embedding], @qv), 
				vector_distance('cosine', ne.[embedding], @qv), 
				vector_distance('cosine', de.[embedding], @qv) 
			) as cosine_distance
		into
			#s
		from 
			dbo.DocumentChuncks dc
		inner join    
			dbo.DocumentChunkContents_Embedding dcce on dc.id = dcce.DocumentChunckId
		left join
			dbo.DocumentChunkHeaderContext_Embedding dchde on dc.id = dchde.DocumentChunckId
		left join
			dbo.DocumentChunkNotes_Embedding dcne on dc.id = dcne.DocumentChunckId    
		left join
			dbo.DocumentChunkDetails_Embedding dcde on dc.id = dcde.DocumentChunckId    
		order by 
			cosine_distance asc;
	- Per i dati di ritorno alle API verrà restituito un Json con i campi elenvati di seguito, mentre per la versione SQL i dati dovranno essere restituiri in colonne separate:
		-- Id del record della DocumentChuncks
		-- HeaderContext
		-- Content
		-- Notes
		-- Details
		-- Valore numerico della similarità del risultato in precentuale
		-- Nome del file da cui proviene il chunck
		-- Percorso o Url del file da cui proviene il chunk
	- Alla fine inserire i dati nella tabella SemanticCache per le successive ricerche

