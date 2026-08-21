package it.quiz.jeopardy.banca;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface SegnalazioneRepository extends JpaRepository<Segnalazione, Long> {

    /**
     * Quante segnalazioni pesano su una domanda. Il contatore su
     * {@code domanda.segnalazioni} si ricalcola da qui invece di essere
     * incrementato a mano: cosi' resta vero anche se una riga viene cancellata.
     */
    int countByDomandaId(Long domandaId);

    /**
     * La segnalazione gia' inviata da questo dispositivo, se c'e'.
     *
     * E' quello che impedisce a un solo client di consumare da solo la soglia:
     * la domanda e' condivisa fra tutti, e tre tocchi dello stesso telefono non
     * sono tre pareri.
     */
    Optional<Segnalazione> findFirstByDomandaIdAndClientId(Long domandaId, UUID clientId);
}
