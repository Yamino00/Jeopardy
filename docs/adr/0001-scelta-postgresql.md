# ADR 0001 - Scelta PostgreSQL

## Stato
Accettata

## Contesto
Il progetto richiede un database relazionale affidabile, open source e compatibile con free tier cloud e sviluppo locale senza costi fissi.

## Decisione
Usiamo PostgreSQL come database principale per backend e migrazioni Flyway.

## Conseguenze
- SQL standard e supporto maturo per vincoli/indici
- Facilità di deploy su provider con piani gratuiti
- Stack locale semplice con Docker Compose
