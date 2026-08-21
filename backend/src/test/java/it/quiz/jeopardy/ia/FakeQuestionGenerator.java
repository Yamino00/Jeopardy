package it.quiz.jeopardy.ia;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Test double for the LLM: never touches the network. By default it produces
 * unique, mutually dissimilar questions; specific outcomes can be enqueued.
 */
public class FakeQuestionGenerator implements QuestionGenerator {

    private final AtomicInteger calls = new AtomicInteger();
    private final Deque<GenerationOutcome> queued = new ArrayDeque<>();
    private RuntimeException erroreDaLanciare;

    @Override
    public GenerationOutcome generate(GenerationRequest request) {
        calls.incrementAndGet();
        if (erroreDaLanciare != null) {
            throw erroreDaLanciare;
        }
        if (!queued.isEmpty()) {
            return queued.pop();
        }
        List<GeneratedQuestion> domande = new ArrayList<>();
        // Rispetta la distribuzione richiesta: il servizio smista le domande
        // per difficolta', quindi un fake che le marca tutte uguali non
        // eserciterebbe quel percorso
        for (GenerationRequest.QuotaDifficolta quota : request.richieste()) {
            for (int i = 0; i < quota.quantita(); i++) {
                // Random identifiers keep trigram similarity between texts low
                String unique = UUID.randomUUID().toString();
                domande.add(new GeneratedQuestion(
                        "Indovina il codice segreto " + unique + "?",
                        "Codice " + unique,
                        "codice " + unique,
                        request.sottoArgomento(),
                        quota.difficolta()));
            }
        }
        return new GenerationOutcome(domande, "fake-model", 100, 200);
    }

    public void enqueue(GenerationOutcome outcome) {
        queued.add(outcome);
    }

    /** Simula un provider che non risponde: serve a verificare cosa si paga. */
    public void faiFallire(RuntimeException errore) {
        this.erroreDaLanciare = errore;
    }

    public int calls() {
        return calls.get();
    }

    public void reset() {
        calls.set(0);
        queued.clear();
        erroreDaLanciare = null;
    }
}
