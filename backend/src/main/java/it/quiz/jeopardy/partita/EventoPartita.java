package it.quiz.jeopardy.partita;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.Map;

/**
 * Append-only game log. The score of a team is by definition the sum of
 * {@code deltaPunti} of its non-cancelled events: undo flips
 * {@code annullato} and recomputes from here.
 */
@Entity
@Table(name = "evento_partita")
@Getter
@Setter
@NoArgsConstructor
public class EventoPartita {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "partita_id", nullable = false)
    private Long partitaId;

    @Column(name = "squadra_id")
    private Long squadraId;

    @Column(nullable = false)
    private TipoEvento tipo;

    @Column(name = "delta_punti")
    private Integer deltaPunti;

    @JdbcTypeCode(SqlTypes.JSON)
    private Map<String, Object> payload;

    @Column(nullable = false)
    private boolean annullato;

    @Column(name = "creato_il", nullable = false)
    private Instant creatoIl = Instant.now();
}
