// =====================================================================
// Ambiente Container Apps + il servizio backend.
//
// Si distribuisce su un gruppo di risorse (vedi docs/DEPLOY_AZURE.md).
// Rieseguirlo e' sicuro: e' una descrizione dello stato voluto, non una
// sequenza di passi, quindi lanciarlo due volte non crea due ambienti.
//
// Quel che NON c'e', e non e' una dimenticanza:
//   - nessun workspace Log Analytics: l'ingestione dei log consuma credito
//     in silenzio, e con 8 dollari al mese non c'e' margine per una voce
//     che cresce da sola. Vedi `logsDestination` piu' sotto.
//   - nessun Container Registry: l'immagine sta su ghcr.io, che e' gratis.
//     ACR Basic costerebbe 0,167 dollari al giorno, cioe' 5 al mese: il 63%
//     del budget per conservare un file.
// =====================================================================

targetScope = 'resourceGroup'

@description('Prefisso dei nomi delle risorse, minuscolo e senza spazi.')
@minLength(3)
@maxLength(20)
param nome string

@description('Regione. West Europe e la piu vicina con Container Apps.')
param regione string = resourceGroup().location

@description('Immagine completa, per esempio ghcr.io/utente/jeopardy-backend:v1.')
param immagine string

@description('Stringa JDBC del database, con ?sslmode=require. Neon la rifiuta senza.')
@secure()
param dbUrl string

@description('Utente del database.')
@secure()
param dbUsername string

@description('Password del database.')
@secure()
param dbPassword string

@description('Chiave Gemini. Vuota per disattivare quel provider.')
@secure()
param geminiApiKey string = ''

@description('Chiave Groq. Vuota per disattivare quel provider.')
@secure()
param groqApiKey string = ''

@description('Origini CORS ammesse, separate da virgola. Vuoto = nessuna regola CORS, che e il valore giusto per un client Android.')
param corsAllowedOrigins string = ''

// Mezza vCPU con 1 GiB e la taglia piu piccola con memoria sufficiente a
// Spring Boot. La quota gratuita mensile (180.000 vCPU-secondi e 360.000
// GiB-secondi) a questa taglia copre 100 ore di servizio acceso.
var cpu = json('0.5')
var memoria = '1Gi'

resource ambiente 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${nome}'
  location: regione
  properties: {
    // La riga che tiene il conto a zero. Senza, Azure aggancia un workspace
    // Log Analytics e comincia a fatturare l'ingestione. I log restano
    // leggibili in diretta con `az containerapp logs show --follow`, ma non
    // c'e' storico: e' il compromesso, ed e' consapevole.
    appLogsConfiguration: {
      destination: 'none'
    }
  }
}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-${nome}'
  location: regione
  properties: {
    managedEnvironmentId: ambiente.id
    configuration: {
      ingress: {
        // Esterno: il client e un'app Android su una rete qualunque.
        external: true
        targetPort: 8080
        transport: 'auto'
        // HTTPS obbligatorio: l'APK di release non ha usesCleartextTraffic,
        // quindi una chiamata in chiaro fallirebbe sul telefono.
        allowInsecure: false
      }
      secrets: [
        { name: 'db-url', value: dbUrl }
        { name: 'db-username', value: dbUsername }
        { name: 'db-password', value: dbPassword }
        { name: 'gemini-api-key', value: geminiApiKey }
        { name: 'groq-api-key', value: groqApiKey }
      ]
    }
    template: {
      containers: [
        {
          name: 'backend'
          image: immagine
          resources: {
            cpu: cpu
            memory: memoria
          }
          env: [
            { name: 'SPRING_PROFILES_ACTIVE', value: 'prod' }
            { name: 'DB_URL', secretRef: 'db-url' }
            { name: 'DB_USERNAME', secretRef: 'db-username' }
            { name: 'DB_PASSWORD', secretRef: 'db-password' }
            { name: 'GEMINI_API_KEY', secretRef: 'gemini-api-key' }
            { name: 'GROQ_API_KEY', secretRef: 'groq-api-key' }
            { name: 'CORS_ALLOWED_ORIGINS', value: corsAllowedOrigins }
            // Il fuso della JVM sarebbe UTC: i cron configurati in ora
            // italiana scatterebbero due ore prima.
            { name: 'TZ', value: 'Europe/Rome' }
          ]
          probes: [
            {
              // Liveness: quando fallisce, il container viene riavviato.
              // Percio' interroga solo il processo e non il database, che
              // si sospende da solo dopo qualche minuto di inattivita'.
              type: 'Liveness'
              httpGet: {
                path: '/api/salute/vivo'
                port: 8080
              }
              initialDelaySeconds: 30
              periodSeconds: 30
              failureThreshold: 3
            }
            {
              // Readiness: se il database non risponde, niente traffico —
              // ma nessun riavvio.
              type: 'Readiness'
              httpGet: {
                path: '/api/salute/pronto'
                port: 8080
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              failureThreshold: 6
            }
            {
              // Startup: misurato, l'avvio a freddo su mezza vCPU richiede
              // circa 24 secondi con l'archivio CDS. Il tetto qui e' 150s
              // (30 x 5), largo abbastanza da non uccidere un avvio lento
              // su una macchina occupata.
              type: 'Startup'
              httpGet: {
                path: '/api/salute/vivo'
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 5
              failureThreshold: 30
            }
          ]
        }
      ]
      scale: {
        // Il numero piu' importante del file. A zero, un servizio fermo non
        // costa niente. A uno costerebbe circa 13,60 dollari al mese ai
        // prezzi West Europe: da solo sfonderebbe il budget.
        // Il prezzo di questa scelta e' l'avvio a freddo sulla prima
        // richiesta, che l'app mitiga con un ping di risveglio all'apertura.
        minReplicas: 0
        // Due repliche bastano: si gioca con un dispositivo per volta, e il
        // tetto serve solo a impedire che un errore moltiplichi la spesa.
        maxReplicas: 2
        rules: [
          {
            name: 'http'
            http: {
              concurrentRequests: '10'
            }
          }
        ]
      }
    }
  }
}

@description('Indirizzo del backend, da passare a --dart-define=API_BASE_URL.')
output url string = 'https://${app.properties.configuration.ingress.fqdn}'
