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
