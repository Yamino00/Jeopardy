package it.quiz.jeopardy.partita;

import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Kind of game-log entry. Only events carrying {@code delta_punti} affect the
 * score, which must always be derivable from the non-cancelled events.
 */
public enum TipoEvento {
    CELLA_GIOCATA("cella_giocata"),
    CORREZIONE("correzione");

    private final String dbValue;

    TipoEvento(String dbValue) {
        this.dbValue = dbValue;
    }

    @JsonValue
    public String dbValue() {
        return dbValue;
    }

    public static TipoEvento fromDbValue(String value) {
        for (TipoEvento tipo : values()) {
            if (tipo.dbValue.equals(value)) {
                return tipo;
            }
        }
        throw new IllegalArgumentException("Unknown tipo evento: " + value);
    }
}
