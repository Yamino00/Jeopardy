package it.quiz.jeopardy.banca;

import it.quiz.jeopardy.comune.ResourceNotFoundException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class SegnalazioneService {

    private final SegnalazioneRepository segnalazioneRepository;
    private final DomandaRepository domandaRepository;
    private final int sogliaSegnalazioni;

    public SegnalazioneService(SegnalazioneRepository segnalazioneRepository,
                               DomandaRepository domandaRepository,
                               @Value("${app.banca.soglia-segnalazioni:3}") int sogliaSegnalazioni) {
        this.segnalazioneRepository = segnalazioneRepository;
        this.domandaRepository = domandaRepository;
        this.sogliaSegnalazioni = sogliaSegnalazioni;
    }

    /**
     * Records the report and flips the question to 'segnalata' once the
     * counter goes beyond the threshold (default 3).
     */
    @Transactional
    public SegnalazioneDto segnala(UUID clientId, Long domandaId,
                                   MotivoSegnalazione motivo, String nota) {
        Domanda domanda = domandaRepository.findById(domandaId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Domanda " + domandaId + " non trovata"));

        Segnalazione segnalazione = new Segnalazione();
        segnalazione.setDomanda(domanda);
        segnalazione.setClientId(clientId);
        segnalazione.setMotivo(motivo);
        segnalazione.setNota(nota);
        segnalazioneRepository.save(segnalazione);

        domanda.setSegnalazioni(domanda.getSegnalazioni() + 1);
        if (domanda.getSegnalazioni() > sogliaSegnalazioni
                && domanda.getStato() == StatoDomanda.ATTIVA) {
            domanda.setStato(StatoDomanda.SEGNALATA);
        }
        return new SegnalazioneDto(segnalazione.getId(), domandaId,
                motivo, domanda.getSegnalazioni(), domanda.getStato().dbValue());
    }

    public record SegnalazioneDto(
            Long id,
            Long domandaId,
            MotivoSegnalazione motivo,
            int segnalazioniTotali,
            String statoDomanda) {
    }
}
