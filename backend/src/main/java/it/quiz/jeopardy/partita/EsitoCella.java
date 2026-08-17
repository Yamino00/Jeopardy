package it.quiz.jeopardy.partita;

import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Outcome of a played cell. Stored lowercase
 * (CHECK constraint on {@code cella_giocata.esito}).
 */
public enum EsitoCella {
    CORRETTA("corretta"),
    ERRATA("errata"),
    PASSATA("passata");

    private final String dbValue;

    EsitoCella(String dbValue) {
        this.dbValue = dbValue;
    }

    @JsonValue
    public String dbValue() {
        return dbValue;
    }

    public static EsitoCella fromDbValue(String value) {
        for (EsitoCella esito : values()) {
            if (esito.dbValue.equals(value)) {
                return esito;
            }
        }
        throw new IllegalArgumentException("Unknown esito: " + value);
    }
}
