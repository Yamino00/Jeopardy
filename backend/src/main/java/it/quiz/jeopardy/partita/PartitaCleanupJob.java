package it.quiz.jeopardy.partita;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * Daily cleanup of expired, never-concluded games. In-process @Scheduled:
 * no external workers or brokers (budget constraint).
 *
 * <p>Il cron da solo non basta piu'. In produzione il servizio scende a zero
 * repliche quando nessuno gioca, e un {@code @Scheduled} gira solo se c'e' un
 * processo vivo a farlo girare: alle quattro del mattino non c'e'. La pulizia
 * viene percio' eseguita anche all'avvio, che con lo scale-to-zero capita a
 * ogni risveglio — cioe' molto piu' spesso di quanto capiti l'ora giusta. Il
 * cron resta per il caso opposto, un processo che sta su per giorni.
 *
 * <p>La cancellazione e' idempotente: eseguirla due volte di fila non fa
 * niente la seconda.
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

    /**
     * Un fallimento qui non deve impedire al servizio di partire: le partite
     * scadute sono spazzatura, non un invariante. Meglio un'applicazione su
     * con qualche riga di troppo che un'applicazione che non risponde.
     */
    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void pulisciAllAvvio() {
        try {
            // Chiamata interna: la transazione e' quella aperta qui sopra,
            // perche' l'annotazione su un metodo invocato da dentro la classe
            // non verrebbe vista
            pulisciPartiteScadute();
        } catch (RuntimeException e) {
            log.warn("Pulizia all'avvio fallita, riprovera' col cron", e);
        }
    }
}
