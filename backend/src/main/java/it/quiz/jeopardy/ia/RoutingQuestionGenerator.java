package it.quiz.jeopardy.ia;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Spreads generation across every configured {@link LlmProvider} and falls
 * back to the others when one fails.
 *
 * <p>Creating a board fires one call per difficulty band per category, so a
 * single provider on a free tier gets rate-limited or overloaded partway
 * through and the whole board ends up full of placeholders. Round-robin
 * halves the calls each backend sees, and the failover means one provider
 * having a bad minute no longer ruins the board.
 */
@Component
public class RoutingQuestionGenerator implements QuestionGenerator {

    private static final Logger log = LoggerFactory.getLogger(RoutingQuestionGenerator.class);

    private final List<LlmProvider> providers;
    private final AtomicInteger cursore = new AtomicInteger();
    private final int tentativi;
    private final Duration attesaDopoLimite;

    public RoutingQuestionGenerator(
            List<LlmProvider> providers,
            @Value("${app.ia.tentativi:2}") int tentativi,
            @Value("${app.ia.attesa-dopo-limite-secondi:12}") int attesaSecondi) {
        this.providers = providers;
        this.tentativi = Math.max(1, tentativi);
        this.attesaDopoLimite = Duration.ofSeconds(attesaSecondi);
    }

    @Override
    public GenerationOutcome generate(GenerationRequest request) {
        List<LlmProvider> disponibili = providers.stream()
                .filter(LlmProvider::configurato)
                .toList();

        if (disponibili.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Generazione IA non configurata: impostare almeno una fra "
                            + "GEMINI_API_KEY e GROQ_API_KEY");
        }

        RuntimeException ultimoErrore = null;

        for (int giro = 0; giro < tentativi; giro++) {
            if (giro > 0) {
                // I limiti dei free tier sono al minuto e si ricaricano in
                // pochi secondi: aspettare una volta sola costa meno che
                // consegnare un tabellone pieno di celle vuote
                log.info("Tutti i provider occupati, riprovo fra {}s", attesaDopoLimite.toSeconds());
                attendi();
            }

            // Il cursore avanza a ogni richiesta: le chiamate si distribuiscono
            // fra i provider invece di martellarne uno solo
            int partenza = Math.floorMod(cursore.getAndIncrement(), disponibili.size());

            for (int i = 0; i < disponibili.size(); i++) {
                LlmProvider provider = disponibili.get((partenza + i) % disponibili.size());
                try {
                    GenerationOutcome outcome = provider.generate(request);
                    if (outcome.domande().isEmpty()) {
                        // Risposta vuota: vale come fallimento, proviamo il prossimo
                        throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                                "Nessuna domanda restituita da " + provider.nome());
                    }
                    return outcome;
                } catch (RuntimeException e) {
                    ultimoErrore = e;
                    log.warn("Provider {} non ha risposto ({}), passo al successivo",
                            provider.nome(), e.getMessage());
                }
            }
        }

        log.error("Tutti i provider hanno fallito per l'argomento '{}'", request.argomento());
        throw ultimoErrore;
    }

    private void attendi() {
        try {
            Thread.sleep(attesaDopoLimite.toMillis());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Generazione interrotta", e);
        }
    }
}
