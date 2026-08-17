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
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;

/**
 * A question in the shared bank. {@code entitaCanonica} and {@code hashTesto}
 * are always computed in Java via {@link it.quiz.jeopardy.comune.Normalizer},
 * never taken from the LLM.
 */
@Entity
@Table(name = "domanda")
@Getter
@Setter
@NoArgsConstructor
public class Domanda {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "argomento_id", nullable = false)
    private Argomento argomento;

    @Column(name = "sotto_argomento")
    private String sottoArgomento;

    @Column(nullable = false)
    private String testo;

    @Column(nullable = false)
    private String risposta;

    @Column(name = "entita_canonica", nullable = false)
    private String entitaCanonica;

    @Column(name = "hash_testo", nullable = false)
    private byte[] hashTesto;

    @Column(nullable = false)
    private short difficolta;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(nullable = false, length = 2)
    private String lingua = "it";

    private String modello;

    @Column(nullable = false)
    private StatoDomanda stato = StatoDomanda.ATTIVA;

    @Column(name = "volte_usata", nullable = false)
    private int volteUsata;

    @Column(nullable = false)
    private int segnalazioni;

    @Column(name = "creata_il", nullable = false)
    private Instant creataIl = Instant.now();
}
