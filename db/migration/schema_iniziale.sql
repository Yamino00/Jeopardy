-- ============================================================
-- App quiz stile Jeopardy con generazione IA
-- PostgreSQL 15+
-- ============================================================

CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================
-- 1. BANCA DOMANDE  (persistente, condivisa fra tutti)
-- ============================================================

CREATE TABLE argomento (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome            TEXT        NOT NULL,
    slug            TEXT        NOT NULL,
    lingua          CHAR(2)     NOT NULL DEFAULT 'it',
    creato_il       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_argomento_slug UNIQUE (slug, lingua)
);

CREATE TABLE domanda (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    argomento_id     BIGINT      NOT NULL REFERENCES argomento(id),
    sotto_argomento  TEXT,
    testo            TEXT        NOT NULL,
    risposta         TEXT        NOT NULL,
    entita_canonica  TEXT        NOT NULL,
    hash_testo       BYTEA       NOT NULL,
    difficolta       SMALLINT    NOT NULL CHECK (difficolta BETWEEN 1 AND 5),
    lingua           CHAR(2)     NOT NULL DEFAULT 'it',
    modello          TEXT,
    stato            TEXT        NOT NULL DEFAULT 'attiva'
                     CHECK (stato IN ('attiva','segnalata','ritirata')),
    volte_usata      INT         NOT NULL DEFAULT 0,
    segnalazioni     INT         NOT NULL DEFAULT 0,
    creata_il        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Vincolo anti-duplicazione principale: una sola domanda per
-- (argomento, risposta canonica). Le ritirate non occupano lo slot.
CREATE UNIQUE INDEX ux_domanda_entita
    ON domanda (argomento_id, entita_canonica)
    WHERE stato <> 'ritirata';

-- Rete di sicurezza: testo identico anche fra argomenti diversi
CREATE UNIQUE INDEX ux_domanda_hash ON domanda (hash_testo);

-- Selezione celle del tabellone
CREATE INDEX ix_domanda_selezione
    ON domanda (argomento_id, difficolta, stato)
    INCLUDE (sotto_argomento);

-- Fallback opzionale: similarita testuale entro lo stesso argomento
CREATE INDEX ix_domanda_trgm ON domanda USING gin (testo gin_trgm_ops);

-- Matrice di copertura: alimenta i prompt mirati
CREATE VIEW copertura AS
SELECT argomento_id, sotto_argomento, difficolta, count(*) AS n
FROM domanda
WHERE stato = 'attiva'
GROUP BY argomento_id, sotto_argomento, difficolta;

-- ============================================================
-- 2. TABELLONE  (artefatto salvato e riusabile)
-- ============================================================

CREATE TABLE tabellone (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codice_pubblico  TEXT        NOT NULL UNIQUE,
    codice_modifica  TEXT        NOT NULL,
    titolo           TEXT        NOT NULL,
    client_creatore  UUID        NOT NULL,
    righe            SMALLINT    NOT NULL DEFAULT 5,
    punti_base       INT         NOT NULL DEFAULT 200,
    pubblico         BOOLEAN     NOT NULL DEFAULT false,
    creato_il        TIMESTAMPTZ NOT NULL DEFAULT now(),
    ultimo_uso_il    TIMESTAMPTZ
);

CREATE INDEX ix_tabellone_client ON tabellone (client_creatore, creato_il DESC);

CREATE TABLE categoria (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tabellone_id  BIGINT   NOT NULL REFERENCES tabellone(id) ON DELETE CASCADE,
    argomento_id  BIGINT            REFERENCES argomento(id),
    nome_display  TEXT     NOT NULL,
    posizione     SMALLINT NOT NULL,
    CONSTRAINT ux_categoria_pos UNIQUE (tabellone_id, posizione)
);

-- domanda_id NULL + override valorizzati = cella scritta a mano dall'host.
-- Gli override evitano di sporcare la banca condivisa con modifiche locali.
CREATE TABLE cella (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    categoria_id       BIGINT   NOT NULL REFERENCES categoria(id) ON DELETE CASCADE,
    domanda_id         BIGINT            REFERENCES domanda(id),
    riga               SMALLINT NOT NULL,
    valore             INT      NOT NULL,
    testo_override     TEXT,
    risposta_override  TEXT,
    daily_double       BOOLEAN  NOT NULL DEFAULT false,
    CONSTRAINT ux_cella_riga UNIQUE (categoria_id, riga),
    CONSTRAINT ck_cella_contenuto
        CHECK (domanda_id IS NOT NULL OR testo_override IS NOT NULL)
);

CREATE INDEX ix_cella_domanda ON cella (domanda_id);

-- ============================================================
-- 3. PARTITA E SQUADRE  (effimere, nessun utente)
-- ============================================================

CREATE TABLE partita (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tabellone_id      BIGINT      NOT NULL REFERENCES tabellone(id) ON DELETE CASCADE,
    codice_sessione   TEXT        UNIQUE,
    stato             TEXT        NOT NULL DEFAULT 'in_corso'
                      CHECK (stato IN ('in_corso','conclusa','abbandonata')),
    turno_squadra_id  BIGINT,
    iniziata_il       TIMESTAMPTZ NOT NULL DEFAULT now(),
    conclusa_il       TIMESTAMPTZ,
    scade_il          TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '30 days'
);

CREATE INDEX ix_partita_scadenza ON partita (scade_il) WHERE stato <> 'conclusa';

-- Nessun vincolo di unicita sul nome: massima liberta all'host.
-- posizione e solo ordinamento, cosi aggiungere/rimuovere a meta
-- partita non richiede rinumerazioni.
CREATE TABLE squadra (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    partita_id  BIGINT   NOT NULL REFERENCES partita(id) ON DELETE CASCADE,
    nome        TEXT     NOT NULL,
    punteggio   INT      NOT NULL DEFAULT 0,
    colore      TEXT,
    posizione   SMALLINT NOT NULL DEFAULT 0,
    attiva      BOOLEAN  NOT NULL DEFAULT true
);

CREATE INDEX ix_squadra_partita ON squadra (partita_id, posizione);

ALTER TABLE partita
    ADD CONSTRAINT fk_partita_turno
    FOREIGN KEY (turno_squadra_id) REFERENCES squadra(id) ON DELETE SET NULL;

CREATE TABLE cella_giocata (
    partita_id  BIGINT      NOT NULL REFERENCES partita(id) ON DELETE CASCADE,
    cella_id    BIGINT      NOT NULL REFERENCES cella(id)   ON DELETE CASCADE,
    squadra_id  BIGINT               REFERENCES squadra(id) ON DELETE SET NULL,
    esito       TEXT        CHECK (esito IN ('corretta','errata','passata')),
    giocata_il  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (partita_id, cella_id)
);

-- Log append-only: rende banale l'annulla, che a un host serve sempre
CREATE TABLE evento_partita (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    partita_id    BIGINT      NOT NULL REFERENCES partita(id) ON DELETE CASCADE,
    squadra_id    BIGINT,
    tipo          TEXT        NOT NULL,
    delta_punti   INT,
    payload       JSONB,
    annullato     BOOLEAN     NOT NULL DEFAULT false,
    creato_il     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_evento_partita ON evento_partita (partita_id, id DESC);

-- ============================================================
-- 4. CONTROLLO COSTI E QUALITA
-- ============================================================

CREATE TABLE generazione (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    argomento_id  BIGINT REFERENCES argomento(id),
    client_id     UUID,
    modello       TEXT,
    richieste     SMALLINT,
    accettate     SMALLINT,
    token_input   INT,
    token_output  INT,
    costo_stimato NUMERIC(10,6),
    creato_il     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_generazione_giorno ON generazione (creato_il DESC);

-- Senza questo un singolo client puo bruciare il budget in un pomeriggio
CREATE TABLE quota_client (
    client_id        UUID     PRIMARY KEY,
    giorno           DATE     NOT NULL DEFAULT CURRENT_DATE,
    generazioni_oggi SMALLINT NOT NULL DEFAULT 0,
    bloccato         BOOLEAN  NOT NULL DEFAULT false
);

CREATE TABLE segnalazione (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    domanda_id  BIGINT      NOT NULL REFERENCES domanda(id) ON DELETE CASCADE,
    client_id   UUID,
    motivo      TEXT        CHECK (motivo IN ('errata','ambigua','offensiva','duplicata')),
    nota        TEXT,
    creato_il   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_segnalazione_domanda ON segnalazione (domanda_id);

-- ============================================================
-- 5. NORMALIZZAZIONE
-- ============================================================

-- ATTENZIONE: unaccent() e STABLE, non IMMUTABLE. Non usare questa
-- funzione dentro colonne generate o indici senza wrapparla.
-- Consigliato: calcolare entita_canonica e hash_testo in Java e
-- tenere questa versione solo per verifiche e backfill.
CREATE OR REPLACE FUNCTION normalizza(t TEXT) RETURNS TEXT AS $$
    SELECT regexp_replace(
             regexp_replace(
               regexp_replace(lower(unaccent(trim(t))),
                              '^(il|lo|la|i|gli|le|un|uno|una|l'')\s*', ''),
               '\s*\(.*\)\s*', ' ', 'g'),
             '[^a-z0-9 ]', '', 'g');
$$ LANGUAGE sql STABLE;

-- ============================================================
-- 6. QUERY CHIAVE
-- ============================================================

-- Celle di una colonna, escludendo cio che il client ha gia usato.
-- Sostituisce la tabella "domande viste": l'informazione e gia
-- ricavabile dai tabelloni che ha creato.
/*
SELECT d.*
FROM domanda d
WHERE d.argomento_id = :argomento
  AND d.difficolta   = :difficolta
  AND d.stato        = 'attiva'
  AND NOT EXISTS (
        SELECT 1
        FROM cella c
        JOIN categoria cat ON cat.id = c.categoria_id
        JOIN tabellone t   ON t.id   = cat.tabellone_id
        WHERE c.domanda_id = d.id
          AND t.client_creatore = :client
  )
ORDER BY d.volte_usata ASC, random()
LIMIT 1;
*/

-- Celle scarse da riempire: alimenta i prompt mirati
/*
SELECT :argomento AS argomento_id, s.sotto_argomento, d.difficolta,
       COALESCE(c.n, 0) AS presenti
FROM (SELECT unnest(:sotto_argomenti::text[]) AS sotto_argomento) s
CROSS JOIN generate_series(1,5) AS d(difficolta)
LEFT JOIN copertura c
       ON c.argomento_id    = :argomento
      AND c.sotto_argomento = s.sotto_argomento
      AND c.difficolta      = d.difficolta
WHERE COALESCE(c.n, 0) < :soglia
ORDER BY presenti ASC;
*/

-- Blocklist da iniettare nel prompt (stringhe corte, poco costose)
/*
SELECT string_agg(entita_canonica, ', ')
FROM domanda
WHERE argomento_id = :argomento
  AND sotto_argomento = :sotto
  AND stato = 'attiva';
*/

-- Pulizia partite scadute (job schedulato)
/*
DELETE FROM partita WHERE scade_il < now() AND stato <> 'conclusa';
*/