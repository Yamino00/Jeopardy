package it.quiz.jeopardy.partita;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;

public interface PartitaRepository extends JpaRepository<Partita, Long> {

    /**
     * Daily cleanup: expired games never concluded. Children (squadre, eventi,
     * celle giocate) are removed by the ON DELETE CASCADE at database level.
     */
    @Modifying
    @Query("""
            delete from Partita p
            where p.scadeIl < :ora and p.stato <> :conclusa
            """)
    int deleteScadute(@Param("ora") Instant ora,
                      @Param("conclusa") StatoPartita conclusa);
}
