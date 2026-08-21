// =====================================================================
// Avvisi di budget al 50% e all'80%.
//
// Non e' un extra. Con Azure for Students, quando il credito finisce Azure
// non manda una bolletta: **disabilita l'intera sottoscrizione**, non solo
// la risorsa costosa. Senza avvisi non c'e' nessun segnale prima del buio.
//
// Azure genera da se' avvisi al 90% e al 100% del credito complessivo, ma
// arrivano tardi e ragionano sul totale dei 12 mesi. Questi due ragionano
// sulla spesa del mese, che e' la grandezza che si puo' ancora correggere.
//
// Ambito: la sottoscrizione, non il gruppo di risorse — un budget legato al
// gruppo non vedrebbe una risorsa creata per sbaglio da un'altra parte, che
// e' esattamente il caso da cui ci si vuole proteggere.
//
// Si distribuisce con:
//   az deployment sub create --location <REGIONE> --template-file infra/budget.bicep \
//      --parameters email=<EMAIL_AVVISI>
// =====================================================================

targetScope = 'subscription'

@description('Dove arrivano gli avvisi.')
param email string

@description('Tetto mensile in dollari. 8 e il credito annuale spalmato sui 12 mesi.')
param tettoMensile int = 8

@description('Nome del budget.')
param nome string = 'budget-jeopardy'

@description('Inizio del periodo, primo del mese, formato aaaa-MM-01. Deve essere il mese corrente o uno futuro: Azure rifiuta una data passata.')
param inizio string = '${utcNow('yyyy-MM')}-01'

resource budget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: nome
  properties: {
    category: 'Cost'
    amount: tettoMensile
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: inizio
    }
    notifications: {
      // Al 50% c'e' ancora mezzo mese per capire cosa sta consumando.
      Avviso50: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        contactEmails: [email]
        thresholdType: 'Actual'
      }
      // All'80% e' il momento di spegnere qualcosa, non di indagare.
      Avviso80: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        contactEmails: [email]
        thresholdType: 'Actual'
      }
    }
  }
}

output nomeBudget string = budget.name
