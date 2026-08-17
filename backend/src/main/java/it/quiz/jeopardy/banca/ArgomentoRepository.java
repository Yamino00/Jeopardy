package it.quiz.jeopardy.banca;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface ArgomentoRepository extends JpaRepository<Argomento, Long> {

    Optional<Argomento> findBySlugAndLingua(String slug, String lingua);
}
