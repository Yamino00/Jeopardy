package it.quiz.jeopardy.tabellone;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * A saved, reusable board: 5-6 categories by N rows. Identified by a public
 * code (to play) and a secret edit code. No owner: only the anonymous UUID
 * of the creator.
 */
@Entity
@Table(name = "tabellone")
@Getter
@Setter
@NoArgsConstructor
public class Tabellone {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "codice_pubblico", nullable = false)
    private String codicePubblico;

    @Column(name = "codice_modifica", nullable = false)
    private String codiceModifica;

    @Column(nullable = false)
    private String titolo;

    @Column(name = "client_creatore", nullable = false)
    private UUID clientCreatore;

    @Column(nullable = false)
    private short righe = 5;

    @Column(name = "punti_base", nullable = false)
    private int puntiBase = 200;

    @Column(nullable = false)
    private boolean pubblico;

    @Column(name = "creato_il", nullable = false)
    private Instant creatoIl = Instant.now();

    @Column(name = "ultimo_uso_il")
    private Instant ultimoUsoIl;

    @OneToMany(mappedBy = "tabellone", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("posizione ASC")
    private List<Categoria> categorie = new ArrayList<>();

    public void addCategoria(Categoria categoria) {
        categoria.setTabellone(this);
        categorie.add(categoria);
    }
}
