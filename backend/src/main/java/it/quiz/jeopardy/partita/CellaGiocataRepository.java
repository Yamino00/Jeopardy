package it.quiz.jeopardy.partita;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface CellaGiocataRepository extends JpaRepository<CellaGiocata, CellaGiocataId> {

    List<CellaGiocata> findByPartitaIdOrderByGiocataIlAsc(Long partitaId);
}
