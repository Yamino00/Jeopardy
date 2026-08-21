# Jeopardy Monorepo Skeleton

Monorepo per applicazione quiz a griglia stile Jeopardy con backend Spring Boot e frontend Flutter.

## Struttura

- `/backend`: API Spring Boot 3.3+, Java 21, Maven
- `/frontend`: app Flutter 3.x con Riverpod + GoRouter + Dio
- `/db/migration`: migrazioni Flyway
- `/docs/adr`: decisioni architetturali

## Prerequisiti

- Java 21
- Maven 3.9+
- Flutter 3.x stabile
- PostgreSQL 15+ (locale via Docker consigliato)

## Variabili d'ambiente backend

- `DB_URL`
- `DB_USERNAME`
- `DB_PASSWORD`

## Avvio locale

1. Avvia DB:
   ```bash
   docker compose up -d
   ```
2. Backend:
   ```bash
   cd backend
   mvn spring-boot:run -Dspring-boot.run.profiles=dev
   ```
3. Frontend:
   ```bash
   cd frontend
   flutter pub get
   flutter run -d web-server
   ```

## Verifica compilazione

- Backend:
  ```bash
  cd backend
  mvn verify
  ```
- Frontend:
  ```bash
  cd frontend
  flutter analyze
  ```

## Deploy

Il backend gira su Azure Container Apps con scale-to-zero e il database su Neon,
fuori da Azure: costo atteso $0,00 al mese entro le quote gratuite.

- [docs/DEPLOY_AZURE.md](docs/DEPLOY_AZURE.md) — la procedura completa, comando
  per comando
- [docs/AZURE_INTERVENTI.md](docs/AZURE_INTERVENTI.md) — solo quello che
  richiede una persona, in ordine di quando serve
- `infra/` — infrastruttura come codice (Bicep)
- `scripts/verifica-deploy.ps1` — dice se il deploy ha funzionato davvero

L'APK di release va costruito indicando il backend, altrimenti punta a
`localhost`:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<indirizzo-del-backend>
```

## Decisioni architetturali principali

- Identità client anonima tramite UUID persistito lato client (`X-Client-Id`)
- Schema DB gestito solo via Flyway (`ddl-auto: validate`)
- Nessun account utente / nessuna autenticazione applicativa
- Feature-first package structure su backend e frontend
