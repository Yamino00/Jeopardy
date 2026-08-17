package it.quiz.jeopardy.partita;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * Daily cleanup of expired, never-concluded games. In-process @Scheduled:
 * no external workers or brokers (budget constraint).
 */
@Component
public class PartitaCleanupJob {

    private static final Logger log = LoggerFactory.getLogger(PartitaCleanupJob.class);

    private final PartitaRepository partitaRepository;

    public PartitaCleanupJob(PartitaRepository partitaRepository) {
        this.partitaRepository = partitaRepository;
    }

    @Scheduled(cron = "${app.partita.pulizia-cron:0 0 4 * * *}")
    @Transactional
    public void pulisciPartiteScadute() {
        int rimosse = partitaRepository.deleteScadute(Instant.now(), StatoPartita.CONCLUSA);
        if (rimosse > 0) {
            log.info("Pulizia partite scadute: rimosse {}", rimosse);
        }
    }
}
