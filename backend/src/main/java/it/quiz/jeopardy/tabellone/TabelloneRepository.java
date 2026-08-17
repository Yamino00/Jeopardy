package it.quiz.jeopardy.tabellone;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface TabelloneRepository extends JpaRepository<Tabellone, Long> {

    Optional<Tabellone> findByCodicePubblico(String codicePubblico);

    boolean existsByCodicePubblico(String codicePubblico);

    List<Tabellone> findByClientCreatoreOrderByCreatoIlDesc(UUID clientCreatore);
}
