package it.quiz.jeopardy.partita;

import java.io.Serializable;
import java.util.Objects;

/**
 * Composite key of {@code cella_giocata}: one play per cell per game.
 */
public class CellaGiocataId implements Serializable {

    private Long partitaId;
    private Long cellaId;

    public CellaGiocataId() {
    }

    public CellaGiocataId(Long partitaId, Long cellaId) {
        this.partitaId = partitaId;
        this.cellaId = cellaId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof CellaGiocataId that)) {
            return false;
        }
        return Objects.equals(partitaId, that.partitaId)
                && Objects.equals(cellaId, that.cellaId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(partitaId, cellaId);
    }
}
