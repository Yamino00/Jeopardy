package it.quiz.jeopardy.ia;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Audit row for each LLM call: how many questions were requested, how many
 * survived deduplication, token usage and estimated cost.
 */
@Entity
@Table(name = "generazione")
@Getter
@Setter
@NoArgsConstructor
public class Generazione {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "argomento_id")
    private Long argomentoId;

    @Column(name = "client_id")
    private UUID clientId;

    private String modello;

    private Short richieste;

    private Short accettate;

    @Column(name = "token_input")
    private Integer tokenInput;

    @Column(name = "token_output")
    private Integer tokenOutput;

    @Column(name = "costo_stimato", precision = 10, scale = 6)
    private BigDecimal costoStimato;

    @Column(name = "creato_il", nullable = false)
    private Instant creatoIl = Instant.now();
}
