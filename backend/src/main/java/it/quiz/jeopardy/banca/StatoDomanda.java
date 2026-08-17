package it.quiz.jeopardy.banca;

/**
 * Lifecycle state of a question in the bank. The database stores the
 * lowercase Italian value (see the CHECK constraint on {@code domanda.stato}).
 */
public enum StatoDomanda {
    ATTIVA("attiva"),
    SEGNALATA("segnalata"),
    RITIRATA("ritirata");

    private final String dbValue;

    StatoDomanda(String dbValue) {
        this.dbValue = dbValue;
    }

    public String dbValue() {
        return dbValue;
    }

    public static StatoDomanda fromDbValue(String value) {
        for (StatoDomanda stato : values()) {
            if (stato.dbValue.equals(value)) {
                return stato;
            }
        }
        throw new IllegalArgumentException("Unknown stato: " + value);
    }
}
