# Guida al test del backend (Docker)

Guida passo passo per avviare PostgreSQL e il backend **entrambi dockerizzati**
e testare a fondo tutte le funzionalità. I comandi sono per **PowerShell** su
Windows.

## Prerequisiti

- Docker Desktop in esecuzione
- (Facoltativo) una chiave API Gemini gratuita da <https://aistudio.google.com/apikey>:
  serve solo per la **generazione IA** delle domande. Senza chiave tutto il resto
  funziona e la generazione risponde `503` con un messaggio chiaro; puoi comunque
  testare l'intera app usando lo script di seed (vedi sotto).

## Architettura

| Container | Immagine | Porta | Note |
|---|---|---|---|
| `jeopardy-postgres` | postgres:16 | 5432 | dati nel volume `postgres_data` |
| `jeopardy-backend` | build multi-stage da `backend/Dockerfile` | 8080 | JRE 21 alpine, utente non-root |

Al primo avvio il backend applica da solo le 6 migrazioni Flyway.

## 1. Avvio dello stack

```bash
docker compose up -d --build
```

Con la chiave Gemini: copia `.env.example` in `.env` e incolla lì la chiave
(il file è in `.gitignore`, non finisce mai nel repository). Docker Compose lo
legge da solo:

```bash
Copy-Item .env.example .env
```

Poi apri `.env`, valorizza `GEMINI_API_KEY=...` e avvia normalmente con
`docker compose up -d --build`. Per cambiare modello (i modelli Gemini vengono
dismessi nel tempo) agisci su `app.ia.gemini.modello` in
`backend/src/main/resources/application.yml`. Per vedere quali sono attivi
adesso per la tua chiave:

```bash
curl.exe -s -H "x-goog-api-key: $env:GEMINI_API_KEY" https://generativelanguage.googleapis.com/v1beta/models | Select-String '"name": "models/gemini'
```

Verifica che il backend risponda (riprova dopo qualche secondo se parte adesso):

```bash
curl.exe http://localhost:8080/api/salute
```

Atteso: `{"database":"connesso","stato":"ok"}`.

## 2. Prepara la sessione di test

Ogni richiesta (tranne `/api/salute`) richiede l'header `X-Client-Id` con un
UUID: è l'identità anonima del client. Incolla questo blocco nella shell — crea
l'ID e una funzione `Api` che mostra sempre status HTTP e corpo della risposta,
anche per gli errori:

```bash
$CLIENT_ID = [guid]::NewGuid().ToString()
function Api {
  param([string]$Method, [string]$Path, [string]$Body, [hashtable]$ExtraHeaders = @{})
  $headers = @{ 'X-Client-Id' = $CLIENT_ID } + $ExtraHeaders
  try {
    $p = @{ Uri = "http://localhost:8080$Path"; Method = $Method; Headers = $headers; UseBasicParsing = $true }
    if ($Body) { $p.ContentType = 'application/json'; $p.Body = $Body }
    $r = Invoke-WebRequest @p
    Write-Host "HTTP $($r.StatusCode)" -ForegroundColor Green; $r.Content
  } catch {
    $resp = $_.Exception.Response
    if ($resp) {
      Write-Host "HTTP $([int]$resp.StatusCode)" -ForegroundColor Yellow
      (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd()
    } else { Write-Host $_ -ForegroundColor Red }
  }
}
```

Prova subito che il filtro identità funzioni — senza header deve dare **400**:

```bash
curl.exe -s -w "`nHTTP %{http_code}`n" http://localhost:8080/api/tabelloni
```

## 3. Popola la banca domande

**Percorso A — senza chiave Gemini (consigliato per iniziare).** Carica 20
domande predefinite su "Storia romana" e "Geografia":

```bash
Get-Content scripts\seed-banca.sql -Raw | docker exec -i jeopardy-postgres psql -U jeopardy -d jeopardy
```

**Percorso B — con chiave Gemini.** Salta il seed: le domande verranno generate
alla creazione del tabellone (più lenta la prima volta). Occhio alla quota:
20 chiamate LLM al giorno per client (configurabile in `application.yml`,
`app.ia.quota-giornaliera`).

## 4. Tabelloni

### 4.1 Creazione

```bash
Api POST /api/tabelloni '{"titolo":"Il mio quiz","argomenti":["Storia romana","Geografia"],"righe":5,"punti_base":100}'
```

Cose da verificare nella risposta:
- `codice_pubblico` di 6 caratteri e `codice_modifica` di 12 (alfabeto senza 0/O/1/I/L)
- 2 categorie × 5 celle, valori 100/200/300/400/500 (punti_base × riga)
- ogni cella ha `testo` e `risposta` (dal seed, o generate dall'IA)

Salva i codici per i passi successivi:

```bash
$b = (Api POST /api/tabelloni '{"titolo":"Quiz test","argomenti":["Storia romana","Geografia"],"righe":5,"punti_base":100}' | Select-Object -Last 1) | ConvertFrom-Json; $CODICE = $b.codice_pubblico; $MODIFICA = $b.codice_modifica; "pubblico=$CODICE modifica=$MODIFICA"
```

### 4.2 Lettura e lista

```bash
Api GET /api/tabelloni/$CODICE
```

> Verifica: nella risposta **non** compare `codice_modifica` (segreto).

```bash
Api GET /api/tabelloni
```

> Verifica: la lista contiene il tuo tabellone. Cambia `$CLIENT_ID` con un nuovo
> UUID e rilancia: la lista è vuota (i tabelloni sono per-client). Poi ripristina
> il vecchio valore.

### 4.3 Modifica protetta dal codice

Codice sbagliato → **403**:

```bash
Api PUT /api/tabelloni/$CODICE '{"titolo":"Hack"}' @{ 'X-Codice-Modifica' = 'CODICEFARLOCCO' }
```

Codice giusto → **200**. Prendi l'id di una cella dal GET (`$b.categorie[0].celle[0].id`)
e personalizzala:

```bash
$cellaId = $b.categorie[0].celle[0].id
Api PUT /api/tabelloni/$CODICE ('{"titolo":"Quiz rinominato","celle":[{"id":' + $cellaId + ',"testo":"Domanda personalizzata?","risposta":"Risposta mia"}]}') @{ 'X-Codice-Modifica' = $MODIFICA }
```

> Verifica chiave (override, non modifica condivisa): il GET del tabellone mostra
> il testo personalizzato, ma la domanda in banca è intatta:
>
> ```bash
> docker exec jeopardy-postgres psql -U jeopardy -d jeopardy -c "SELECT testo FROM domanda WHERE testo LIKE 'Chi fu il primo%';"
> ```

### 4.4 Rigenera una cella

```bash
Api POST /api/tabelloni/$CODICE/celle/$cellaId/rigenera '' @{ 'X-Codice-Modifica' = $MODIFICA }
```

> Verifica: la cella ha una domanda **diversa** (dalla banca c'è una riserva per
> ogni difficoltà) e gli override del passo precedente sono azzerati.
> Rilanciando ancora, quando le domande di riserva finiscono: `503` senza chiave
> Gemini (o generazione nuova con chiave), oppure `409` se l'IA non trova
> alternative.

## 5. Generazione IA diretta e quota (solo con chiave)

L'endpoint a grana fine usato anche dal tabellone. Gli id degli argomenti
**non partono da 1** (la sequenza avanza anche sui tentativi falliti), quindi
recupera prima quello vero invece di indovinarlo:

```bash
docker exec jeopardy-postgres psql -U jeopardy -d jeopardy -c "SELECT id, nome FROM argomento ORDER BY id;"
```

```bash
$ARG = (docker exec jeopardy-postgres psql -U jeopardy -d jeopardy -t -A -c "SELECT id FROM argomento WHERE slug='storia-romana';").Trim()
Api POST /api/generazioni ('{"argomento_id":' + $ARG + ',"difficolta":3,"numero":2}')
```

> Se ottieni `404 Argomento N non trovato` è proprio questo il caso: l'id
> passato non esiste. Rilancia la query qui sopra.

> Verifica: `chiamata_llm=false` e `riusate>0` se la banca basta (il risparmio è
> il cuore del progetto); `chiamata_llm=true` e `nuove_generate>0` se mancano.
> Ogni chiamata che raggiunge l'LLM scrive una riga di audit:
>
> ```bash
> docker exec jeopardy-postgres psql -U jeopardy -d jeopardy -c "SELECT modello, richieste, accettate, token_input, token_output FROM generazione ORDER BY id DESC LIMIT 5;"
> ```

Per testare il **429 di quota** senza fare 20 chiamate: ferma tutto
(`docker compose down`), riavvia con `$env:GEMINI_API_KEY` impostata e aggiungi
in `docker-compose.yml` al servizio backend `APP_IA_QUOTA_GIORNALIERA: 2`
(Spring legge le env con questo formato). Alla terza generazione su argomenti
nuovi: `429 Quota Exceeded`.

## 6. Segnalazioni

Prendi un id domanda (`SELECT id, testo FROM domanda LIMIT 5;` come sopra) e
segnalala 4 volte — alla quarta lo stato passa a `segnalata` e la domanda esce
dalla selezione dei nuovi tabelloni:

```bash
Api POST /api/domande/1/segnalazioni '{"motivo":"errata","nota":"data sbagliata"}'
```

(motivi validi: `errata`, `ambigua`, `offensiva`, `duplicata`; la soglia è
`app.banca.soglia-segnalazioni`, default 3 = si scatta alla quarta)

## 7. Partita completa

### 7.1 Avvio con squadre

```bash
$p = (Api POST /api/tabelloni/$CODICE/partite '{"squadre":[{"nome":"Rossi","colore":"#ff0000"},{"nome":"Blu","colore":"#0000ff"}]}' | Select-Object -Last 1) | ConvertFrom-Json; $PID_PARTITA = $p.id; $SQ_A = $p.squadre[0].id; $SQ_B = $p.squadre[1].id; "partita=$PID_PARTITA A=$SQ_A B=$SQ_B"
```

> Verifica: `stato=in_corso`, `turno_squadra_id` = prima squadra.

### 7.2 Gioca celle

Prendi gli id delle celle dal tabellone (`$b.categorie[0].celle | Select id, riga, valore`):

```bash
$c1 = $b.categorie[0].celle[0].id; $c2 = $b.categorie[0].celle[1].id; $c3 = $b.categorie[0].celle[2].id
Api POST /api/partite/$PID_PARTITA/celle/$c1 ('{"squadra_id":' + $SQ_A + ',"esito":"corretta","delta_punti":100}')
Api POST /api/partite/$PID_PARTITA/celle/$c2 ('{"squadra_id":' + $SQ_B + ',"esito":"corretta","delta_punti":200}')
```

> Verifiche:
> - `GET /api/partite/$PID_PARTITA` → punteggi aggiornati, `celle_giocate`
>   elencate, turno che ruota tra le squadre attive
> - rigiocare la **stessa** cella → `409 Conflict`

### 7.3 Correzione manuale del punteggio

```bash
Api PATCH /api/partite/$PID_PARTITA/squadre/$SQ_A '{"punteggio":250}'
```

### 7.4 Annulla

Gioca una cella "sbagliata" e annullala:

```bash
Api POST /api/partite/$PID_PARTITA/celle/$c3 ('{"squadra_id":' + $SQ_A + ',"esito":"errata","delta_punti":-300}')
Api POST /api/partite/$PID_PARTITA/annulla ''
Api GET /api/partite/$PID_PARTITA
```

> Verifiche (l'invariante del progetto):
> - il punteggio di A torna a 250 (l'evento annullato non conta più)
> - la cella annullata **si può rigiocare**
> - il punteggio coincide sempre con la somma dei delta del log:
>
> ```bash
> docker exec jeopardy-postgres psql -U jeopardy -d jeopardy -c "SELECT squadra_id, tipo, delta_punti, annullato FROM evento_partita WHERE partita_id = 1 ORDER BY id;"
> ```

### 7.5 Squadre in corsa

```bash
Api POST /api/partite/$PID_PARTITA/squadre '{"nome":"Verdi"}'          # aggiunta a partita iniziata
Api PATCH /api/partite/$PID_PARTITA/squadre/$SQ_B '{"nome":"Blu Reloaded"}'
Api DELETE /api/partite/$PID_PARTITA/squadre/$SQ_A ''                  # soft delete
```

> Verifica: la squadra rimossa resta nello stato con `attiva=false` (lo storico
> eventi rimane coerente); nomi duplicati sono ammessi.

### 7.6 Concludi

```bash
Api POST /api/partite/$PID_PARTITA/concludi ''
```

> Verifica: `stato=conclusa`; giocare un'altra cella ora dà `409`.

### 7.7 Pulizia automatica

Un job giornaliero (cron `app.partita.pulizia-cron`, default 04:00) elimina le
partite **scadute e non concluse** (scadenza `app.partita.scadenza-giorni`,
default 30). Per provarlo subito: retrodata una partita non conclusa e aspetta
il cron, oppure verifica solo il dato:

```bash
docker exec jeopardy-postgres psql -U jeopardy -d jeopardy -c "SELECT id, stato, scade_il FROM partita;"
```

## 8. Log e troubleshooting

```bash
docker logs jeopardy-backend --tail 50 -f
```

- Il backend non parte / errore connessione DB → controlla `docker compose ps`:
  `jeopardy-postgres` deve essere `healthy` (il backend attende l'healthcheck).
- `404 Argomento N non trovato` → l'id non esiste; leggi gli id veri con la
  query del passo 5 (non partono da 1).
- `503 Generazione IA non configurata` → manca `GEMINI_API_KEY` **e** la banca
  non ha domande per quegli argomenti: usa il seed (passo 3) o imposta la chiave.
- `503 Il modello '...' non esiste o non e' piu disponibile` → Google ha
  dismesso quel modello: aggiorna `app.ia.gemini.modello` con uno di quelli
  elencati dalla query del passo 1.
- `503 ... e' sovraccarico` → congestione temporanea del free tier, riprova fra
  poco (capita anche sui modelli più recenti).
- Celle con "Domanda da completare" → la banca/IA non aveva abbastanza domande
  per quella difficoltà: sono placeholder modificabili via PUT.
- Porte occupate (5432/8080) → ferma il servizio in conflitto o cambia il
  mapping in `docker-compose.yml`.

## 9. Reset e pulizia

```bash
docker compose down            # ferma i container, i dati restano
```

```bash
docker compose down -v         # ferma TUTTO e cancella anche il database
```

Dopo un `down -v`, al riavvio Flyway ricrea lo schema da zero (rilancia anche il
seed se ti serve).
