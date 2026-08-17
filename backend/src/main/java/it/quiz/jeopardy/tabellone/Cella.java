package it.quiz.jeopardy.tabellone;

import it.quiz.jeopardy.banca.Domanda;
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

/**
 * A board cell. Text edits made by the board owner go into the override
 * columns, NEVER into the shared {@link Domanda}.
 */
@Entity
@Table(name = "cella")
@Getter
@Setter
@NoArgsConstructor
public class Cella {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "categoria_id", nullable = false)
    private Categoria categoria;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "domanda_id")
    private Domanda domanda;

    @Column(nullable = false)
    private short riga;

    @Column(nullable = false)
    private int valore;

    @Column(name = "testo_override")
    private String testoOverride;

    @Column(name = "risposta_override")
    private String rispostaOverride;

    @Column(name = "daily_double", nullable = false)
    private boolean dailyDouble;

    /** The text shown to players: override wins over the shared question. */
    public String testoEffettivo() {
        if (testoOverride != null) {
            return testoOverride;
        }
        return domanda == null ? null : domanda.getTesto();
    }

    public String rispostaEffettiva() {
        if (rispostaOverride != null) {
            return rispostaOverride;
        }
        return domanda == null ? null : domanda.getRisposta();
    }
}
