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
| `<REGIONE>` | Il datacenter. **Non sceglierlo adesso**: la tua sottoscrizione ne permette solo alcuni, e quali lo scopri al passo 2.2. | dal passo 2.2 |
| `<NOME>` | Prefisso dei nomi. L'ambiente diventa `cae-<NOME>`, il servizio `ca-<NOME>`. | `jeopardy` |
| `<UTENTE_GITHUB>` | Il tuo nome utente GitHub, minuscolo. | — |
| `<EMAIL_AVVISI>` | Dove arrivano gli avvisi di budget. Un indirizzo che leggi. | — |

Le credenziali del database e le chiavi dell'IA non sono in questa tabella di
proposito: non vanno mai su una riga di comando. Si scrivono una volta sola in
`infra/segreti.parameters.json`, al passo 2.3.

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
questi, e senza questo passo il passo 2.4 fallisce con un errore che non lo dice
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
> e il template non dichiara nessuna destinazione per i log.

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
2. Crea un progetto. **Aspetta il passo 2.2 per scegliere la regione**: conviene
   metterla vicina alla regione Azure che ti tocca, e quella non la scegli tu.
   Cambiare regione a Neon è gratis e immediato, quella di Azure no.
3. PostgreSQL 16 o superiore
4. A progetto creato, copia la stringa di connessione dalla schermata
   **Connection Details**, scegliendo il formato **Java / JDBC**

La stringa che copi assomiglia a questa, con utente e password già dentro:

```
jdbc:postgresql://ep-qualcosa-12345-pooler.c-6.eu-central-1.aws.neon.tech/neondb?user=neondb_owner&password=npg_xxxx&sslmode=require&channelBinding=require
```

Al passo 2.3 la ripulirai: utente e password vanno nei loro campi, non nell'URL.

**Cosa devi vedere:** nella console Neon, il progetto con lo stato **Active** e
un database chiamato `neondb`.

**Se fallisce:** se il piano gratuito non è più disponibile alle condizioni
descritte, l'alternativa più vicina è Supabase (piano gratuito, ma i progetti si
sospendono dopo una settimana di inattività — peggio per un'app che si usa a
raffiche). Non mettere Postgres su Azure senza rifare i conti.

### 2.2 Scoprire in quali regioni puoi distribuire — *gratuito*

**Fai questo passo prima di scegliere `<REGIONE>`.** Le sottoscrizioni Azure for
Students hanno un elenco ristretto di regioni — tipicamente cinque — deciso da
Microsoft e **diverso per ogni persona**. Non è configurabile, e non c'è modo di
indovinarlo: `westeurope` può esserci o non esserci.

```bash
az policy assignment list --query "[].{criterio:displayName, regioni:parameters.listOfAllowedLocations.value}" -o json
```

**Cosa devi vedere:** un elenco di criteri; quello che riguarda le regioni si
chiama «Allowed resource deployment regions» e ha un campo `regioni`
valorizzato.

> **Su questa sottoscrizione, al 21 agosto 2026**, l'elenco era:
> `francecentral`, `uaenorth`, `spaincentral`, `polandcentral`, **`italynorth`**.
>
> Container Apps è disponibile in tutte e cinque — verificato — e `italynorth`
> è Milano, la più vicina sia a te sia al database. **Usa `italynorth`.**
>
> L'elenco può cambiare: se un comando fallisce dicendo che la regione è
> vietata, rilancia la query qui sopra invece di fidarti di questa nota.

Poi controlla che Container Apps esista davvero nella regione scelta: le regioni
permesse dalla sottoscrizione e quelle in cui il servizio è disponibile sono due
elenchi diversi, e devono intersecarsi.

```bash
az provider show --namespace Microsoft.App --query "resourceTypes[?resourceType=='managedEnvironments'].locations | [0]" -o json
```

**Se il primo comando non restituisce niente di utile**, guarda dal portale:
**Criteri → Creazione → Assegnazioni**, cerca l'assegnazione con «location» o
«region» nel nome e apri **Parametri**.

> **Se nessuna regione permessa fosse in Europa** il progetto funzionerebbe lo
> stesso, ma ogni query al database pagherebbe la traversata dell'Atlantico due
> volte. In quel caso conviene creare il progetto Neon vicino alla regione Azure
> che ti tocca, non il contrario: cambiare regione a Neon è gratis e immediato,
> quella di Azure non dipende da te.

### 2.3 Preparare i segreti — *gratuito*

I segreti **non** vanno sulla riga di comando. Due motivi concreti, non teorici:

- su Windows `az` è un file `.cmd`, e `cmd.exe` rilegge la riga di comando dopo
  PowerShell: le `&` di una stringa di connessione vengono interpretate come
  separatori **anche dentro gli apici singoli**, e il comando si spezza a metà;
- quello che scrivi nel terminale resta in chiaro per sempre nella cronologia di
  PowerShell.

Copia il modello:

```bash
copy infra\segreti.parameters.json.esempio infra\segreti.parameters.json
```

Aprilo e riempi i cinque valori. Il file è già in `.gitignore`.

Per `dbUrl` usa la stringa JDBC di Neon **senza utente e password dentro**: quelli
vanno nei loro campi. Neon te la dà con tutto incluso, quindi va ripulita —
tieni solo host, database e parametri:

```
jdbc:postgresql://ep-xxxx-pooler.c-6.eu-central-1.aws.neon.tech/neondb?sslmode=require&channelBinding=require
```

> **Controlla che ci sia `sslmode=require`.** Se manca, il backend non si avvia:
> Neon rifiuta le connessioni in chiaro, e l'errore parla di rete, non di TLS.
>
> L'endpoint `-pooler` va benissimo: Neon usa PgBouncer 1.22, che supporta le
> prepared statement a livello di protocollo, quindi Hibernate funziona senza
> dover disattivare niente.

**Verifica che sia davvero ignorato da git:**

```bash
git check-ignore -v infra/segreti.parameters.json
```

Deve stampare una riga. Se non stampa niente, il file **finirebbe nel
repository**: fermati e sistemalo prima di andare avanti.

### 2.4 Il gruppo di risorse e il servizio — *gratuito a riposo*

Il gruppo di risorse è la scatola che contiene tutto. Crearlo non costa niente,
e cancellarlo cancella tutto quello che c'è dentro: è la tua leva di emergenza
(vedi la sezione 7).

```bash
az group create --name <NOME_RG> --location <REGIONE>
```

**Cosa devi vedere:** JSON con `"provisioningState": "Succeeded"`.

> La regione si sceglie **qui e solo qui**: il template la eredita dal gruppo di
> risorse, così non c'è un secondo posto in cui possa divergere.

Ora l'ambiente e il servizio, descritti in `infra/main.bicep`. Il comando
sostituisce quaranta click nel portale che non sapresti rifare fra tre mesi, ed
è **rieseguibile**: lanciarlo due volte non crea due servizi.

```bash
az deployment group create --resource-group <NOME_RG> --template-file infra/main.bicep --parameters infra/main.parameters.json --parameters infra/segreti.parameters.json --parameters immagine=ghcr.io/<UTENTE_GITHUB>/jeopardy-backend:latest
```

Questo passo fallirà la prima volta, ed è previsto: l'immagine
`ghcr.io/<UTENTE_GITHUB>/jeopardy-backend:latest` non esiste ancora. Il servizio
viene creato lo stesso e resterà in errore finché non fai il primo deploy
(passo 4). Se preferisci evitarlo, fai prima il passo 4.1 e poi torna qui.

**Cosa devi vedere:** in fondo all'output, `"provisioningState": "Succeeded"` e
un valore `url`. **Segnatelo**: è l'indirizzo del backend, e serve sia per la
verifica sia per costruire l'APK.

> **Non provare a comporlo a mente.** Non è
> `ca-<NOME>.<REGIONE>.azurecontainerapps.io`: Azure infila un sottodominio
> casuale, assegnato all'ambiente alla creazione. Quello vero assomiglia a
> `ca-jeopardy.agreeablepebble-31d3ba21.italynorth.azurecontainerapps.io`, e
> l'unico modo di conoscerlo è chiederlo.

Per rileggerlo in qualunque momento:

```bash
az containerapp show --name ca-<NOME> --resource-group <NOME_RG> --query properties.configuration.ingress.fqdn -o tsv
```

**Controlla subito che non sia comparso un workspace Log Analytics.** Il
template non ne dichiara nessuno, ma è il tipo di risorsa che Azure aggancia da
sé quando qualcosa la richiede, e consuma credito in silenzio:

```bash
az resource list --resource-group <NOME_RG> --query "[].{tipo:type, nome:name}" -o table
```

**Cosa devi vedere:** solo `Microsoft.App/managedEnvironments` e
`Microsoft.App/containerApps`. Se compare `Microsoft.OperationalInsights/workspaces`,
cancellalo:

```bash
az monitor log-analytics workspace delete --resource-group <NOME_RG> --workspace-name <NOME_WORKSPACE> --yes
```

**Se ti chiede** «Please provide securestring value for 'dbUsername'»: il file
dei segreti non è stato letto, o ha un campo vuoto. Non rispondere al prompt —
premi Ctrl+C, controlla il percorso e che tutti e cinque i valori siano pieni.

**Se fallisce** con `RequestDisallowedByAzure` e un messaggio sulle «best
available regions»: la regione del gruppo di risorse non è fra quelle permesse.
Torna al passo 2.2, cancella il gruppo (`az group delete --name <NOME_RG>
--yes`) e ricrealo in una regione dell'elenco.

**Se fallisce** con `MissingSubscriptionRegistration`: torna al passo 1.4, la
registrazione del provider non era finita.

### 2.5 Far parlare GitHub Actions con Azure — *gratuito, una tantum*

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

Ora crea l'**ambiente** su GitHub. Il workflow lo dichiara (`environment: azure`)
per due ragioni: è il punto in cui puoi chiedere un'approvazione manuale prima di
un deploy che consuma credito, ed è quello che determina l'identità con cui
GitHub si presenta ad Azure — vedi la nota qui sotto.

```bash
gh api -X PUT repos/Yamino00/Jeopardy/environments/azure
```

Se vuoi anche il blocco manuale prima di ogni deploy — consigliato, visto che
ogni deploy tocca risorse che consumano credito — quello si aggiunge dal
browser: **Settings → Environments → azure → Required reviewers**, e metti te
stesso.

Poi la credenziale federata. Azure confronta il `subject` **carattere per
carattere**, senza jolly, quindi deve essere esattamente quello che GitHub
manderà. Due cose lo rendono meno ovvio di come lo raccontano i tutorial:

1. **Il job dichiara un `environment:`**, quindi GitHub non mette il ramo nel
   claim: la forma è `…:environment:azure`, non `…:ref:refs/heads/main`.
2. **I repository creati dopo il 15 luglio 2026 usano i *subject immutabili***:
   al proprietario e al repository viene attaccato il rispettivo ID numerico,
   così un nome riciclato non può ereditare la fiducia del precedente. La forma
   diventa `repo:OWNER@IDOWNER/REPO@IDREPO:environment:azure`.

Ricava gli ID — sono pubblici, non sono segreti:

```bash
gh api users/Yamino00 --jq .id; gh api repos/Yamino00/Jeopardy --jq .id
```

Il file `infra/federated-credential.json` contiene già il soggetto composto per
questo repository. **Se il tuo è diverso**, ricomponilo con gli ID appena letti
prima di andare avanti.

**Non passare il JSON come stringa sulla riga di comando**: PowerShell toglie le
virgolette prima che `az` le veda, e ottieni «Failed to parse string as JSON».

```bash
az ad app federated-credential create --id <APP_ID> --parameters '@infra/federated-credential.json'
```

> **Se avevi già creato la credenziale con il soggetto vecchio** (senza gli ID),
> non serve cancellarla: correggila sul posto.
>
> ```bash
> az ad app federated-credential update --id <APP_ID> --federated-credential-id github-deploy --parameters '@infra/federated-credential.json'
> ```

**Cosa devi vedere:** un JSON con il `subject` che hai scelto. Per rileggerlo:

```bash
az ad app federated-credential list --id <APP_ID> --query "[].{nome:name, soggetto:subject}" -o table
```

**Se fallisce** con «Failed to parse string as JSON»: hai passato il JSON come
stringa invece del file. Usa la forma `'@percorso'`, apici singoli compresi.

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
normale, la seconda serve quando il passo 2.5 non è stato possibile.

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

**Se fallisce** al passo «Accesso ad Azure» con `AADSTS700213` o `AADSTS70021`:
il `subject` della credenziale non corrisponde a quello che GitHub ha mandato.
Il bello è che **l'errore ti dice quello presentato**, fra apici singoli:
`No matching federated identity record found for presented assertion subject
'…'`. Copialo da lì — è la verità, e non va indovinata.

Confrontalo con quello che Azure si aspetta:

```bash
az ad app federated-credential list --id <APP_ID> --query "[].subject" -o tsv
```

Se differiscono, allinea Azure a GitHub: metti il soggetto presentato in
`infra/federated-credential.json` e aggiorna la credenziale.

```bash
az ad app federated-credential update --id <APP_ID> --federated-credential-id github-deploy --parameters '@infra/federated-credential.json'
```

Le quattro trappole, in ordine di frequenza: gli **ID immutabili** attaccati a
proprietario e repository, la forma `environment:` invece di
`ref:refs/heads/main`, le **maiuscole** di proprietario e repository, e
l'ambiente `azure` che deve **esistere** su GitHub.

**Se fallisce** al passo «Test del backend»: non è un problema di deploy, è il
codice. Guarda quale test è rosso.

**Se fallisce** al passo «Costruzione e push» con «repository name must be
lowercase»: il proprietario del repository ha delle maiuscole (`Yamino00`) e i
registri OCI non le accettano. Il workflow lo abbassa da sé in un passo
apposito, perché le espressioni `${{ }}` di GitHub non hanno una funzione per
farlo. Se hai modificato quella parte, ricontrolla che il nome dell'immagine
passi da `${GITHUB_REPOSITORY_OWNER,,}` e non da
`${{ github.repository_owner }}`.

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
powershell -ExecutionPolicy Bypass -File scripts\verifica-deploy.ps1
```

Senza argomenti l'indirizzo se lo fa dire ad Azure: non c'è niente da copiare e
niente da sbagliare. Lo script controlla, in ordine: che il backend risponda (e
**misura l'avvio a freddo**), che raggiunga il database in TLS, che le rotte
protette chiedano ancora l'identità del client, e che creare un tabellone vero
funzioni — riportando quanto tempo resta prima del tetto interno di 150 secondi.

**Cosa devi vedere:** quattro blocchi verdi e, in fondo, il comando per
costruire l'APK, con l'indirizzo giusto già dentro.

> La prima chiamata dopo un periodo di inattività può metterci **20-60
> secondi** — misurati 31 s sul primo risveglio reale. Il servizio scende a zero
> istanze quando nessuno gioca, e paga l'avvio della JVM più il risveglio del
> database. È il prezzo di non spendere $13,60 al mese per tenerlo sempre
> acceso. L'app lo maschera mandando un ping a vuoto all'apertura, così il
> server si scalda mentre scegli gli argomenti.

Il punto 4 chiama l'IA e consuma una delle generazioni giornaliere. Per un
controllo veloce che non consuma niente:

```bash
powershell -ExecutionPolicy Bypass -File scripts\verifica-deploy.ps1 -SaltaCreazione
```

Se i nomi delle risorse non sono quelli di default, passali:
`-NomeApp ca-<NOME> -GruppoRisorse <NOME_RG>`.

### 5.2 L'app vera punta al backend vero

Serve l'indirizzo vero. Leggilo:

```bash
az containerapp show --name ca-<NOME> --resource-group <NOME_RG> --query properties.configuration.ingress.fqdn -o tsv
```

Poi, sostituendo `<URL_BACKEND>` con `https://` seguito da quello che ha
stampato:

```bash
cd frontend && flutter build apk --release --dart-define=API_BASE_URL=<URL_BACKEND>
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

### `RequestDisallowedByAzure` — «best available regions»

Il messaggio parla di «un insieme delle regioni migliori disponibili»: significa
che la regione del gruppo di risorse non è fra quelle permesse alla tua
sottoscrizione. Non è un problema di quota né di capacità, ed è per questo che
l'errore non suggerisce niente di utile.

Trova quelle permesse:

```bash
az policy assignment list --query "[].{criterio:displayName, regioni:parameters.listOfAllowedLocations.value}" -o json
```

Poi ricrea il gruppo di risorse in una di quelle. Se avevi già provato a
distribuire, il gruppo esiste ma è vuoto o incompleto: cancellalo e rifallo,
non c'è niente da salvare.

```bash
az group delete --name <NOME_RG> --yes
```

```bash
az group create --name <NOME_RG> --location <REGIONE_PERMESSA>
```

E rilancia il passo 2.4. L'elenco è deciso da Microsoft, cambia da persona a
persona e non si modifica: l'unica via per aggiungerne è una richiesta al
supporto, che per questo progetto non vale la pena.

### PowerShell spezza il comando: «"password" non è riconosciuto come comando»

Succede quando un segreto con dentro `&` finisce su una riga di comando. Su
Windows `az` è un file `.cmd`: dopo PowerShell la riga viene riletta da
`cmd.exe`, che tratta `&` come separatore di comandi **anche dentro gli apici
singoli**. Il comando si spezza, i parametri dopo la prima `&` spariscono, e
`az` te li chiede in un prompt interattivo.

Non rispondere al prompt: premi Ctrl+C e usa il file dei segreti del passo 2.3.
È l'unica soluzione robusta — e ha il vantaggio che i segreti non restano nella
cronologia di PowerShell.

### `InvalidTemplate` — «parameters were supplied, but do not correspond»

Dentro `parameters`, ARM pretende che **ogni chiave corrisponda a un parametro
del template**: una nota o un campo di troppo fanno fallire tutto il deploy. Il
messaggio elenca la chiave incriminata e i parametri ammessi.

Le note vanno **fuori** da `parameters`, in cima al file, dove ARM le ignora —
è così che è fatto `infra/segreti.parameters.json.esempio`.

Controlla quali chiavi hai davvero, senza stampare i valori:

```bash
powershell -Command "(Get-Content infra\segreti.parameters.json -Raw | ConvertFrom-Json).parameters.PSObject.Properties.Name"
```

Devono essere esattamente cinque: `dbUrl`, `dbUsername`, `dbPassword`,
`geminiApiKey`, `groqApiKey`.

### Prima di distribuire: validare senza distribuire

`validate` fa controllare il template ad Azure **senza creare niente e senza
consumare credito**. Se stai modificando `infra/`, passa sempre di qui prima:

```bash
az deployment group validate --resource-group <NOME_RG> --template-file infra/main.bicep --parameters infra/main.parameters.json --parameters infra/segreti.parameters.json --query "properties.provisioningState" -o tsv
```

**Cosa devi vedere:** la parola `Succeeded`.

È più severo di `az bicep build`: quello controlla la sintassi, questo chiede ad
Azure se accetterebbe davvero quelle risorse. Due difetti di questa guida sono
stati trovati così e non compilando.

### «Please provide securestring value for 'dbUsername'»

Il file dei segreti non è stato letto, o ha campi vuoti. Ctrl+C, poi controlla:

```bash
type infra\segreti.parameters.json
```

Tutti e cinque i valori devono essere pieni, e il percorso passato con
`--parameters` deve puntare a questo file.

### «Impossibile risolvere il nome remoto»

Non è il servizio a essere spento: è l'indirizzo a non esistere. Quasi sempre
perché è stato composto a mano come `ca-<NOME>.<REGIONE>.azurecontainerapps.io`,
che **non è la forma giusta** — manca il sottodominio casuale dell'ambiente.

Chiedilo ad Azure:

```bash
az containerapp show --name ca-<NOME> --resource-group <NOME_RG> --query properties.configuration.ingress.fqdn -o tsv
```

Oppure lancia lo script di verifica senza `-BaseUrl`: se lo fa dire da solo.

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

Il valore è mascherato perché è un segreto: `az` non te lo mostra. Per
correggerlo, sistema `dbUrl` in `infra/segreti.parameters.json` e rilancia il
comando del passo 2.4.

L'altro caso possibile è il progetto Neon sospeso per inattività prolungata:
aprilo dalla console e si risveglia.

### HTTP 503 creando un tabellone

Il backend non riesce a generare domande. Due cause:

- **Chiavi LLM mancanti o scadute.** I log dicono «Generazione IA non
  configurata» oppure «Chiave Gemini non valida». Correggi `geminiApiKey` e
  `groqApiKey` in `infra/segreti.parameters.json` e rilancia il passo 2.4.
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

**Prezzi verificati il 20 agosto 2026** dall'API prezzi al dettaglio di Azure,
non dalla documentazione commerciale. Controllati in USD sia per `westeurope`
sia per `italynorth`: **vCPU e memoria costano identici**, e Italy North ha le
richieste perfino più basse ($0,40 per milione contro $0,56). I conti qui sotto
valgono per entrambe.

Le quote gratuite sono uguali in ogni regione. Per i numeri esatti di una
regione diversa:

```bash
az rest --method get --url "https://prices.azure.com/api/retail/prices?currencyCode=USD&\$filter=serviceName%20eq%20'Azure%20Container%20Apps'%20and%20armRegionName%20eq%20'<REGIONE>'" --query "Items[?contains(meterName,'Standard')].{voce:meterName, prezzo:retailPrice, unita:unitOfMeasure}" -o table
```

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
omettendo `appLogsConfiguration` in `infra/main.bicep`.

### Verificato sul campo, al primo tentativo

- **Le regioni sono ristrette, e West Europe può non esserci.** Il primo deploy
  reale è fallito con `RequestDisallowedByAzure` su `westeurope`. Da qui il
  passo 2.2, che va fatto prima di scegliere qualunque cosa.
- **I segreti sulla riga di comando si rompono su Windows.** Le `&` della
  stringa Neon sono state interpretate da `cmd.exe` anche dentro gli apici
  singoli: il comando si è spezzato a metà, i parametri successivi sono
  spariti e `az` ha cominciato a chiederli in un prompt interattivo. Da qui il
  file dei segreti del passo 2.3.
- **Il template aveva un difetto vero.** La soglia della regola di scala era
  fuori da `metadata`: Bicep la accettava con l'avviso `BCP037` e ARM l'avrebbe
  ignorata in silenzio. Corretta.

- **I due template Bicep compilano puliti** (`az bicep build`) e **passano la
  validazione lato Azure** contro questa sottoscrizione
  (`az deployment group validate` e `az deployment sub validate`): `Succeeded`
  entrambi, senza creare risorse.
- **Container Apps è disponibile in tutte e cinque le regioni permesse** da
  questa sottoscrizione, `italynorth` compresa.
- **Il deploy è andato a fondo, e il backend risponde.** Verificato il 21 agosto
  2026 su `italynorth`: liveness, database Neon raggiungibile in TLS con le
  migrazioni applicate, rotte protette che chiedono ancora `X-Client-Id`.
  **Avvio a freddo misurato: 31 secondi** sul primo risveglio reale, contro i
  24 misurati in locale — la differenza è il risveglio del database.
- **L'indirizzo del servizio non è componibile.** Contiene un sottodominio
  casuale assegnato all'ambiente
  (`ca-jeopardy.agreeablepebble-31d3ba21.italynorth.…`), e va sempre chiesto ad
  Azure. Lo script di verifica ora lo fa da sé.
- **Il nome dell'immagine deve essere minuscolo.** `github.repository_owner`
  restituisce `Yamino00` con le maiuscole e la build fallisce con «repository
  name must be lowercase». Il workflow lo abbassa in un passo dedicato.
- **Il soggetto della credenziale federata dipende dall'ambiente, non dal ramo.**
  Il workflow dichiara `environment: azure`, quindi GitHub manda
  `…:environment:azure` e non `…:ref:refs/heads/main`. La prima stesura di
  questa guida usava la forma col ramo — quella dei tutorial, che presuppongono
  un job senza ambiente.
- **E porta anche gli ID immutabili.** Dal 15 luglio 2026 i repository nuovi
  attaccano l'ID numerico a proprietario e repository, così un nome riciclato
  non eredita la fiducia del precedente. Il soggetto reale di questo repository
  è `repo:Yamino00@205906705/Jeopardy@1334456979:environment:azure`, verificato
  contro gli ID letti dall'API di GitHub. Nessun tutorial scritto prima di
  quella data lo menziona.
- **La destinazione dei log non si scrive `'none'`.** Il messaggio di Azure
  («Supported values: 'log-analytics', 'azure-monitor' or none») sembra dire il
  contrario, ma quel «none» significa *nessun valore*: la proprietà
  `appLogsConfiguration` va **omessa**. Trovato dalla validazione, non dalla
  compilazione.

### Cose che restano non verificate

- **La forma esatta di `az consumption budget list`** nella versione corrente
  della CLI: quel gruppo di comandi si è spostato più volte. Il percorso nel
  portale è indicato al passo 3 come alternativa.
- **La franchigia sul traffico in uscita.** Il nostro traffico è JSON,
  dell'ordine dei megabyte al mese: qualunque sia la franchigia ci stiamo
  dentro, ma non l'ho verificata.
- **Il deploy vero non è ancora andato a fondo**: il primo tentativo si è
  fermato sulla regione. Che il template descriva risorse valide è verificato,
  che Azure le accetti tutte lo si vede al passo 2.4.
