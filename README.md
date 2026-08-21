# Quiz Grid

Un gioco a quiz a griglia da giocare **di persona**, in gruppo, attorno a un
tavolo. Un telefono o un tablet fa da tabellone, una persona conduce, gli altri
rispondono a voce.

Le domande le scrive un modello linguistico sugli argomenti che scegli tu, e
finiscono in una banca condivisa: la seconda partita su «Storia romana» riusa
quello che ha prodotto la prima, e non costa niente.

> Progetto personale, non commerciale. Le meccaniche si ispirano al formato
> televisivo classico dei quiz a griglia; nomi e aspetto non sono definitivi.

---

## Com'è fatto

**Android, esclusivamente.** Niente web, niente iOS. Quando una scelta va bene
sul web ed è mediocre su Android, vince Android.

Il contesto d'uso ha deciso quasi tutto:

| Vincolo reale | Conseguenza nel codice |
|---|---|
| Lo schermo si legge da un metro e mezzo, da più persone | Testi grandi, contrasto AA, niente informazione affidata alla sola tinta |
| Le partite durano 20-40 minuti con lunghe pause | Lo schermo non si spegne mai durante una partita (`wakelock_plus`) |
| Chi conduce sbaglia ad assegnare i punti | L'annulla è sempre a portata di pollice, mai in un menu |
| La generazione IA richiede decine di secondi | L'attesa è progettata, non nascosta dietro uno spinner |
| Il tablet finisce appoggiato al tavolo | Verticale e orizzontale sono entrambi casi primari |

## Cosa fa

- **Crea un tabellone** da una lista di argomenti. Categorie in colonna, valori
  crescenti in riga, una cella *Daily Double* per tabellone.
- **Genera le domande** con Gemini o Groq, alternandoli: creare un tabellone
  fa molte chiamate di fila, e un solo free tier non regge.
- **Non ripete le domande.** Un vincolo unico su `(argomento, entità)` più una
  deduplicazione a tre livelli — entità canonica, hash del testo normalizzato,
  similarità trigram — impedisce che due domande sullo stesso soggetto entrino
  nella banca.
- **Conduce la partita**: squadre, punteggi, turni, annulla di qualunque
  azione, podio finale.
- **Funziona anche se cade la rete.** Le giocate si accodano in locale e
  ripartono quando torna, il tabellone resta leggibile da una copia salvata.
- **Segnala una domanda sbagliata**: alla terza segnalazione da dispositivi
  diversi smette di essere pescata per i tabelloni nuovi.

Nessun account, nessuna registrazione, nessuna password. L'identità è un UUID
anonimo generato sul dispositivo.

## Architettura

```
App Android (Flutter)
        │  HTTPS
        ▼
Azure Container Apps · 0,5 vCPU / 1 GiB · repliche 0→2
        │
        ├──► PostgreSQL (Neon, piano gratuito)
        └──► Gemini / Groq
```

**Costo di esercizio: $0,00 al mese.** Non è un modo di dire: il servizio scende
a zero istanze quando nessuno gioca, e la quota gratuita mensile di Container
Apps copre 100 ore di servizio acceso a questa taglia. Il database sta fuori da
Azure perché un Postgres gestito costerebbe più di tutto il resto messo insieme.

Il prezzo di quella scelta è l'avvio a freddo: **31 secondi misurati** sulla
prima richiesta dopo una pausa. L'app lo maschera bussando al server appena si
apre, così si scalda mentre scegli gli argomenti.

## Stack

**Frontend** — Flutter · Riverpod · go_router · dio · `CustomPainter` e
`AnimationController` per il movimento · wakelock_plus

**Backend** — Java 21 · Spring Boot 3.3 · Spring Data JPA · Flyway ·
PostgreSQL 16 · Maven

**Infrastruttura** — Docker multi-stage con AppCDS · Bicep · GitHub Actions con
autenticazione OIDC · immagine su ghcr.io

## Struttura

```
backend/     API Spring Boot           (85 file Java, 10 classi di test)
frontend/    App Flutter               (40 file Dart, 12 file di test)
infra/       Bicep: ambiente, servizio, avvisi di budget
scripts/     Verifica del deploy, seed della banca domande
docs/        Guide operative e decisioni architetturali
```

## Provare in locale

Serve Docker, Java 21 e Flutter.

```bash
docker compose up -d
```

```bash
cd backend && mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

```bash
cd frontend && flutter run
```

Senza chiavi LLM il resto funziona: la generazione risponde 503 e tutto il
resto dell'app continua a girare. Per averle, copia `.env.example` in `.env` —
sono gratuite, da [Google AI Studio](https://aistudio.google.com/apikey) e
[Groq](https://console.groq.com/keys).

Per giocare senza chiamare l'IA c'è una banca già pronta:
`scripts/seed-banca.sql`.

## Verifica

```bash
cd backend && ./mvnw test
```

```bash
cd frontend && flutter analyze && flutter test
```

## Documentazione

| Documento | Quando serve |
|---|---|
| [docs/COMANDI.md](docs/COMANDI.md) | **Tutti i giorni**: ogni comando che serve, con una riga che dice cosa fa |
| [docs/DEPLOY_AZURE.md](docs/DEPLOY_AZURE.md) | Il primo deploy, da zero, comando per comando |
| [docs/AZURE_INTERVENTI.md](docs/AZURE_INTERVENTI.md) | Solo i passi che richiedono una persona |
| [docs/adr/](docs/adr/) | Perché certe scelte sono state fatte così |

## Scelte che vale la pena spiegare

**Lo schema del database si tocca solo con Flyway.** `ddl-auto: validate`:
l'applicazione si rifiuta di partire se lo schema non è quello che si aspetta,
invece di modificarlo da sé.

**Nessun errore per una condizione normale.** Annullare quando non c'è niente da
annullare, o rigenerare quando l'argomento è esaurito, rispondono `200` con un
campo che lo dice. Erano `409`, e arrivavano a chi giocava come allarmi rossi.

**Nessun messaggio del server arriva all'utente così com'è.** Un *Problem
Detail* è scritto per chi sviluppa; come raccontare un guasto a chi sta giocando
lo decide il client.

**Le celle non restano vuote.** Se la deduplicazione non lascia abbastanza
domande, il backend ripiega sulla banca allentando i vincoli un gradino per
volta. Solo se non c'è davvero niente rifiuta di creare il tabellone: una
griglia con i buchi si scopre a partita iniziata, ed è peggio di nessuna
griglia.

**La creazione ha un tetto di tempo.** 150 secondi lato server, sotto i 180 del
client e i 240 del proxy di Azure. In quest'ordine risponde sempre il server,
con un errore comprensibile, invece che il proxy tagliando la connessione.
