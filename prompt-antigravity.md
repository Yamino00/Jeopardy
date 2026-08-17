# Prompt per Antigravity — App Quiz stile Jeopardy con generazione IA

## Come usarlo

1. Crea la cartella del progetto, metti dentro `schema.sql` e `AGENTS.md` (contenuto sotto).
2. Apri la cartella in Antigravity.
3. Incolla il **Prompt 0**. Aspetta il piano di implementazione, commentalo, approvalo.
4. Solo dopo, procedi fase per fase. Non incollare tutti i prompt insieme.
5. Nei prompt usa `@schema.sql` per agganciare il file: l'overlay dei path riduce le ricerche a vuoto dell'agente.

---

# PARTE 1 — `AGENTS.md`

Salva questo file nella root del progetto. Antigravity lo legge prima di ogni task.

```markdown
# Regole di progetto

## Cosa stiamo costruendo
App per creare e giocare quiz a griglia stile Jeopardy, dove le domande
sono generate da un LLM sugli argomenti scelti dall'utente e salvate a
database per essere riusate in partite successive.

## Vincolo dominante: budget vicino a zero
Ogni scelta tecnica va valutata prima di tutto sul costo di esercizio.
- Solo servizi con free tier permanente. Niente che richieda carta di credito.
- Ogni chiamata all'LLM va evitata se la risposta è già in database.
- Niente componenti sempre accesi oltre al backend (no broker, no cache
  esterna, no worker separati). Se serve uno scheduler, usa @Scheduled.
- Prima di introdurre una dipendenza nuova, chiedi conferma.

## Stack (non negoziabile)
- Backend: Java 21, Spring Boot 3.x, Maven
- Database: PostgreSQL 15+, migrazioni con Flyway
- Frontend: Flutter (Dart 3), state management con Riverpod
- Monorepo: `/backend` e `/app`

## Cosa NON fare
- NON creare tabelle o entità utente, login, registrazione, password, JWT.
  L'app è completamente anonima. L'unica identità è un UUID generato dal
  client e inviato nell'header `X-Client-Id`.
- NON introdurre WebSocket o partite multi-device. L'host tiene il
  tabellone su un solo schermo.
- NON aggiungere Spring Security.
- NON modificare lo schema in `schema.sql` senza spiegare prima perché.
- NON usare `unaccent()` dentro colonne generate o indici funzionali:
  in PostgreSQL è STABLE, non IMMUTABLE, e la migrazione fallisce.

## Convenzioni
- Nomi di tabelle, colonne ed entità in italiano, come da `schema.sql`.
- Nomi di classi, metodi e variabili Java in inglese.
- Package base: `it.quiz.jeopardy`
- Package per contesto, non per layer:
  `banca`, `tabellone`, `partita`, `ia`, `comune`
- DTO separati dalle entità JPA. Le entità non escono mai dal controller.
- Ogni endpoint valida l'input con Bean Validation.
- Errori gestiti con @RestControllerAdvice, risposta in formato Problem Detail.

## Verifica
Dopo ogni modifica al backend esegui:
    cd backend && ./mvnw test
Dopo ogni modifica al frontend esegui:
    cd app && flutter analyze && flutter test
Non considerare un task concluso finché questi comandi non passano.

## Test
- Unit test per la logica di normalizzazione e di deduplicazione: sono il
  cuore del progetto e devono avere copertura alta.
- Integration test con Testcontainers su PostgreSQL reale, non H2:
  i vincoli unici parziali e gli indici GIN non esistono su H2.
- Il client LLM va dietro un'interfaccia, con implementazione fake nei test.
  Nessun test deve fare chiamate di rete reali.
```

---

# PARTE 2 — Prompt 0: esplorazione e piano

> Analizza `@schema.sql` e `@AGENTS.md`. Non scrivere ancora codice.
>
> Sto costruendo un'app per creare e giocare quiz a griglia stile
> JeopardyLabs, dove le domande vengono generate da un LLM sugli argomenti
> scelti e poi salvate a database per il riuso.
>
> Il modello di dominio ha tre livelli distinti:
>
> 1. **Banca domande** — persistente e condivisa fra tutti gli utenti.
>    È l'unico asset che si accumula nel tempo. Deduplicata.
> 2. **Tabellone** — l'artefatto salvato e riusabile: 5-6 categorie per
>    5 righe. Ha un codice pubblico per giocare e un codice segreto per
>    modificare. Nessun proprietario, solo l'UUID anonimo del creatore.
> 3. **Partita e squadre** — effimere. Una partita è un'istanza di gioco
>    di un tabellone; le squadre sono figlie della partita in CASCADE,
>    hanno solo nome, colore e punteggio, e muoiono con essa. Nessun
>    utente associato, nome libero anche duplicato, aggiungibili e
>    rimovibili a metà partita.
>
> Il problema centrale è **evitare domande duplicate**. La strategia già
> decisa: l'LLM restituisce anche una `entita_canonica`, cioè la risposta
> normalizzata (minuscola, senza accenti, senza articoli, senza
> parentetiche). Il vincolo unico `(argomento_id, entita_canonica)` in
> `schema.sql` rende impossibile inserire due domande con la stessa
> risposta sullo stesso argomento. Prima di chiamare l'LLM si legge la
> banca: se ci sono già abbastanza domande adatte, la chiamata non parte.
> Quando parte, il prompt include la blocklist delle entità già presenti.
>
> Scrivi un piano di implementazione che copra:
> - struttura del monorepo e file di build
> - mappatura tabelle -> entità JPA, segnalando dove lo schema mi
>   costringerebbe a soluzioni scomode con JPA
> - elenco degli endpoint REST con verbo, path, request e response
> - dove vive il calcolo di `entita_canonica` e `hash_testo`
> - come strutturi la cascata di deduplicazione
> - suddivisione in fasi indipendenti e verificabili
>
> Segnalami esplicitamente ogni punto dove lo schema o le mie decisioni
> ti sembrano sbagliati o incompleti, prima di iniziare.

---

# PARTE 3 — Prompt per fase

Da usare uno alla volta, dopo aver approvato il piano.

## Fase 1 — Scaffolding e schema

> Crea il monorepo con `/backend` (Spring Boot 3, Java 21, Maven) e
> `/app` (Flutter).
>
> Backend: dipendenze Web, Data JPA, Validation, Flyway, PostgreSQL
> driver, Testcontainers, Lombok.
>
> Converti `@schema.sql` in migrazioni Flyway in
> `src/main/resources/db/migration`, separando: estensioni, banca
> domande, tabelloni, partite, controllo costi.
>
> Aggiungi un `docker-compose.yml` con solo PostgreSQL per lo sviluppo
> locale, e un endpoint `GET /api/salute` che verifica la connessione.
>
> Scrivi un integration test con Testcontainers che avvia il contesto,
> applica tutte le migrazioni e verifica che il vincolo unico su
> `(argomento_id, entita_canonica)` respinga davvero un doppione.
> Esegui `./mvnw test` e mostrami l'esito.

## Fase 2 — Normalizzazione e deduplicazione

> Implementa nel package `comune` la classe `Normalizer`, con un metodo
> puro e deterministico che trasforma una risposta nella sua
> `entita_canonica`:
> minuscolo -> rimozione diacritici (Normalizer.Form.NFD) -> rimozione
> contenuto fra parentesi -> rimozione articoli italiani iniziali
> (il, lo, la, i, gli, le, l', un, uno, una) -> rimozione punteggiatura
> -> collasso degli spazi -> trim.
> Aggiungi un metodo per lo SHA-256 del testo domanda normalizzato.
>
> Scrivi i test PRIMA dell'implementazione. Casi obbligatori:
> "Giulio Cesare" e "giulio cesare" -> stessa entità;
> "Il Colosseo" e "Colosseo" -> stessa entità;
> "Perù" e "Peru" -> stessa entità;
> "Napoleone (imperatore)" e "Napoleone" -> stessa entità;
> "44 a.C." e "44 aC" -> stessa entità;
> "Giulio Cesare" e "Augusto" -> entità diverse.
>
> Poi implementa nel package `banca` il `DeduplicationService`, come
> cascata che si ferma al primo scarto:
> 1. entità canonica già presente per quell'argomento (query indicizzata)
> 2. hash del testo già presente (qualunque argomento)
> 3. similarità trigram > 0.6 sul testo, ristretta allo stesso argomento
>
> Il servizio riceve una lista di domande candidate e restituisce
> accettate e scartate con il motivo. Deve deduplicare anche all'interno
> del batch, non solo contro il database.
>
> Esegui i test e mostrami la copertura di questi due componenti.

## Fase 3 — Pipeline di generazione IA

> Implementa il package `ia`.
>
> Definisci l'interfaccia `QuestionGenerator` con un'unica implementazione
> reale basata su Gemini via API REST (free tier), configurabile da
> `application.yml`, più una implementazione fake per i test.
>
> Il servizio `GenerationService` esegue in ordine:
> 1. Legge la vista `copertura` e individua le celle
>    (sotto_argomento, difficoltà) sotto soglia.
> 2. Conta quante domande adatte e non ancora usate da questo client
>    esistono già. Se bastano, NON chiama l'LLM: ritorna quelle.
> 3. Se mancano N domande, costruisce il prompt per una singola cella
>    (mai "generami domande su X" generico), includendo la blocklist
>    delle entita_canonica già presenti per quella cella.
> 4. Chiede N+2 domande in una sola chiamata, mai retry su scarto.
> 5. Fa il parsing dello schema JSON stretto e valida ogni campo.
> 6. Passa i candidati al DeduplicationService.
> 7. Inserisce le accettate, registra la riga in `generazione` con token
>    e costo stimato, scarta il resto.
>
> Il contratto JSON che l'LLM deve rispettare:
> ```json
> {"domande":[{"testo":"...","risposta":"...","entita_canonica":"...",
>   "sotto_argomento":"...","difficolta":3}]}
> ```
> Ricalcola comunque `entita_canonica` lato Java con il Normalizer: non
> fidarti di quella restituita dal modello, usala solo come confronto e
> logga le divergenze.
>
> Implementa in `comune` un filtro sull'header `X-Client-Id` e un
> `QuotaService` che blocca il client oltre N generazioni giornaliere
> (default 20, configurabile), rispondendo 429.
>
> Test con il generator fake: verifica che con banca già popolata la
> chiamata non parta, che i duplicati nel batch vengano scartati, e che
> superata la quota si ottenga 429.

## Fase 4 — Tabelloni

> Implementa il package `tabellone`.
>
> Endpoint:
> - `POST /api/tabelloni` — riceve titolo, lista argomenti, numero righe,
>   punti base. Genera codice pubblico (6 caratteri, alfabeto senza
>   caratteri ambigui) e codice modifica (12 caratteri). Per ogni
>   categoria richiama la generazione e popola le celle. Ritorna il
>   tabellone completo con entrambi i codici.
> - `GET /api/tabelloni/{codicePubblico}` — tabellone per il gioco.
> - `PUT /api/tabelloni/{codicePubblico}` — richiede header
>   `X-Codice-Modifica`, altrimenti 403. Permette di modificare titolo,
>   nomi categoria e testo/risposta delle celle. Le modifiche al testo
>   vanno negli override della cella, MAI sulla domanda condivisa.
> - `POST /api/tabelloni/{codicePubblico}/celle/{id}/rigenera` —
>   sostituisce una singola cella con un'altra domanda.
> - `GET /api/tabelloni?client=...` — tabelloni creati da questo client.
> - `POST /api/domande/{id}/segnalazioni` — segnala una domanda; oltre 3
>   segnalazioni lo stato passa a 'segnalata'.
>
> La selezione delle domande per le celle deve escludere quelle già usate
> in tabelloni dello stesso client, ordinare per `volte_usata` crescente,
> e incrementare `volte_usata`.
>
> Test: creazione completa, tabellone senza celle duplicate, rifiuto con
> codice modifica errato, override che non altera la domanda in banca.

## Fase 5 — Partite e squadre

> Implementa il package `partita`. Questa parte deve essere il più
> permissiva possibile: nessun account, nessun vincolo di unicità sui
> nomi squadra, tutto modificabile in corsa.
>
> Endpoint:
> - `POST /api/tabelloni/{codicePubblico}/partite` — avvia una partita.
> - `GET /api/partite/{id}` — stato completo: squadre, punteggi, celle
>   già giocate, turno corrente.
> - `POST /api/partite/{id}/squadre` — aggiunge una squadra, anche a
>   partita iniziata.
> - `PATCH /api/partite/{id}/squadre/{sid}` — rinomina, cambia colore,
>   corregge il punteggio a mano.
> - `DELETE /api/partite/{id}/squadre/{sid}` — soft delete su `attiva`,
>   così lo storico eventi resta coerente.
> - `POST /api/partite/{id}/celle/{cid}` — gioca una cella: squadra,
>   esito, delta punti. Scrive su `cella_giocata` e su `evento_partita`.
> - `POST /api/partite/{id}/annulla` — annulla l'ultimo evento non
>   annullato, ricalcolando il punteggio dal log.
> - `POST /api/partite/{id}/concludi`
>
> Il punteggio va sempre derivabile dalla somma dei delta degli eventi
> non annullati: scrivi un test che lo verifica dopo una sequenza mista
> di assegnazioni, correzioni manuali e annullamenti.
>
> Aggiungi un job `@Scheduled` giornaliero che cancella le partite oltre
> `scade_il` non concluse.

## Fase 6 — App Flutter

> Implementa il client Flutter in `/app`, con Riverpod e go_router.
>
> Al primo avvio genera un UUID v4, salvalo in shared_preferences e
> inviarlo in `X-Client-Id` su ogni richiesta tramite interceptor Dio.
>
> Schermate:
> 1. **Home** — crea nuovo tabellone, entra con codice, i miei tabelloni.
> 2. **Creazione** — titolo, aggiunta argomenti con chip, numero
>    categorie e righe. Durante la generazione mostra avanzamento per
>    categoria, non uno spinner unico: l'attesa è lunga e va spiegata.
> 3. **Tabellone** — griglia con valori, tap apre la cella a tutto
>    schermo con la domanda; secondo tap rivela la risposta; poi i
>    pulsanti per assegnare punti a una squadra o passare.
> 4. **Barra squadre** — sempre visibile durante la partita, punteggi
>    modificabili con tap lungo, pulsante per aggiungere una squadra in
>    qualsiasi momento, pulsante annulla sempre raggiungibile.
> 5. **Riepilogo** — classifica finale, rigioca, condividi codice.
>
> La griglia deve funzionare sia su telefono in verticale che su tablet
> in orizzontale: su schermo stretto le categorie scorrono
> orizzontalmente invece di comprimersi.
>
> Usa il browser agent per verificare il flusso completo in Flutter web
> (crea tabellone, gioca tre celle, annulla, concludi) e allega gli
> screenshot al walkthrough.

## Fase 7 — Deploy

> Prepara il deploy su servizi con free tier permanente:
> PostgreSQL su Neon o Supabase, backend containerizzato.
>
> Produci:
> - `Dockerfile` multi-stage per il backend, immagine finale su JRE slim
> - profilo `application-prod.yml` con configurazione da variabili
>   d'ambiente, pool di connessioni ridotto (max 5: i free tier hanno
>   limiti bassi di connessioni)
> - build Flutter web con output statico
> - `README.md` con i passi di deploy e le variabili richieste
> - una GitHub Action che esegue i test a ogni push
>
> Documenta nel README il costo mensile stimato per fascia di utilizzo e
> quale limite del free tier si raggiunge per primo.
```
