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

CREATE UNIQUE INDEX ux_domanda_entita
    ON domanda (argomento_id, entita_canonica)
    WHERE stato <> 'ritirata';

-- CHANGED: was global, now per-argomento
CREATE UNIQUE INDEX ux_domanda_hash ON domanda (argomento_id, hash_testo);

CREATE INDEX ix_domanda_selezione
    ON domanda (argomento_id, difficolta, stato)
    INCLUDE (sotto_argomento);

CREATE INDEX ix_domanda_trgm ON domanda USING gin (testo gin_trgm_ops);

CREATE VIEW copertura AS
SELECT argomento_id, sotto_argomento, difficolta, count(*) AS n
FROM domanda
WHERE stato = 'attiva'
GROUP BY argomento_id, sotto_argomento, difficolta;
