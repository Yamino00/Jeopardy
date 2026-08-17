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
     * Registers one generation for the client, or throws
     * {@link QuotaExceededException} if the daily quota is exhausted.
     * Runs in its own transaction so the counter survives a later rollback.
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
}
