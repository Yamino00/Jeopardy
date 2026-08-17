package it.quiz.jeopardy.partita;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface EventoPartitaRepository extends JpaRepository<EventoPartita, Long> {

    Optional<EventoPartita> findFirstByPartitaIdAndAnnullatoFalseOrderByIdDesc(Long partitaId);

    List<EventoPartita> findByPartitaIdOrderByIdAsc(Long partitaId);

    /**
     * The score, by definition: sum of deltas of non-cancelled events.
     */
    @Query("""
            select coalesce(sum(e.deltaPunti), 0) from EventoPartita e
            where e.partitaId = :partitaId
              and e.squadraId = :squadraId
              and e.annullato = false
            """)
    int sumDeltaBySquadra(@Param("partitaId") Long partitaId,
                          @Param("squadraId") Long squadraId);
}
