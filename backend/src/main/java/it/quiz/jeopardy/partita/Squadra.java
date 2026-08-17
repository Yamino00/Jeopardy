package it.quiz.jeopardy.partita;

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
 * A team: name, color, score. No account, no name uniqueness, removable
 * mid-game (soft delete on {@code attiva} so the event log stays coherent).
 */
@Entity
@Table(name = "squadra")
@Getter
@Setter
@NoArgsConstructor
public class Squadra {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "partita_id", nullable = false)
    private Partita partita;

    @Column(nullable = false)
    private String nome;

    @Column(nullable = false)
    private int punteggio;

    private String colore;

    @Column(nullable = false)
    private short posizione;

    @Column(nullable = false)
    private boolean attiva = true;
}
