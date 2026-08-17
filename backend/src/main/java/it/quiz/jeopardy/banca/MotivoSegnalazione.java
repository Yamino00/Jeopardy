package it.quiz.jeopardy.banca;

import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Why a question was reported. Stored lowercase (see the CHECK constraint
 * on {@code segnalazione.motivo}); the same value is used on the wire.
 */
public enum MotivoSegnalazione {
    ERRATA("errata"),
    AMBIGUA("ambigua"),
    OFFENSIVA("offensiva"),
    DUPLICATA("duplicata");

    private final String dbValue;

    MotivoSegnalazione(String dbValue) {
        this.dbValue = dbValue;
    }

    @JsonValue
    public String dbValue() {
        return dbValue;
    }

    public static MotivoSegnalazione fromDbValue(String value) {
        for (MotivoSegnalazione motivo : values()) {
            if (motivo.dbValue.equals(value)) {
                return motivo;
            }
        }
        throw new IllegalArgumentException("Unknown motivo: " + value);
    }
}
