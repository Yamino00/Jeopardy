package it.quiz.jeopardy.partita;

import it.quiz.jeopardy.tabellone.Tabellone;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * An ephemeral play-through of a board. Teams are children in CASCADE and die
 * with it. {@code turnoSquadraId} is a raw FK on purpose: a bidirectional
 * relation with Squadra would create a mapping cycle.
 */
@Entity
@Table(name = "partita")
@Getter
@Setter
@NoArgsConstructor
public class Partita {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "tabellone_id", nullable = false)
    private Tabellone tabellone;

    @Column(name = "codice_sessione")
    private String codiceSessione;

    @Column(nullable = false)
    private StatoPartita stato = StatoPartita.IN_CORSO;

    @Column(name = "turno_squadra_id")
    private Long turnoSquadraId;

    @Column(name = "iniziata_il", nullable = false)
    private Instant iniziataIl = Instant.now();

    @Column(name = "conclusa_il")
    private Instant conclusaIl;

    @Column(name = "scade_il", nullable = false)
    private Instant scadeIl;

    @OneToMany(mappedBy = "partita", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("posizione ASC, id ASC")
    private List<Squadra> squadre = new ArrayList<>();

    public void addSquadra(Squadra squadra) {
        squadra.setPartita(this);
        squadre.add(squadra);
    }
}
