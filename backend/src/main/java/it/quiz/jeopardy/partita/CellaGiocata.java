package it.quiz.jeopardy.partita;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

/**
 * Marks a cell as played within a game. The PK (partita, cella) makes a
 * double play impossible; undo deletes the row so the cell can be replayed.
 */
@Entity
@Table(name = "cella_giocata")
@IdClass(CellaGiocataId.class)
@Getter
@Setter
@NoArgsConstructor
public class CellaGiocata {

    @Id
    @Column(name = "partita_id")
    private Long partitaId;

    @Id
    @Column(name = "cella_id")
    private Long cellaId;

    @Column(name = "squadra_id")
    private Long squadraId;

    private EsitoCella esito;

    @Column(name = "giocata_il", nullable = false)
    private Instant giocataIl = Instant.now();

    public CellaGiocata(Long partitaId, Long cellaId, Long squadraId, EsitoCella esito) {
        this.partitaId = partitaId;
        this.cellaId = cellaId;
        this.squadraId = squadraId;
        this.esito = esito;
    }
}
