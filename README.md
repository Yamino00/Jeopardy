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

## Decisioni architetturali principali

- Identità client anonima tramite UUID persistito lato client (`X-Client-Id`)
- Schema DB gestito solo via Flyway (`ddl-auto: validate`)
- Nessun account utente / nessuna autenticazione applicativa
- Feature-first package structure su backend e frontend
