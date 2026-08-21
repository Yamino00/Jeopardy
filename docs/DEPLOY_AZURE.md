# Portare il backend su Azure

Guida completa, scritta per chi Azure non l'ha mai usato. Ogni passo dice **cosa
fa**, **il comando esatto**, **cosa devi vedere se ha funzionato**, **cosa fare
se invece fallisce** e **se costa**.

Dove serve il portale è indicato con il percorso esatto delle voci — ma è raro,
perché il portale cambia interfaccia in continuazione mentre i comandi `az` no.

> **La regola che governa tutto.** La sottoscrizione Azure for Students ha $100
> di credito per 12 mesi. Quando il credito finisce, Azure **disabilita l'intera
> sottoscrizione**: non manda una bolletta, spegne tutto. Il credito non usato
> non passa al mese dopo, quindi il budget reale è circa **$8 al mese**.
>
> L'architettura di questa guida costa **$0,00 al mese** e sta dentro le quote
> gratuite. Il rischio non è questa architettura: è aggiungerci qualcosa dopo.
> Per questo il **passo 3 sono gli avvisi di budget**, prima del deploy e non in
> fondo.

---

## Valori da scegliere una volta sola

Scegli questi valori adesso e tienili sott'occhio: compaiono in quasi tutti i
comandi. I segnaposto in MAIUSCOLO fra parentesi angolari vanno sostituiti.

| Segnaposto | Cos'è | Valore consigliato |
|---|---|---|
| `<NOME_RG>` | Il contenitore di tutte le risorse Azure. Cancellarlo cancella tutto. | `rg-jeopardy` |
| `<REGIONE>` | Il datacenter. La più vicina all'Italia con Container Apps. | `westeurope` |
| `<NOME>` | Prefisso dei nomi. L'ambiente diventa `cae-<NOME>`, il servizio `ca-<NOME>`. | `jeopardy` |
| `<UTENTE_GITHUB>` | Il tuo nome utente GitHub, minuscolo. | — |
| `<EMAIL_AVVISI>` | Dove arrivano gli avvisi di budget. Un indirizzo che leggi. | — |
| `<DB_URL>` | Stringa di connessione, dal passo 2.1. **Deve finire con `?sslmode=require`**. | — |
| `<DB_UTENTE>` | Utente del database, dal passo 2.1. | — |
| `<DB_PASSWORD>` | Password del database, dal passo 2.1. | — |

Il nome del servizio diventa parte dell'indirizzo pubblico, quindi deve essere
minuscolo, senza spazi e senza accenti.

---

## 1. Prima di iniziare

Quello che devi avere e fare tu, prima del primo comando. Sono i passi che
**bloccano tutto il resto**.

### 1.1 Attivare Azure for Students — *gratuito*

Serve un'email istituzionale valida: la verifica dello status studente passa da
lì e non da altro.

1. Vai su <https://azure.microsoft.com/free/students>
2. Accedi con l'email della tua università
3. Segui la verifica dello status studente

**Cosa devi vedere:** il portale mostra $100 di credito e nessuna carta di
credito richiesta.

**Se fallisce:** se la verifica non riconosce l'ateneo, l'unica strada è il
supporto Microsoft — non c'è modo di aggirarla da riga di comando. Senza questo
passo il resto della guida non è eseguibile.

### 1.2 Installare gli strumenti — *gratuito*

Su Windows, da PowerShell:

```bash
winget install --id Microsoft.AzureCLI -e
```

Docker Desktop e GitHub CLI dovresti già averli. Per controllarlo:

```bash
docker --version; gh --version
```

**Chiudi e riapri il terminale** dopo l'installazione di `az`: il `PATH` non si
aggiorna in una sessione già aperta.

**Cosa devi vedere:**

```bash
az version
```

Un blocco JSON con `azure-cli` e un numero di versione.

**Se fallisce** con «`az` non è riconosciuto»: il terminale è quello di prima.
Riaprilo. Se ancora non va, riavvia il computer — l'installer aggiorna il `PATH`
di sistema e a volte serve.

### 1.3 Autenticarsi — *gratuito*

```bash
az login
```

Si apre il browser. Accedi con lo stesso account del passo 1.1.

**Cosa devi vedere:** al ritorno nel terminale, una tabella con la tua
sottoscrizione e `"state": "Enabled"`.

Per fissare la sottoscrizione giusta, se ne hai più di una:

```bash
az account set --subscription "Azure for Students"
```

Verifica:

```bash
az account show --output table
```

**Se fallisce** con «No subscriptions found»: la verifica studente del passo 1.1
non è andata a buon fine, oppure hai fatto login con un altro account.

### 1.4 Registrare i provider — *gratuito, una tantum*

Azure tiene disattivati i servizi che non hai mai usato. Container Apps è uno di
questi, e senza questo passo il passo 2.2 fallisce con un errore che non lo dice
chiaramente.

```bash
az provider register --namespace Microsoft.App --wait
```

```bash
az provider register --namespace Microsoft.OperationalInsights --wait
```

> `Microsoft.OperationalInsights` è il provider di Log Analytics. Lo
> registriamo perché Container Apps lo richiede comunque presente, **ma non
> creeremo nessun workspace**: l'ingestione dei log consuma credito in silenzio
> e la nostra configurazione la disattiva esplicitamente.

**Cosa devi vedere:**

```bash
az provider show --namespace Microsoft.App --query registrationState -o tsv
```

La parola `Registered`. Può volerci qualche minuto: `--wait` aspetta per te.

**Se fallisce** con `AuthorizationFailed`: l'account non ha i permessi sulla
sottoscrizione. Su Azure for Students dovresti esserne il proprietario;
ricontrolla di essere sulla sottoscrizione giusta con `az account show`.

---

## 2. Setup una tantum

Le risorse che si creano la prima volta e mai più.

### 2.1 Il database, fuori da Azure — *gratuito, per sempre*

Il database **non** va su Azure, ed è la scelta che tiene il conto a zero. Un
Azure Database for PostgreSQL, anche nella taglia minima, costa oltre $15 al
mese: da solo sarebbe il doppio del budget. Neon ha un piano gratuito senza
scadenza e senza carta di credito, e supporta le due estensioni che lo schema
richiede (`unaccent` e `pg_trgm`), quindi le migrazioni girano senza modifiche.

1. Vai su <https://neon.com> e registrati (va bene l'account GitHub)
2. Crea un progetto, regione **Europa** — una qualunque: la latenza verso West
   Europe è di pochi millisecondi, mentre dagli Stati Uniti si sentirebbe
3. PostgreSQL 16 o superiore
4. A progetto creato, copia la stringa di connessione dalla schermata
   **Connection Details**, scegliendo il formato **Java / JDBC**

La stringa che copi assomiglia a questa:

```
jdbc:postgresql://ep-qualcosa-12345.eu-central-1.aws.neon.tech/neondb?sslmode=require
```

Da qui ricavi tre valori: `<DB_URL>` (la stringa intera), `<DB_UTENTE>` e
`<DB_PASSWORD>` (che Neon mostra separatamente nella stessa schermata).

> **Controlla che la stringa finisca con `?sslmode=require`.** Se manca, il
> backend non si avvia: Neon rifiuta le connessioni in chiaro, e l'errore che
> vedresti parla di rete, non di TLS. È il singolo errore più comune di questa
> guida.

**Cosa devi vedere:** nella console Neon, il progetto con lo stato **Active** e
un database chiamato `neondb`.

**Se fallisce:** se il piano gratuito non è più disponibile alle condizioni
descritte, l'alternativa più vicina è Supabase (piano gratuito, ma i progetti si
sospendono dopo una settimana di inattività — peggio per un'app che si usa a
raffiche). Non mettere Postgres su Azure senza rifare i conti.

### 2.2 Il gruppo di risorse e il servizio — *gratuito a riposo*

Il gruppo di risorse è la scatola che contiene tutto. Crearlo non costa niente,
e cancellarlo cancella tutto quello che c'è dentro: è la tua leva di emergenza
(vedi la sezione 7).

```bash
az group create --name <NOME_RG> --location <REGIONE>
```

**Cosa devi vedere:** JSON con `"provisioningState": "Succeeded"`.

Ora l'ambiente e il servizio, descritti in `infra/main.bicep`. Il comando
sostituisce quaranta click nel portale che non sapresti rifare fra tre mesi, ed
è **rieseguibile**: lanciarlo due volte non crea due servizi.

```bash
az deployment group create --resource-group <NOME_RG> --template-file infra/main.bicep --parameters infra/main.parameters.json --parameters immagine=ghcr.io/<UTENTE_GITHUB>/jeopardy-backend:latest dbUrl='<DB_URL>' dbUsername='<DB_UTENTE>' dbPassword='<DB_PASSWORD>' geminiApiKey='<CHIAVE_GEMINI>' groqApiKey='<CHIAVE_GROQ>'
```

> **Gli apici singoli servono.** Le stringhe di connessione contengono `?` e
> `&`, che PowerShell interpreta se non sono protetti.
>
> Le chiavi LLM sono le stesse che hai nel `.env` locale. Passandole qui
> finiscono nelle impostazioni applicative del servizio, cifrate, e **non**
> nel repository.

Questo passo fallirà la prima volta, ed è previsto: l'immagine
`ghcr.io/<UTENTE_GITHUB>/jeopardy-backend:latest` non esiste ancora. Il servizio
viene creato lo stesso e resterà in errore finché non fai il primo deploy
(passo 4). Se preferisci evitarlo, fai prima il passo 4.1 e poi torna qui.

**Cosa devi vedere:** in fondo all'output, `"provisioningState": "Succeeded"` e
un valore `url` che assomiglia a
`https://ca-jeopardy.westeurope.azurecontainerapps.io`. **Segnatelo**: è
l'indirizzo del backend, e serve sia per la verifica sia per costruire l'APK.

Se ti serve ritrovarlo dopo:

```bash
az containerapp show --name ca-<NOME> --resource-group <NOME_RG> --query properties.configuration.ingress.fqdn -o tsv
```

**Se fallisce** con `MissingSubscriptionRegistration`: torna al passo 1.4, la
registrazione del provider non era finita.

**Se fallisce** con un errore di quota o di disponibilità in `<REGIONE>`: prova
`northeurope`. Non ho potuto verificare se Container Apps abbia restrizioni
sulle sottoscrizioni Student, quindi questo è il punto in cui si scopre —
motivo per cui viene prima di tutto il resto.

### 2.3 Far parlare GitHub Actions con Azure — *gratuito, una tantum*

Serve perché il workflow di deploy possa aggiornare il servizio **senza che tu
salvi una password da nessuna parte**. Si usa la federazione OIDC: GitHub prova
la propria identità a ogni esecuzione, e Azure gli crede solo per questo
repository.

Prima crea l'identità applicativa:

```bash
az ad app create --display-name "jeopardy-deploy" --query appId -o tsv
```

Segna il valore che stampa: è `<APP_ID>`.

```bash
az ad sp create --id <APP_ID>
```

Dai a quell'identità il permesso di modificare **solo** il gruppo di risorse:

```bash
az role assignment create --assignee <APP_ID> --role Contributor --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/<NOME_RG>
```

Poi la credenziale federata, che lega l'identità al ramo `main` del tuo
repository:

```bash
az ad app federated-credential create --id <APP_ID> --parameters '{"name":"github-main","issuer":"https://token.actions.githubusercontent.com","subject":"repo:<UTENTE_GITHUB>/Jeopardy:ref:refs/heads/main","audiences":["api://AzureADTokenExchange"]}'
```

> Sostituisci `Jeopardy` con il nome esatto del repository se è diverso, e
> attenzione alle maiuscole: il confronto è sensibile.

Infine consegna a GitHub i tre identificatori. Non sono credenziali: da soli non
aprono niente.

```bash
gh secret set AZURE_CLIENT_ID --body "<APP_ID>"
```

```bash
gh secret set AZURE_TENANT_ID --body "$(az account show --query tenantId -o tsv)"
```

```bash
gh secret set AZURE_SUBSCRIPTION_ID --body "$(az account show --query id -o tsv)"
```

E le due variabili che dicono al workflow come si chiamano le risorse:

```bash
gh variable set NOME_RISORSE --body "<NOME>"
```

```bash
gh variable set GRUPPO_RISORSE --body "<NOME_RG>"
```

**Cosa devi vedere:**

```bash
gh secret list; gh variable list
```

Tre segreti e due variabili.

**Se fallisce** `az ad app create` con `Insufficient privileges`: il tuo account
non può creare identità applicative nel tenant. Capita sui tenant universitari
gestiti. In quel caso salta questo passo e fai i deploy a mano dal tuo computer
(passo 4.2): funziona identico, solo meno comodo.

---

## 3. Avvisi di budget — **non saltare questo passo**

È qui e non in fondo di proposito. Azure genera da sé avvisi al 90% e al 100%
del credito complessivo, ma arrivano tardi e ragionano sul totale dei 12 mesi.
Questi due ragionano sulla spesa **del mese**, che è quella su cui puoi ancora
intervenire.

```bash
az deployment sub create --location <REGIONE> --template-file infra/budget.bicep --parameters email=<EMAIL_AVVISI>
```

**Cosa devi vedere:** `"provisioningState": "Succeeded"`.

**Cosa costa:** niente. Gli avvisi sono gratuiti.

**Se fallisce** con un errore sulla data di inizio: il budget vuole il primo di
un mese non passato. Passa esplicitamente il mese corrente:

```bash
az deployment sub create --location <REGIONE> --template-file infra/budget.bicep --parameters email=<EMAIL_AVVISI> inizio=2026-09-01
```

**Se fallisce** con `AuthorizationFailed`: i budget si creano a livello di
sottoscrizione e servono i permessi lì, non solo sul gruppo di risorse. Su Azure
for Students dovresti averli.

**Verifica che ci siano davvero:**

```bash
az consumption budget list --query "[].{nome:name, tetto:amount}" -o table
```

Se il comando non esiste nella tua versione della CLI — quel gruppo di comandi
si è spostato più volte fra versioni, e non ho potuto verificarlo — controlla
dal portale: **Cost Management + Billing → Cost Management → Budgets**.

E per vedere quanto hai speso finora:

```bash
az consumption usage list --query "[].{data:usageStart, costo:pretaxCost}" -o table
```

---

## 4. Deploy

La procedura ripetibile, da fare a ogni rilascio. Due strade: la prima è quella
normale, la seconda serve quando il passo 2.3 non è stato possibile.

### 4.1 Con GitHub Actions — *consuma credito solo per il servizio*

Rendi pubblico il pacchetto la prima volta, così Azure può scaricarlo senza
credenziali. Dopo il primo push dell'immagine, dal browser:

**github.com/<UTENTE_GITHUB>?tab=packages → jeopardy-backend → Package settings
→ Change visibility → Public**

> L'immagine è pubblica e va bene: **non contiene segreti**. Le credenziali del
> database e le chiavi LLM arrivano dalle impostazioni applicative a runtime, e
> `backend/.dockerignore` esclude `.env` e `target/` dal contesto di build
> perché resti vero.

Poi, per ogni rilascio:

```bash
gh workflow run "Deploy backend su Azure"
```

Il workflow esegue i test, costruisce l'immagine, la pubblica su ghcr.io e
aggiorna il servizio.

**Cosa devi vedere:**

```bash
gh run watch
```

Tutti i passi verdi, e in fondo un riepilogo con l'indirizzo del servizio.

**Se fallisce** al passo «Accesso ad Azure» con `AADSTS70021`: il `subject`
della credenziale federata non corrisponde. Ricontrolla il passo 2.3: nome del
repository e maiuscole devono coincidere esattamente.

**Se fallisce** al passo «Test del backend»: non è un problema di deploy, è il
codice. Guarda quale test è rosso.

### 4.2 A mano, dal tuo computer — *stessa cosa, meno comoda*

```bash
docker build -t ghcr.io/<UTENTE_GITHUB>/jeopardy-backend:latest ./backend
```

```bash
gh auth token | docker login ghcr.io -u <UTENTE_GITHUB> --password-stdin
```

```bash
docker push ghcr.io/<UTENTE_GITHUB>/jeopardy-backend:latest
```

```bash
az containerapp update --name ca-<NOME> --resource-group <NOME_RG> --image ghcr.io/<UTENTE_GITHUB>/jeopardy-backend:latest
```

**Cosa devi vedere:** `"provisioningState": "Succeeded"`.

**Se fallisce** il `docker build` allo stage CDS: quello stage costruisce un
archivio che accelera l'avvio della JVM di circa il 28% (misurato: 24 s invece
di 34 s su mezza vCPU), e verifica che sia utilizzabile prima di andare avanti.
Se si rompe, è un problema vero e va guardato — non aggirato.

---

## 5. Verifica

### 5.1 Il backend risponde

```bash
powershell -ExecutionPolicy Bypass -File scripts\verifica-deploy.ps1 -BaseUrl https://ca-<NOME>.<REGIONE>.azurecontainerapps.io
```

Lo script controlla, in ordine: che risponda (e **misura l'avvio a freddo**),
che raggiunga il database in TLS, che le rotte protette chiedano ancora
l'identità del client, e che creare un tabellone vero funzioni — riportando
quanto tempo resta prima del tetto interno di 150 secondi.

**Cosa devi vedere:** quattro blocchi verdi e, in fondo, il comando per
costruire l'APK.

> La prima chiamata dopo un periodo di inattività può metterci **20-60
> secondi**: il servizio scende a zero istanze quando nessuno gioca, e paga
> l'avvio della JVM. È il prezzo di non spendere $13,60 al mese per tenerlo
> sempre acceso. L'app lo maschera mandando un ping a vuoto all'apertura, così
> il server si scalda mentre scegli gli argomenti.

Il punto 4 chiama l'IA e consuma una delle generazioni giornaliere. Per un
controllo veloce che non consuma niente:

```bash
powershell -ExecutionPolicy Bypass -File scripts\verifica-deploy.ps1 -BaseUrl https://ca-<NOME>.<REGIONE>.azurecontainerapps.io -SaltaCreazione
```

### 5.2 L'app vera punta al backend vero

```bash
cd frontend && flutter build apk --release --dart-define=API_BASE_URL=https://ca-<NOME>.<REGIONE>.azurecontainerapps.io
```

> **Il `--dart-define` non è opzionale.** Senza, l'APK parla con
> `http://localhost:8080`, cioè con se stesso, e non funziona niente. E deve
> essere `https`: l'APK di release non permette traffico in chiaro, di
> proposito, perché un deploy in HTTP fallisca invece di funzionare per sbaglio.

L'APK esce in `frontend/build/app/outputs/flutter-apk/app-release.apk`.

**Cosa devi vedere:** installato sul telefono, l'app crea un tabellone e ci
gioca una partita.

---

## 6. Cosa fare quando qualcosa non va

Per prima cosa, i log in diretta. Non c'è storico — è una scelta di budget, vedi
la nota in fondo — quindi vanno guardati **mentre** il problema succede:

```bash
az containerapp logs show --name ca-<NOME> --resource-group <NOME_RG> --follow
```

### «Il servizio non risponde» / la verifica si ferma al punto 1

Se sono passati più di due minuti, non è l'avvio a freddo. Controlla lo stato:

```bash
az containerapp revision list --name ca-<NOME> --resource-group <NOME_RG> --query "[].{revisione:name, attiva:properties.active, stato:properties.runningState}" -o table
```

Se `runningState` è `Failed`, il container parte e muore. Quasi sempre è il
database: vedi il punto seguente.

### `PSQLException` / `Connection refused` nei log

Nel 90% dei casi `DB_URL` non finisce con `?sslmode=require`. Controlla cosa ha
davvero il servizio:

```bash
az containerapp show --name ca-<NOME> --resource-group <NOME_RG> --query "properties.template.containers[0].env[?name=='DB_URL']" -o table
```

Il valore è mascherato perché è un segreto. Per correggerlo, rilancia il
comando del passo 2.2 con la stringa giusta.

L'altro caso possibile è il progetto Neon sospeso per inattività prolungata:
aprilo dalla console e si risveglia.

### HTTP 503 creando un tabellone

Il backend non riesce a generare domande. Due cause:

- **Chiavi LLM mancanti o scadute.** I log dicono «Generazione IA non
  configurata» oppure «Chiave Gemini non valida». Rilancia il passo 2.2 con le
  chiavi giuste.
- **Banca vuota per quell'argomento e IA che non produce niente.** Il backend
  si rifiuta di consegnare un tabellone con dei buchi, ed è voluto: una griglia
  incompleta si scopre a partita iniziata. Riprova, o scegli un argomento meno
  stretto.

### HTTP 504 creando un tabellone

La generazione ha superato il tetto interno di 150 secondi e il server si è
fermato da solo, per rispondere prima che lo faccia il proxy. Non è un guasto,
è il limite che funziona.

Succede con molte categorie e provider LLM lenti. Rimedi, nell'ordine: meno
categorie, meno righe, oppure riprova più tardi. Se capita sempre, alza il
tetto — ma **non oltre 170 secondi**, perché il client molla a 180 e l'ingress
di Azure a 240, e l'ordine di quei tre numeri è quello che fa arrivare un errore
comprensibile invece di una connessione tagliata:

```bash
az containerapp update --name ca-<NOME> --resource-group <NOME_RG> --set-env-vars APP_TABELLONE_BUDGET_CREAZIONE_SECONDI=170
```

### «Il credito sta finendo»

Guarda cosa consuma:

```bash
az consumption usage list --query "[].{risorsa:instanceName, costo:pretaxCost}" -o table
```

Se compare qualcosa che non è la Container App, è arrivato qualcosa che non
avevi previsto — quasi sempre un workspace Log Analytics agganciato da una
diagnostica accesa nel portale. Cancellalo.

Se il consumo è davvero della Container App, stai superando le 100 ore mensili
di servizio acceso. Sono $0,076 all'ora oltre la soglia: non è un'emergenza, ma
tienilo d'occhio.

---

## 7. Come spengo tutto

La sezione che serve di più il giorno in cui qualcosa va storto.

### Fermare il consumo senza cancellare niente

Porta il servizio a zero repliche fisse. Resta tutto in piedi, ma non risponde e
non consuma:

```bash
az containerapp update --name ca-<NOME> --resource-group <NOME_RG> --min-replicas 0 --max-replicas 0
```

Per riaccenderlo:

```bash
az containerapp update --name ca-<NOME> --resource-group <NOME_RG> --min-replicas 0 --max-replicas 2
```

### Cancellare tutto

Il gruppo di risorse contiene ogni risorsa Azure di questo progetto.
Cancellarlo le cancella tutte, e **non si torna indietro**:

```bash
az group delete --name <NOME_RG> --yes
```

**Cosa devi vedere:** il comando finisce senza errori. Ci mette qualche minuto.

**Verifica che sia sparito davvero:**

```bash
az group exists --name <NOME_RG>
```

Deve stampare `false`. Finché stampa `true`, qualcosa consuma ancora.

Il budget del passo 3 vive a livello di sottoscrizione e sopravvive: se vuoi
togliere anche quello,

```bash
az consumption budget delete --budget-name budget-jeopardy
```

o dal portale, **Cost Management + Billing → Cost Management → Budgets**.

### Cancellare il database

Neon è fuori da Azure e non si tocca cancellando il gruppo di risorse. Dalla
console Neon: **Project settings → Delete project**.

**I dati non sono recuperabili.** Se ci tieni, prima esportali:

```bash
docker run --rm postgres:16 pg_dump "<DB_URL_SENZA_PREFISSO_JDBC>" > backup.sql
```

dove `<DB_URL_SENZA_PREFISSO_JDBC>` è la stessa stringa senza `jdbc:` davanti.

---

## Note su cosa costa, e su cosa non ho potuto verificare

**Prezzi verificati il 20 agosto 2026** dall'API prezzi al dettaglio di Azure
per `westeurope` in USD, non dalla documentazione commerciale:

| Voce | Costo |
|---|---|
| Container Apps, quota gratuita mensile | 180.000 vCPU-secondi, 360.000 GiB-secondi, 2 milioni di richieste |
| A 0,5 vCPU / 1 GiB, la quota copre | **100 ore al mese di servizio acceso** |
| Oltre la quota | $0,0756 all'ora |
| Ambiente Container Apps | nessun canone nel piano Consumption |
| Neon, piano gratuito | $0, senza scadenza |
| ghcr.io, immagine pubblica | $0 |
| Avvisi di budget | $0 |
| **Totale atteso** | **$0,00 al mese** |

Due voci **deliberatamente evitate**: Azure Container Registry Basic ($0,167 al
giorno, cioè $5,08 al mese) sostituito da ghcr.io, e Log Analytics disattivato
con `logsDestination: none` in `infra/main.bicep`.

Cose che **non ho potuto verificare** e su cui potresti trovare sorprese:

- **Se Container Apps abbia quote o restrizioni sulle sottoscrizioni Student in
  West Europe.** Si scopre al passo 2.2, ed è per questo che quel passo viene
  prima del resto.
- **La forma esatta di `az consumption budget list`** nella versione corrente
  della CLI: quel gruppo di comandi si è spostato più volte. Il percorso nel
  portale è indicato al passo 3 come alternativa.
- **La franchigia sul traffico in uscita.** Il nostro traffico è JSON,
  dell'ordine dei megabyte al mese: qualunque sia la franchigia ci stiamo
  dentro, ma non l'ho verificata.
- **I template Bicep non sono stati validati** con `az bicep build`, perché la
  CLI di Azure non era installata sulla macchina su cui sono stati scritti. Il
  primo `az deployment group create` è anche il primo controllo di sintassi: se
  segnala un errore nel template, è di questa natura e non della tua
  configurazione.
