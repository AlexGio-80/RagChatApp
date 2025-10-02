# IMPLEMENTAZIONI PER APPLICAZIONE RAG

## Implementazioni per utilizzo procedure RAG direttamente da SQL

### problema con recupero dati dopo prima installazione CLR
non ho capito... la dbo.SP_GetDataForLLM_Gemini (come quelle simili per gli altri provider) sono le procedure semplificate che voglio usare io in ultima istanza dai miei servizi esterni per recuperare i dati da passare poi all'LLM. Questa "struttura" deve rimanere valida sia che io faccia l'installazione del CLR, sia che io utilizzi i vettori su SQL 2025. Nel senso che la parte finale della catena di stored che è quella che restituisce il risultato deve variare a seconda del tipo di installazione che faccio, ma l'interfaccia verso l'esterno deve essere multi provider con stored dedicate, come avevamo strutturato il progetto in precedenza. Possiamo anche fare un'installazione nuova su un database pulito in cui posso importare un paio di documenti per vedere se i vari file di installazione e la struttura di recupero funziona. Se voglio procedere su questa strada di inizializzazione da zero di un nuovo database per importare documenti e poi eseguire le ricerche RAG da SQL, abbiamo già un documento con i passaggi da fare?

## miglioramento pacchetto di installazione

### Implementazione documentazione per prima installazione e pulizia della solution
procedi con l'opzione A e se trovi nel mentre documentazione duplicata, file obsoleti o non utili archiviali pure così puliamo anche un po' la soltion

### Correzioni e documentazione dopo prima installazione su database nuovo
ok, ora farò io un test manuale seguendo 00_SETUP_GUIDE.md, un paio di appunti: 1) la guida di installazione forse andrebbe messa in una posizione più consona nel progetto in modo che una volta che si fa
 il deploy per l'installazione in produzione sia più facile da trovare. 2) visto che sp_invoke_external_rest_endpoint non è disponibile nelle versioni di SQL Server precedenti alla 2025, forse andrebbe
indicato in documentazione questa cosa in modo che se non è comunque un problema per l'installazione, chi la fa non deve preoccuparsi di un warning; Se invece la mancanza di
sp_invoke_external_rest_endpoint è un problema per il funzionamento dell'interfaccia SQL di recupero dei chunck per gli LLM allora va risolto, perché come sappiamo SQL Server 2024 è in RC e per ora
sicuramente installeremo su versioni precedenti

### rimozione file di configurazione dei dev e correzione documentazione
sto guardando la cartella di compilazione e la documentazione e vedo che nella cartella di deploy c'è il file appsettings.Development.json e nella documentazione si fa riferimento al completamento dei parametri in quel file, ma credo che sia errato, quello dovrebbe essere il file che usiamo noi in programmazione quando lanciamo il progetto, magari in debug, per dei test, ma il deploy credo che dovrebbe contenere solo il file appsettings.json e la documentazione dovrebbe fare riferimento a quello, o sbaglio?

### miglioramento del deploy per avere nella cartella di compilazione tutto il necessario per l'installazione di un ambiente pulito
sono arrivato al passaggio della documentazione dell'inizializzazione del database con le migration, ma le indicazioni della 00_SETUP_GUIDE.md presuppongono di avere un ambiente di sviluppo, invece per la versione deploy io non ho l'ambiente di sviluppo, forse manca la creazione delle migration e la loro esecuzione fuori dall'ambiente di sviluppo. il progetto dovrebbe essere fatto in modo che una volta compilato e distribuito a chi deve fare l'installazione comprenda tutto il necessario per creare, aggiorare il database, e poi installare le procedure, il CLR o i VECTOR a seconda delle scelte di chi installa, ma comunque deve essere tutto disponibile

### miglioramento posizione documentazione per setup applicativo
ok perfetto, puoi correggere il file 00_SETUP_GUIDE.md in modo che nel setup della soluzione non sia indicato come installare usando l'ambiente di sviluppo, ma come fare l'installazione e la configurazione completa dell'applicazione e del database in ambiente di produzione. Se ritieni che il file 00_SETUP_GUIDE.md debba essere rilasciato con tutto il necessario per l'installazione in ambiene di produzione puoi anche spostarlo, altrimenti quando preparerò il pacchetto di installazione provvederò io a fornire il file 00_SETUP_GUIDE.md, la cartella di deploy del database e la cartella del servizio con le API. A proposito, l'applicativo server può essere messo a servizio vero? di questo non avevamo ancora parlato, ma immagino di sì

### configurazioni aggiuntive dell'applicazione
allora sto provando il funzionamento del pacchetto di installazione dell'applicazione e ho rilevato alcuni problemi. la porta su cui vengono esposte le API non è configurabile da appsettings.json, questo credo che sarebbe comodo in caso ci siano altre applicazioni che usano la porta di default usata che credo che sia la 5000

### correzione deploy per mancanza installazione CLR o VECTOR
Nel deploy per la produzione vedo che manca tutta la parte di installazione della versione delle procedure RAG con CLR o VECTOR da scegliere a seconda del database a disposizione. Andrebbe incluso tutto il necessario per dare a chi fa l'installazione la possibilità di scegliere, e poi ovviamente di installare, il necessario per il recupero via SQL dei chunks con logica RAG per i LLM.

### miglioramento documetazione per una più facile comprensione
altra cosa che vorrei controllare, visto che il pacchetto di installazione è fatto per essere distribuito, puoi controllare che nelle varie documentazioni dove vengono date indicazioni per l'installazione di stored o altri artefatti SQL siano indicati i parametri o le configurazioni da fare per installare sul database corretto? ad esempio nel 00_PRODUCTION_SETUP_GUIDE.md vedo questa indicazione [Pasted text #1 +21 lines], ma lasciandola così verrebbe lanciato con l'indicazione del database di default e non di quello su cui sto installando. oltretutto ci sono un sacco di file di documentazione specifici per le varie parti (stored, clr, etc) e questi vanno bene per la spiegazione del contenuto delle cartelle, di cosa fanno, e magari dei possibili test o problem solving specifici dei vari punti, ma tutti i passaggi da fare durante l'installazione, con le opzioni utilizzabili e il lancio dei vari ps1 o di qualsiasi altro strumento di installazione dovrebbero stare in un unico file, in modo che chi installa se non incontra problemi o non vuole fare test approfonditi o altro, deve aprire solo quel file e seguirne le istruzioni per completare un'installazione ex-novo dal principio alla fine

