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
