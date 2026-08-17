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
