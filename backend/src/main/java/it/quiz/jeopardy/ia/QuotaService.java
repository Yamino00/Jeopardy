package it.quiz.jeopardy.ia;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.UUID;

/**
 * Blocks a client beyond N LLM generations per day (default 20, configurable).
 * Only calls that actually reach the LLM consume quota: answers served from
 * the bank are free.
 */
@Service
public class QuotaService {

    private final QuotaClientRepository quotaClientRepository;
    private final int quotaGiornaliera;

    public QuotaService(QuotaClientRepository quotaClientRepository,
                        @Value("${app.ia.quota-giornaliera:20}") int quotaGiornaliera) {
        this.quotaClientRepository = quotaClientRepository;
        this.quotaGiornaliera = quotaGiornaliera;
    }

    /**
     * Controlla che una generazione sia ancora concessa <b>senza consumarla</b>.
     *
     * <p>Va chiamata prima di iniziare un lavoro lungo: un tabellone che non
     * potra' finire non deve nemmeno cominciare, altrimenti l'utente aspetta
     * un minuto per sentirsi dire di no. Non e' una prenotazione — fra questo
     * controllo e {@link #consumeGeneration} un'altra richiesta dello stesso
     * client puo' passare — ma per un uso con un dispositivo per volta la
     * differenza non si vede, e una prenotazione vera costerebbe un lock
     * tenuto per tutta la durata della chiamata all'LLM.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW, readOnly = true)
    public void verificaDisponibilita(UUID clientId) {
        quotaClientRepository.findById(clientId).ifPresent(quota -> {
            if (quota.isBloccato() || generazioniDiOggi(quota) >= quotaGiornaliera) {
                throw new QuotaExceededException(
                        "Quota giornaliera di generazioni esaurita (" + quotaGiornaliera + ")");
            }
        });
    }

    /**
     * Registers one generation for the client, or throws
     * {@link QuotaExceededException} if the daily quota is exhausted.
     * Runs in its own transaction so the counter survives a later rollback.
     *
     * <p>Va invocata <b>dopo</b> che l'LLM ha risposto, non prima: una
     * generazione che fallisce non ha prodotto niente, e farla pagare come se
     * avesse prodotto qualcosa significa che tre rigenerazioni sfortunate
     * bruciano tre delle venti generazioni del giorno senza dare una domanda.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void consumeGeneration(UUID clientId) {
        QuotaClient quota = quotaClientRepository.findById(clientId)
                .orElseGet(() -> new QuotaClient(clientId));

        LocalDate oggi = LocalDate.now();
        if (!oggi.equals(quota.getGiorno())) {
            quota.setGiorno(oggi);
            quota.setGenerazioniOggi((short) 0);
        }
        if (quota.isBloccato() || quota.getGenerazioniOggi() >= quotaGiornaliera) {
            throw new QuotaExceededException(
                    "Quota giornaliera di generazioni esaurita (" + quotaGiornaliera + ")");
        }
        quota.setGenerazioniOggi((short) (quota.getGenerazioniOggi() + 1));
        quotaClientRepository.save(quota);
    }

    /** Il contatore vale solo per il giorno che ha registrato: ieri non conta. */
    private static short generazioniDiOggi(QuotaClient quota) {
        return LocalDate.now().equals(quota.getGiorno()) ? quota.getGenerazioniOggi() : 0;
    }
}
