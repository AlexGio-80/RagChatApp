# IMPLEMENTAZIONI PER APPLICAZIONE RAG

## Implementazioni per utilizzo procedure RAG direttamente da SQL

### problema con recupero dati dopo prima installazione CLR
non ho capito... la dbo.SP_GetDataForLLM_Gemini (come quelle simili per gli altri provider) sono le procedure semplificate che voglio usare io in ultima istanza dai miei servizi esterni per recuperare i dati da passare poi all'LLM. Questa "struttura" deve rimanere valida sia che io faccia l'installazione del CLR, sia che io utilizzi i vettori su SQL 2025. Nel senso che la parte finale della catena di stored che è quella che restituisce il risultato deve variare a seconda del tipo di installazione che faccio, ma l'interfaccia verso l'esterno deve essere multi provider con stored dedicate, come avevamo strutturato il progetto in precedenza. Possiamo anche fare un'installazione nuova su un database pulito in cui posso importare un paio di documenti per vedere se i vari file di installazione e la struttura di recupero funziona. Se voglio procedere su questa strada di inizializzazione da zero di un nuovo database per importare documenti e poi eseguire le ricerche RAG da SQL, abbiamo già un documento con i passaggi da fare?

### Implementazione documentazione per prima installazione e pulizia della solution
procedi con l'opzione A e se trovi nel mentre documentazione duplicata, file obsoleti o non utili archiviali pure così puliamo anche un po' la soltion