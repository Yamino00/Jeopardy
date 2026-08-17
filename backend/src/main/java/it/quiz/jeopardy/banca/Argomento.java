package it.quiz.jeopardy.banca;

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

/**
 * A quiz topic. Part of the shared, persistent question bank.
 */
@Entity
@Table(name = "argomento")
@Getter
@Setter
@NoArgsConstructor
public class Argomento {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String nome;

    @Column(nullable = false)
    private String slug;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(nullable = false, length = 2)
    private String lingua = "it";

    @Column(name = "creato_il", nullable = false)
    private Instant creatoIl = Instant.now();

    public Argomento(String nome, String slug) {
        this.nome = nome;
        this.slug = slug;
    }
}
