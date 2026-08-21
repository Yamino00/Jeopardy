# Prontuario dei comandi

Tutto quello che serve dopo il primo deploy, con una riga che dice cosa fa.
Per il setup iniziale vedi [DEPLOY_AZURE.md](DEPLOY_AZURE.md).

**Indirizzo del backend** — chiedilo ad Azure, non comporlo a mente: contiene un
sottodominio casuale assegnato alla creazione dell'ambiente.

```bash
az containerapp show --name ca-jeopardy --resource-group rg-jeopardy --query properties.configuration.ingress.fqdn -o tsv
```

---

## Sviluppo in locale

Avvia il database in un container. Va fatto prima di tutto il resto.

```bash
docker compose up -d
```

Avvia il backend sul tuo PC, in ascolto su `localhost:8080`.

```bash
cd backend && mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

Avvia l'app sul telefono collegato o sull'emulatore, con hot reload.

```bash
cd frontend && flutter run
```

Spegne il database. I dati restano: vivono in un volume Docker.

```bash
docker compose down
```

Spegne il database **e cancella i dati**. Serve per ripartire da zero.

```bash
docker compose down -v
```

Log del database, in diretta.

```bash
docker compose logs -f postgres
```

---

## Test

Test del backend. Avviano da soli un PostgreSQL usa-e-getta: non serve
`docker compose`, serve solo che Docker sia acceso.

```bash
cd backend && ./mvnw test
```

Controllo statico e test del frontend.

```bash
cd frontend && flutter analyze && flutter test
```

Test che parlano col backend vero in locale. Esclusi di default: richiedono
`docker compose up -d` e la banca già popolata.

```bash
cd frontend && flutter test --tags e2e --run-skipped
```

---

## L'app sul telefono

APK di collaudo, veloce da costruire, parla con `localhost`.

```bash
cd frontend && flutter build apk --debug
```

APK definitivo, che parla col backend su Azure. **Il `--dart-define` non è
opzionale**: senza, l'app cerca `localhost` e non funziona niente.

```bash
cd frontend && flutter build apk --release --dart-define=API_BASE_URL=https://ca-jeopardy.agreeablepebble-31d3ba21.italynorth.azurecontainerapps.io
```

L'APK esce in `frontend/build/app/outputs/flutter-apk/app-release.apk`.

Elenca i dispositivi che Flutter vede.

```bash
flutter devices
```

Installa sul telefono collegato l'ultimo APK di release costruito.

```bash
cd frontend && flutter install --release
```

Misura i fotogrammi: è il modo per accorgersi di un'animazione che scatta, che a
occhio non si vede.

```bash
cd frontend && flutter run --profile
```

---

## Rilasciare una modifica al backend

Il workflow legge il codice **dal repository**: senza push rilascia la versione
di prima. Nell'ordine:

```bash
cd backend && ./mvnw test
```

```bash
git add -A && git commit -m "..." && git push
```

Lancia il deploy: test, costruzione dell'immagine, pubblicazione su ghcr.io,
aggiornamento del servizio.

```bash
gh workflow run "Deploy backend su Azure"
```

Segue l'esecuzione passo per passo.

```bash
gh run watch
```

Verifica che il backend risponda davvero, che raggiunga il database e che sappia
creare un tabellone. L'indirizzo se lo ricava da solo.

```bash
powershell -ExecutionPolicy Bypass -File scripts\verifica-deploy.ps1
```

Come sopra ma senza creare il tabellone di prova: non chiama l'IA e non consuma
quota.

```bash
powershell -ExecutionPolicy Bypass -File scripts\verifica-deploy.ps1 -SaltaCreazione
```

Elenca le ultime esecuzioni del workflow, con l'esito.

```bash
gh run list --workflow "Deploy backend su Azure" --limit 5
```

**Hai cambiato lo schema del database?** Aggiungi una migrazione
`V<n>__nome.sql` in `backend/src/main/resources/db/migration/`. Flyway la applica
all'avvio, da sola. Non modificare mai una migrazione già applicata: se ne
scrive una nuova.

**L'APK non va rifatto** per una modifica al backend: l'indirizzo non cambia.

---

## Guardare cosa succede su Azure

Log dell'applicazione, in diretta. **Non c'è storico**: vanno guardati mentre il
problema succede.

```bash
az containerapp logs show --name ca-jeopardy --resource-group rg-jeopardy --follow
```

Ultime 100 righe, senza restare in ascolto.

```bash
az containerapp logs show --name ca-jeopardy --resource-group rg-jeopardy --tail 100
```

Stato del servizio: quale versione gira e se è viva.

```bash
az containerapp revision list --name ca-jeopardy --resource-group rg-jeopardy --query "[].{revisione:name, attiva:properties.active, stato:properties.runningState, immagine:properties.template.containers[0].image}" -o table
```

Quante istanze sono accese adesso. **Zero è normale**: significa che nessuno sta
giocando e non stai pagando niente.

```bash
az containerapp replica list --name ca-jeopardy --resource-group rg-jeopardy -o table
```

Riavvia il servizio senza cambiare niente. Utile se è in uno stato strano.

```bash
az containerapp revision restart --name ca-jeopardy --resource-group rg-jeopardy --revision ca-jeopardy--v75jxqo
```

Il nome della revisione cambia a ogni deploy: se non è più quello, leggilo con
il comando dello stato qui sopra.

Quali variabili d'ambiente ha il servizio. I valori dei segreti restano
mascherati, si vedono solo i nomi.

```bash
az containerapp show --name ca-jeopardy --resource-group rg-jeopardy --query "properties.template.containers[0].env[].name" -o tsv
```

Che cosa c'è nel gruppo di risorse. **Devono essere due voci.** Se compare un
workspace Log Analytics sta consumando credito: cancellalo.

```bash
az resource list --resource-group rg-jeopardy --query "[].{tipo:type, nome:name}" -o table
```

---

## Cambiare configurazione o segreti

Vale per `infra/main.bicep` e per le chiavi in `infra/segreti.parameters.json`
(chiave LLM scaduta, password Neon ruotata).

Prima valida: fa controllare tutto ad Azure **senza creare niente e senza
consumare credito**. Deve stampare `Succeeded`.

```bash
az deployment group validate --resource-group rg-jeopardy --template-file infra/main.bicep --parameters infra/main.parameters.json --parameters infra/segreti.parameters.json --query "properties.provisioningState" -o tsv
```

Poi applica.

```bash
az deployment group create --resource-group rg-jeopardy --template-file infra/main.bicep --parameters infra/main.parameters.json --parameters infra/segreti.parameters.json
```

> Questo comando riporta l'immagine a `:latest`. Se l'ultimo deploy aveva un tag
> diverso, rilancia il workflow dopo.

Cambiare una singola impostazione senza toccare il resto — per esempio allargare
il tetto di tempo della generazione:

```bash
az containerapp update --name ca-jeopardy --resource-group rg-jeopardy --set-env-vars APP_TABELLONE_BUDGET_CREAZIONE_SECONDI=170
```

---

## Il database

Apre una sessione SQL sul database **locale**.

```bash
docker exec -it jeopardy-postgres psql -U jeopardy -d jeopardy
```

Quante domande ha la banca locale, argomento per argomento.

```bash
docker exec jeopardy-postgres psql -U jeopardy -d jeopardy -c "SELECT a.nome, count(d.id) FROM argomento a LEFT JOIN domanda d ON d.argomento_id=a.id GROUP BY a.nome ORDER BY 2 DESC;"
```

Riempie la banca locale con domande già pronte, per giocare senza chiamare l'IA.

```bash
docker exec -i jeopardy-postgres psql -U jeopardy -d jeopardy < scripts/seed-banca.sql
```

Il database di **produzione** sta su Neon, fuori da Azure: si guarda dalla sua
console, <https://console.neon.tech>. Per un backup, usando la stringa di
connessione senza il prefisso `jdbc:`:

```bash
docker run --rm postgres:16 pg_dump "<STRINGA_NEON_SENZA_JDBC>" > backup.sql
```

---

## Soldi

Quanto è stato speso, per risorsa. Deve restare vicino a zero: se compare
qualcosa che non è la Container App, è arrivato qualcosa che non avevi previsto.

```bash
az consumption usage list --query "[].{risorsa:instanceName, costo:pretaxCost}" -o table
```

Gli avvisi di budget configurati, al 50% e all'80%.

```bash
az consumption budget list --query "[].{nome:name, tetto:amount}" -o table
```

Se quel comando non esiste nella tua versione della CLI, guarda dal portale:
**Cost Management + Billing → Cost Management → Budgets**.

---

## Quando qualcosa va storto

| Sintomo | Da lanciare per primo |
|---|---|
| L'app non raggiunge il backend | `powershell -ExecutionPolicy Bypass -File scripts\verifica-deploy.ps1 -SaltaCreazione` |
| Il backend risponde ma sbaglia | `az containerapp logs show --name ca-jeopardy --resource-group rg-jeopardy --follow` |
| «Impossibile risolvere il nome remoto» | Il comando dell'indirizzo, in cima a questa pagina |
| Errore 503 creando un tabellone | Chiavi LLM: guarda i log, poi rifai «Cambiare configurazione» |
| Errore 504 creando un tabellone | Non è un guasto: la generazione ha superato i 150 s. Meno categorie, o riprova |
| Il deploy fallisce su GitHub | `gh run view --log-failed` |

La sezione 6 di [DEPLOY_AZURE.md](DEPLOY_AZURE.md) ha la diagnosi estesa di ogni
errore incontrato finora, con il rimedio.

---

## Fermare tutto

Smette di rispondere e di consumare, senza cancellare niente. Reversibile.

```bash
az containerapp update --name ca-jeopardy --resource-group rg-jeopardy --min-replicas 0 --max-replicas 0
```

Riaccende.

```bash
az containerapp update --name ca-jeopardy --resource-group rg-jeopardy --min-replicas 0 --max-replicas 2
```

Cancella **tutto** quello che c'è su Azure. Non si torna indietro. Il progetto
Neon è fuori da Azure e va cancellato a parte, dalla sua console.

```bash
az group delete --name rg-jeopardy --yes
```

Conferma che sia sparito davvero: deve stampare `false`.

```bash
az group exists --name rg-jeopardy
```
