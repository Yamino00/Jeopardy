# Quello che devi fare tu

Solo le cose che richiedono te, in ordine di quando servono. Tutto il resto —
`Dockerfile`, profilo di produzione, infrastruttura come codice, workflow,
script di verifica — è già nel repository e non chiede niente.

I passi tra parentesi rimandano a [DEPLOY_AZURE.md](DEPLOY_AZURE.md).

## Prima di poter fare qualunque altra cosa

Questi tre **bloccano tutto il resto**: finché non sono fatti, nessun comando
della guida è eseguibile.

| Cosa | Perché | Quanto tempo |
|---|---|---|
| **Verificare lo status studente e attivare Azure for Students** (1.1) | Senza sottoscrizione non esiste niente su cui distribuire. Serve un'email istituzionale: la verifica passa da lì e non c'è modo di aggirarla. **Se l'ateneo non viene riconosciuto, il progetto si ferma qui** finché non lo risolve il supporto Microsoft. | 10 min, più l'attesa della verifica |
| **Installare la CLI di Azure** (1.2) | Non è installata: l'ho verificato. Ogni comando della guida comincia con `az`. Ricordati di riaprire il terminale dopo. | 5 min |
| **Creare il progetto Neon** (2.1) | Il database sta fuori da Azure, ed è la scelta che tiene il conto a zero: su Azure costerebbe oltre $15 al mese contro un budget di $8. Ti servono la stringa JDBC, l'utente e la password. | 10 min |

## Setup, una volta sola

| Cosa | Perché | Quanto tempo |
|---|---|---|
| **Registrare i provider `Microsoft.App` e `Microsoft.OperationalInsights`** (1.4) | Azure tiene disattivati i servizi mai usati. Senza, il passo 2.2 fallisce con un errore che non dice quale sia il problema. | 5 min, quasi tutti di attesa |
| **Creare gruppo di risorse, ambiente e servizio** (2.2) | È il deploy dell'infrastruttura. Un solo comando, rieseguibile. **È anche il momento in cui si scopre** se Container Apps sia disponibile sulla tua sottoscrizione: non ho potuto verificarlo in anticipo. | 10 min |
| **Impostare gli avvisi di budget al 50% e all'80%** (3) | Quando il credito finisce Azure **disabilita l'intera sottoscrizione**, non manda una bolletta. Gli avvisi automatici di Azure arrivano al 90% del credito totale: troppo tardi e sulla grandezza sbagliata. **Non rimandarlo a dopo il primo deploy.** | 5 min |
| **Rendere pubblico il pacchetto su ghcr.io** (4.1) | Perché Azure possa scaricare l'immagine senza credenziali. Si fa una volta, dal browser, dopo il primo push. L'immagine non contiene segreti. | 2 min |
| **Configurare la federazione OIDC per GitHub Actions** (2.3) | Permette al workflow di aggiornare il servizio senza salvare password. **Facoltativo**: se il tuo tenant universitario non ti lascia creare identità applicative, salta e usa il deploy manuale (4.2), che fa la stessa cosa. | 15 min |

## A ogni rilascio

| Cosa | Perché | Quanto tempo |
|---|---|---|
| **Lanciare il workflow di deploy** (4.1) | Un comando: `gh workflow run "Deploy backend su Azure"`. Test, immagine, pubblicazione e aggiornamento del servizio. | 1 min tuo, 5-8 di attesa |
| **Lanciare lo script di verifica** (5.1) | È quello che dice se ha funzionato davvero, invece di lasciartelo indovinare. Misura anche l'avvio a freddo e il margine sul tetto di tempo della generazione. | 2 min |
| **Ricostruire l'APK con `--dart-define`** (5.2) | Solo quando cambia l'indirizzo del backend. Senza, l'app parla con `localhost` e non funziona niente. | 5 min |

## Ogni tanto

| Cosa | Perché | Quanto tempo |
|---|---|---|
| **Controllare il credito residuo** | `az consumption usage list --query "[].{risorsa:instanceName, costo:pretaxCost}" -o table`. Se compare qualcosa che non è la Container App, è arrivato qualcosa che non avevi previsto. | 1 min al mese |
| **Controllare che le chiavi LLM siano ancora valide** | I modelli si dismettono e le chiavi dei free tier scadono. Il sintomo è un 503 in creazione tabellone. | quando serve |

## Il giorno in cui qualcosa va storto

| Cosa | Perché | Quanto tempo |
|---|---|---|
| **Fermare il consumo senza cancellare** (7) | `az containerapp update ... --max-replicas 0`. Il servizio resta in piedi ma non risponde e non consuma. Reversibile con un comando. | 1 min |
| **Cancellare tutto** (7) | `az group delete --name <NOME_RG> --yes`, poi `az group exists` per essere sicuro. Non si torna indietro. Il progetto Neon è fuori da Azure e va cancellato a parte. | 5 min |
