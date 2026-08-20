# Progetto Quiz — regole per Claude Code

## Cosa stiamo costruendo
App di quiz a griglia stile game show. Le domande sono generate da un LLM
sugli argomenti scelti e salvate a database per il riuso; le partite si
giocano di persona, con un host che tiene il dispositivo e i giocatori che
rispondono a voce.

Due componenti, entrambi in ambito:
- `frontend/` — client Flutter per Android
- `backend/` — servizio Java Spring Boot con PostgreSQL

## Stato del progetto
Il **frontend è sostanzialmente completo**: design system, tessere, griglia,
punteggio a palette, placca della domanda, gestione errori e cache locale sono
implementati secondo il piano in `docs/`. Da qui in avanti il frontend si
**mantiene e si rifinisce**, non si riprogetta: se pensi che una sua parte vada
rifatta, dimmelo e argomenta, non procedere.

Il **backend è il fronte aperto**. Ha difetti noti, elencati sotto, e va
preparato per il deploy su Azure.

## Piattaforma
- **Android nativo, esclusivamente.** Niente web, niente iOS, niente desktop.
  Se una scelta va bene sul web ma è mediocre su Android, vince Android.
- Telefono in verticale è il caso principale, tablet in orizzontale è il caso
  importante: è un gioco di gruppo, spesso finisce su un tablet appoggiato al
  tavolo.
- minSdk 24, target e compile SDK all'ultima versione stabile.

## Contesto d'uso che deve guidare ogni scelta
- Si gioca in gruppo, con lo schermo visibile a più persone da lontano. I testi
  delle domande devono essere leggibili a un metro e mezzo.
- Le sessioni durano 20-40 minuti con lunghe pause di riflessione: lo schermo
  non deve mai spegnersi durante una partita.
- L'host sbaglia ad assegnare i punti. L'annulla deve essere sempre
  raggiungibile con un pollice, mai sepolto in un menu.
- La generazione IA richiede decine di secondi. L'attesa va progettata, non
  nascosta dietro uno spinner.

## Ambito e permessi sul backend

Il backend **si tocca**, ma con un processo più leggero di quello usato sul
frontend: niente piano di design, niente autocritica, niente fasi. Correzione
mirata, test che la copre, riga nel resoconto. Tre livelli:

**Procedi da solo** — bug fix, codici di stato HTTP sbagliati, campi aggiunti a
un DTO, validazioni mancanti, messaggi d'errore, logging, valori di
configurazione, test. Falli e riportali.

**Chiedi conferma prima** — tutto ciò che ha effetti che non si annullano
facilmente:
- migrazioni Flyway e qualunque modifica allo schema
- cambi alla forma di una risposta API già consumata dal frontend
- confini transazionali, sincrono che diventa asincrono, code o job
- dipendenze nuove nel `pom.xml`
- logica di deduplicazione, quota, o generazione delle domande
- qualunque risorsa Azure che costi credito

Quando chiedi, presentami il problema, l'opzione che consigli e cosa si rompe
scegliendo diversamente. Una sola opzione consigliata, non un ventaglio.

**Non farlo mai** — rimuovere o allentare il vincolo unico su
`(argomento_id, entita_canonica)` per far passare più domande: quel vincolo è
il cuore del progetto, e i problemi di banca esaurita si risolvono a monte.
Introdurre account, login o autenticazione utente.

### Difetti noti del backend, già diagnosticati

Sono emersi dall'audit del frontend e ora sono in ambito. Non lavorarci finché
non te lo chiedo esplicitamente, ma tienili presenti perché si intrecciano.

- La quota viene consumata **prima** della chiamata LLM: una rigenerazione che
  fallisce con 409 brucia comunque una delle generazioni giornaliere.
- La creazione del tabellone è sincrona e transazionale: se la quota si esaurisce
  a metà, l'intera transazione fa rollback e l'utente perde tutto dopo ~60s.
- Quando la deduplicazione non lascia abbastanza domande, viene scritta una cella
  segnaposto con testo `"Domanda da completare"` e risposta vuota.
- `CellaDto` non espone l'id della domanda, quindi l'endpoint di segnalazione è
  irraggiungibile dal client.
- `daily_double` esiste nello schema e nel modello Dart, ma il backend non lo
  imposta mai a `true`.
- `annulla`, `updateSquadra` e `removeSquadra` non verificano che la partita sia
  in corso, mentre il frontend lo impone: il client è più restrittivo del server.
- Il 409 "Nessuna domanda alternativa disponibile" e il 409 "Nessun evento da
  annullare" sono condizioni normali restituite come errori.

## Riferimenti al gioco originale

L'app **non è commercializzata** e per ora resta un progetto personale. Puoi
quindi usare liberamente il vocabolario e le meccaniche del format originale:
Daily Double, round finale con puntata, risposta formulata come domanda,
categorie, tabellone a valori crescenti. Non serve più girarci intorno.

Due precisazioni, però:

1. Questo **non è un mandato a ridipingere il frontend**. Il design system
   esistente è coerente e quasi finito; sostituirlo con blu e oro adesso
   significherebbe buttare via lavoro funzionante per un guadagno estetico
   discutibile. Se pensi valga la pena, proponimelo e decido io.
2. Il permesso vale finché il progetto resta privato. Se un giorno si pubblica,
   nomi e trade dress vanno rivisti — quindi tieni i riferimenti al format
   concentrati in stringhe localizzabili e in un file di configurazione, non
   sparsi nel codice.

Il primo effetto concreto è che `daily_double` può finalmente diventare una
funzione vera invece di un campo morto.

## Stack

**Frontend** — Riverpod per lo stato, go_router per la navigazione, dio per le
API, freezed e json_serializable per i modelli, Drift per la persistenza locale,
CustomPainter e AnimationController per il movimento, wakelock_plus durante la
partita.

**Backend** — Java 21, Spring Boot 3, Maven, Spring Data JPA, Flyway,
PostgreSQL 15+.

Se un pacchetto è in questo elenco ma non è usato da nessuna parte, o lo usi o
lo rimuovi: dipendenze installate e inerti sono peggio di dipendenze assenti.
Prima di aggiungerne di nuovi, chiedi.

## Deploy su Azure

Il backend girerà su Azure con una sottoscrizione **Azure for Students**: $100
di credito per 12 mesi, rinnovabile annualmente finché lo status di studente è
valido.

**Il vincolo che governa tutto:** quando il credito finisce, Azure non manda una
bolletta — **disabilita l'intera sottoscrizione**. Non solo la risorsa costosa:
tutto. Il credito non usato non si accumula da un mese all'altro, quindi il
budget reale è circa 8 dollari al mese, e sforare significa spegnere il progetto,
non pagare di più.

Regole che ne discendono:

- **Prima di proporre qualunque risorsa Azure, verifica il prezzo attuale** con
  una ricerca e dimmi il costo mensile stimato. Non fidarti della memoria: i
  piani gratuiti cambiano e i numeri che ricordi potrebbero essere vecchi.
- **Preferisci sempre lo scale-to-zero** al calcolo sempre acceso. L'app ha
  traffico a raffiche e lunghe pause: pagare un'istanza ferma è lo spreco più
  facile da evitare.
- **Un avviso di budget al 50% e all'80% è parte della definizione di "fatto"**
  per il deploy, non un extra da aggiungere dopo.
- **Valuta di lasciare PostgreSQL fuori da Azure.** Un database gestito è
  tipicamente la voce più cara di questa architettura, e un free tier permanente
  esterno può azzerarla lasciando il credito al solo calcolo. Se proponi Postgres
  su Azure, giustifica il costo.
- **Attenzione ai costi indiretti**: l'ingestione dei log verso Log Analytics si
  attiva spesso per default e consuma credito silenziosamente. Verificalo
  esplicitamente e dimmi cosa hai configurato.
- **Segreti fuori dal repository.** Chiave dell'LLM e credenziali del database
  vanno nelle impostazioni applicative del servizio o in un secret store, mai in
  `application.yml` versionato. Preferisci l'identità gestita alla password dove
  è supportata.
- **Cold start.** Un backend Spring Boot su un piano piccolo può metterci
  parecchio a rispondere dopo un periodo di inattività. Se la configurazione
  scelta ne soffre, dimmelo e proponi come mitigarlo: è la prima cosa che l'host
  nota aprendo l'app.
- **Timeout di richiesta.** La creazione del tabellone è sincrona e può durare
  un minuto o più. I servizi Azure hanno un limite di durata sulle richieste
  HTTP in ingresso: verifica quale si applica alla configurazione che proponi e
  confrontalo col tempo peggiore di generazione. Se il margine è stretto,
  segnalamelo prima del deploy, non dopo.
- Il `Dockerfile` è multi-stage con immagine finale su JRE slim, il pool di
  connessioni è dimensionato basso, ci sono health probe.

## Verifica

Frontend:

    cd frontend
    flutter analyze && flutter test

Backend:

    cd backend
    ./mvnw test

Prima di dichiarare conclusa una fase, l'APK debug deve costruirsi:

    cd frontend && flutter build apk --debug

**I comandi Flutter vanno eseguiti nel mio terminale, non nella tua shell**:
`flutter pub get` dal tuo ambiente corrompe il `package_config.json`, e
`frontend\build` è una junction che `flutter clean` rimuove. Quando serve un
gate, preparami il comando esatto e aspetta che ti riporti l'esito.

Per il backend puoi eseguire i test da solo, con PostgreSQL via
`docker compose up -d`.

## Qualità minima non negoziabile

Frontend:
- 60fps stabili sulla griglia e nelle transizioni, verificati in profile mode,
  non a occhio.
- `MediaQuery.disableAnimationsOf(context)` rispettato ovunque: se l'utente ha
  ridotto le animazioni, le durate vanno a zero e nulla si rompe.
- `textScaler` fino a 2.0 senza overflow. Il fit-to-box sceglie la dimensione
  quando c'è margine, ma il fattore di scala alza sia il pavimento sia il tetto:
  quando i due confliggono cede il layout, mai il testo.
- Contrasto AA su ogni testo, e nessuna informazione affidata alla sola tinta.
- Ogni elemento interattivo ha una `Semantics` label sensata.

Backend:
- Ogni correzione arriva con un test che fallisce prima e passa dopo.
- Nessun endpoint restituisce un errore per una condizione normale.
- Nessun messaggio d'errore del server arriva all'utente così com'è: il client
  decide come raccontarlo.

## Cosa NON fare
- NON riprogettare il frontend senza chiedermelo: è quasi finito.
- NON toccare lo schema del database o le API già consumate senza conferma.
- NON creare risorse Azure senza avermi detto prima quanto costano.
- NON introdurre login, account o registrazione. L'identità è solo un UUID
  anonimo in shared_preferences.
- NON usare `Lottie` con file scaricati a caso: licenza non verificabile.
- NON lasciare `TODO` o widget segnaposto nel codice consegnato.
