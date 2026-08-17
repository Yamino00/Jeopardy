package it.quiz.jeopardy.tabellone;

import it.quiz.jeopardy.banca.Argomento;
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

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "categoria")
@Getter
@Setter
@NoArgsConstructor
public class Categoria {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "tabellone_id", nullable = false)
    private Tabellone tabellone;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "argomento_id")
    private Argomento argomento;

    @Column(name = "nome_display", nullable = false)
    private String nomeDisplay;

    @Column(nullable = false)
    private short posizione;

    @OneToMany(mappedBy = "categoria", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("riga ASC")
    private List<Cella> celle = new ArrayList<>();

    public void addCella(Cella cella) {
        cella.setCategoria(this);
        celle.add(cella);
    }
}
