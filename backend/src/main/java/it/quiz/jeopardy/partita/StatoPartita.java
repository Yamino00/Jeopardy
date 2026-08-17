package it.quiz.jeopardy.partita;

import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Game lifecycle. Stored lowercase (CHECK constraint on {@code partita.stato}).
 */
public enum StatoPartita {
    IN_CORSO("in_corso"),
    CONCLUSA("conclusa"),
    ABBANDONATA("abbandonata");

    private final String dbValue;

    StatoPartita(String dbValue) {
        this.dbValue = dbValue;
    }

    @JsonValue
    public String dbValue() {
        return dbValue;
    }

    public static StatoPartita fromDbValue(String value) {
        for (StatoPartita stato : values()) {
            if (stato.dbValue.equals(value)) {
                return stato;
            }
        }
        throw new IllegalArgumentException("Unknown stato partita: " + value);
    }
}
