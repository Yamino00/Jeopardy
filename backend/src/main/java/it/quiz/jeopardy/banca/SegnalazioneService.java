package it.quiz.jeopardy.banca;

import it.quiz.jeopardy.comune.ResourceNotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

@Service
public class SegnalazioneService {

    private static final Logger log = LoggerFactory.getLogger(SegnalazioneService.class);

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
     * Registra la segnalazione e, raggiunta la soglia, disattiva la domanda.
     *
     * Disattivare vuol dire {@link StatoDomanda#SEGNALATA}: la domanda smette
     * di essere pescata per i tabelloni nuovi e per le rigenerazioni, ma resta
     * visibile nei tabelloni gia' creati. E' deliberato: cancellarla davvero
     * svuoterebbe una cella in mezzo a una partita in corso, cioe' punirebbe
     * chi sta giocando per un difetto che non ha causato.
     *
     * <p>Due proprieta' su cui questo metodo si regge:
     * <ul>
     *   <li><b>una segnalazione per dispositivo</b>: la domanda e' condivisa da
     *       tutti i tabelloni, e tre tocchi dello stesso telefono non sono tre
     *       pareri. Un secondo invio dallo stesso client non conta e non e' un
     *       errore — restituisce lo stato corrente;</li>
     *   <li><b>il contatore si ricalcola</b> da {@code count(*)} invece di
     *       essere incrementato, cosi' non puo' divergere dalle righe vere.</li>
     * </ul>
     */
    @Transactional
    public SegnalazioneDto segnala(UUID clientId, Long domandaId,
                                   MotivoSegnalazione motivo, String nota) {
        Domanda domanda = domandaRepository.findByIdBloccando(domandaId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Domanda " + domandaId + " non trovata"));

        Optional<Segnalazione> gia =
                segnalazioneRepository.findFirstByDomandaIdAndClientId(domandaId, clientId);
        if (gia.isPresent()) {
            // Idempotente, non un conflitto: chi ritocca il pulsante ha gia'
            // ottenuto quello che voleva.
            return dto(gia.get(), domanda, true);
        }

        Segnalazione segnalazione = new Segnalazione();
        segnalazione.setDomanda(domanda);
        segnalazione.setClientId(clientId);
        segnalazione.setMotivo(motivo);
        segnalazione.setNota(nota);
        segnalazioneRepository.saveAndFlush(segnalazione);

        domanda.setSegnalazioni(segnalazioneRepository.countByDomandaId(domandaId));
        if (domanda.getSegnalazioni() >= sogliaSegnalazioni
                && domanda.getStato() == StatoDomanda.ATTIVA) {
            domanda.setStato(StatoDomanda.SEGNALATA);
            log.info("Domanda {} disattivata: {} segnalazioni su una soglia di {}",
                    domandaId, domanda.getSegnalazioni(), sogliaSegnalazioni);
        }
        return dto(segnalazione, domanda, false);
    }

    private SegnalazioneDto dto(Segnalazione segnalazione, Domanda domanda, boolean gia) {
        return new SegnalazioneDto(
                segnalazione.getId(),
                domanda.getId(),
                segnalazione.getMotivo(),
                domanda.getSegnalazioni(),
                sogliaSegnalazioni,
                domanda.getStato() != StatoDomanda.ATTIVA,
                gia,
                domanda.getStato().dbValue());
    }

    /**
     * @param segnalazioniTotali quante ne pesano sulla domanda, questa compresa
     * @param soglia             quante ne servono per disattivarla
     * @param disattivata        vero quando la domanda non verra' piu' pescata
     * @param giaSegnalata       vero se questo dispositivo l'aveva gia' segnalata
     */
    public record SegnalazioneDto(
            Long id,
            Long domandaId,
            MotivoSegnalazione motivo,
            int segnalazioniTotali,
            int soglia,
            boolean disattivata,
            boolean giaSegnalata,
            String statoDomanda) {
    }
}
