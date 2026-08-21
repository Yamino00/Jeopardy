> Devo portare il backend su Azure. Ho una sottoscrizione **Azure for Students**
> ($100 di credito, 12 mesi) e **non ho mai usato Azure**: non conosco la
> terminologia, il portale, né la CLI. Tratta ogni cosa come nuova per me, ma
> senza spiegarmi il cloud in generale: dimmi cosa fare e perché quel passo
> esiste.
>
> **Il vincolo che governa tutto:** se il credito finisce, Azure disabilita
> l'intera sottoscrizione, non solo la risorsa costosa. Il budget reale è circa
> 8 dollari al mese. Ogni scelta va giudicata prima sul costo, poi su tutto il
> resto.
>
> Lavora in cinque passi, in quest'ordine. Non scavalcarne nessuno.
>
> ### Passo 1 — Verifica i prezzi, non ricordarli
> I piani gratuiti e i prezzi Azure cambiano, e la tua memoria su questo è
> probabilmente vecchia. Cerca sul web i valori attuali dei servizi che stai per
> propormi, e dimmi la data delle fonti che hai usato. Se un numero non riesci a
> verificarlo, scrivilo come non verificato invece di darmelo per buono.
>
> ### Passo 2 — Audit di deployabilità
> Leggi `backend/` e dimmi **cosa oggi impedisce a questo servizio di girare su
> Azure**, come elenco di correzioni concrete con file e riga. Guarda in
> particolare:
> - come sono gestiti i segreti (chiave LLM, credenziali database) e cosa
>   succede se restano dove sono
> - la creazione del tabellone: è sincrona e può durare oltre un minuto. Verifica
>   quale limite di durata sulle richieste HTTP si applica al servizio che
>   proponi, e confrontalo col tempo peggiore di generazione
> - avvio a freddo della JVM dopo un periodo di inattività
> - dimensionamento del pool di connessioni rispetto ai limiti del database
> - health probe, gestione dello shutdown, migrazioni Flyway all'avvio
> - qualunque cosa che funzioni in locale perché c'è `docker compose` e non
>   esisterà in produzione
>
> Ordina per gravità: cosa **impedisce** il deploy, cosa lo rende **fragile**,
> cosa è solo **da migliorare**. Le correzioni che seguono le regole di
> `CLAUDE.md` puoi farle; per quelle che richiedono conferma, chiedi.
>
> ### Passo 3 — Proponi l'architettura, poi fermati
> Una sola architettura consigliata, non un ventaglio. Per ciascun componente:
> a cosa serve, quanto costa al mese secondo i prezzi verificati al Passo 1, e
> cosa succede quando è inattivo.
>
> Valuta esplicitamente se convenga tenere PostgreSQL **fuori** da Azure su un
> free tier permanente: il database gestito è di solito la voce più cara, e
> spostarlo può liberare quasi tutto il credito per il calcolo. Se proponi
> Postgres su Azure, giustifica la spesa.
>
> Dammi il totale mensile stimato e in quanti mesi esaurisce i $100. Poi
> **fermati e aspetta la mia approvazione.**
>
> ### Passo 4 — Fai tutto quello che puoi fare da solo
> Dopo l'approvazione, prima di scrivere la guida: tutto il lavoro che vive nel
> repository lo fai tu adesso, non me lo metti come compito.
>
> - `Dockerfile` multi-stage, immagine finale su JRE slim
> - profilo `application-prod.yml` con configurazione da variabili d'ambiente
> - endpoint di health e readiness
> - **infrastruttura come codice** (Bicep o Terraform): è la differenza fra
>   quaranta click nel portale che non so rifare e un comando che posso
>   rieseguire. Preferiscila al portale ovunque sia possibile
> - workflow GitHub Actions per build e deploy
> - script di verifica che posso lanciare per capire se il deploy ha funzionato
> - `.gitignore` e controllo che nessun segreto sia già finito nella cronologia
>   git
>
> Controlla quali strumenti Azure hai davvero a disposizione — MCP, CLI, altro —
> e dimmi cosa hai trovato e cosa ci puoi fare. Non dare per scontato di averli.
>
> **Non creare mai risorse che consumano credito.** Nemmeno se hai le
> credenziali per farlo. Prepara i comandi, li eseguo io.
>
> ### Passo 5 — Scrivi la guida
> In `docs/DEPLOY_AZURE.md`. È scritta per me, che non so niente di Azure, e
> deve funzionare anche fra tre mesi quando avrò dimenticato tutto.
>
> Regole di forma, non negoziabili:
>
> - **Comandi, non click.** Il portale Azure cambia interfaccia in
>   continuazione; i comandi `az` no. Usa il portale solo dove è l'unica strada,
>   e in quel caso descrivi il percorso per nome esatto delle voci.
> - **Ogni passo ha quattro parti**: cosa fa, il comando esatto, **cosa devo
>   vedere se ha funzionato**, e cosa fare se invece fallisce con l'errore più
>   probabile.
> - **Nessun passo implicito.** "Configura la rete" non è un'istruzione. O è un
>   comando che posso incollare, o non esiste.
> - **I segnaposto da sostituire in MAIUSCOLO** fra parentesi angolari, con una
>   tabella all'inizio dei valori che devo scegliere una volta sola.
> - **Ogni passo dichiara se costa**: gratuito, consuma credito, o una tantum.
>
> Struttura obbligatoria:
>
> 1. **Prima di iniziare** — cosa devo avere e fare io prima del primo comando:
>    account, verifica dello status studente, strumenti da installare sul mio
>    Windows, come controllo di essere autenticato.
> 2. **Setup una tantum** — le risorse create la prima volta e mai più.
> 3. **Deploy** — la procedura ripetibile a ogni rilascio, che deve stare in
>    pochi comandi.
> 4. **Verifica** — come controllo che l'app risponda davvero, con l'app Flutter
>    che punta al backend vero.
> 5. **Avvisi di budget** — al 50% e all'80%. Questo passo non è opzionale e non
>    va in fondo: mettilo dove non posso saltarlo.
> 6. **Cosa fare quando qualcosa non va** — i tre o quattro fallimenti più
>    probabili, riconoscibili dal messaggio d'errore, con il rimedio.
> 7. **Come spengo tutto** — la procedura per cancellare ogni risorsa e fermare
>    il consumo di credito. Deve essere una sezione vera, non una nota: è la
>    cosa che mi serve di più il giorno in cui qualcosa va storto.
>
> E un secondo documento, `docs/AZURE_INTERVENTI.md`: solo le cose che
> richiedono me, in tabella, ordinate per quando servono, con colonne "cosa",
> "perché", "quanto tempo". Se una di queste blocca tutto il resto finché non la
> faccio, scrivilo esplicitamente.
>
> Non abbellire. Se un passaggio è fragile o non l'hai potuto verificare,
> dichiaralo lì dove sta.
