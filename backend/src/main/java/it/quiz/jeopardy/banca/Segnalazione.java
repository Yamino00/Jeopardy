package it.quiz.jeopardy.banca;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/**
 * A user report on a shared question. Past the threshold the question's
 * state flips to 'segnalata' and it stops being selected for new boards.
 */
@Entity
@Table(name = "segnalazione")
@Getter
@Setter
@NoArgsConstructor
public class Segnalazione {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "domanda_id", nullable = false)
    private Domanda domanda;

    @Column(name = "client_id")
    private UUID clientId;

    private MotivoSegnalazione motivo;

    private String nota;

    @Column(name = "creato_il", nullable = false)
    private Instant creatoIl = Instant.now();
}
