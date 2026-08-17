# Guida all'avvio e al test del frontend Flutter

L'app in `/frontend` è il client dell'API descritta in
[guida-test-backend.md](guida-test-backend.md). Comandi per **PowerShell**.

## Prerequisiti

- **Flutter SDK 3.47** in `C:\Apps\flutter` (già installato su questa macchina).
  Non è nel PATH di sistema: aggiungilo alla sessione corrente con

  ```bash
  $env:PATH = "C:\Apps\flutter\bin;$env:PATH"
  ```

  Per renderlo permanente: Impostazioni → Variabili d'ambiente → `Path` →
  aggiungi `C:\Apps\flutter\bin`.
- **Backend in esecuzione**: `docker compose up -d` dalla root del progetto.
- **Banca popolata**, così la creazione non dipende dall'IA:

  ```bash
  Get-Content scripts\seed-banca.sql -Raw | docker exec -i jeopardy-postgres psql -U jeopardy -d jeopardy
  ```

## 1. Avviare l'app

Su Chrome (consigliato: hot reload e DevTools):

```bash
cd frontend; flutter run -d chrome
```

Come server web, per aprirla nel browser che preferisci su
<http://localhost:5173>:

```bash
cd frontend; flutter run -d web-server --web-port=5173
```

Se il backend non è su `localhost:8080` (deploy, altra porta), passa l'URL a
build time — non c'è nulla di hardcodato:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://api.tuodominio.it
```

## 2. Il giro completo dall'interfaccia

1. **Home** — tre azioni: creare un tabellone, entrare con un codice a 6
   caratteri, riaprire i propri tabelloni (la lista è per client: l'UUID
   anonimo salvato in `shared_preferences`).
2. **Creazione** — titolo, argomenti come chip (max 6), righe e punti base.
   Premendo *Genera*, durante l'attesa vedi l'avanzamento **categoria per
   categoria**, non uno spinner unico.
3. **Tabellone** — griglia con i valori; in alto il banner con il **codice di
   modifica**, mostrato una volta sola: copialo. *Avvia partita* apre la
   finestra delle squadre.
4. **Partita** — tap su una cella: si apre a tutto schermo con la domanda,
   *Mostra risposta* la rivela, poi assegni i punti a una squadra (✓ somma,
   ✗ sottrae) oppure passi. In basso la **barra squadre** è sempre visibile:
   punteggi, tap lungo su una squadra per rinominarla/correggere il punteggio/
   rimuoverla, pulsante per aggiungerne una in corsa e **annulla** sempre
   raggiungibile.
5. **Riepilogo** — dopo *Concludi*: classifica finale, *Rigioca* (nuova partita
   con le stesse squadre) e condivisione del codice.

Cose che vale la pena verificare a mano:

- una cella già giocata resta segnata e non è più cliccabile;
- **annulla** riporta il punteggio E rende la cella di nuovo giocabile;
- su finestra stretta (< ~150px per categoria) le categorie **scorrono in
  orizzontale** invece di comprimersi: rimpicciolisci la finestra o usa la
  device toolbar di Chrome in modalità telefono.

## 3. Test automatici

Suite di default (unit sui modelli + widget test, nessuna rete):

```bash
cd frontend; flutter analyze; flutter test
```

Test **end-to-end contro il backend reale** — crea un tabellone, gioca tre
celle, annulla, conclude, usando gli stessi repository della UI. Richiede lo
stack Docker acceso e la banca seedata:

```bash
cd frontend; flutter test --tags e2e --run-skipped
```

## 4. Build di produzione

```bash
cd frontend; flutter build web --release --dart-define=API_BASE_URL=https://api.tuodominio.it
```

L'output statico finisce in `frontend/build/web`, pubblicabile su qualunque
hosting statico con free tier.

## 5. Troubleshooting

- **La pagina resta bianca / "Internal Server Error"** → manca il supporto web:
  `cd frontend; flutter create . --platforms=web`.
- **Errori CORS in console** → il backend deve essere aggiornato: le origin
  ammesse sono in `app.cors.allowed-origins` (default `*`). Il preflight
  `OPTIONS` è escluso dal controllo di `X-Client-Id`, quindi se vedi ancora
  errori CORS ricostruisci il container: `docker compose up -d --build`.
- **"Errore di rete: il server non risponde"** → backend spento o
  `API_BASE_URL` sbagliato; controlla `curl.exe http://localhost:8080/api/salute`.
- **Creazione lenta o 503** → senza `GEMINI_API_KEY` servono domande in banca:
  esegui il seed. Con la chiave, la prima generazione per categoria richiede
  qualche secondo.
- **`flutter` non riconosciuto** → non hai impostato il PATH della sessione
  (vedi Prerequisiti).
