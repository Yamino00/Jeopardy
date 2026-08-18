package it.quiz.jeopardy.ia;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Il router e' cio' che tiene in piedi la creazione di un tabellone quando un
 * provider e' sovraccarico: qui si verifica che distribuisca il carico e che
 * il fallimento di uno non blocchi la generazione.
 */
class RoutingQuestionGeneratorTest {

    private static final GenerationRequest RICHIESTA =
            GenerationRequest.singola("Storia", null, (short) 3, 3, List.of());

    /** Un solo giro e nessuna attesa: i test non devono dormire. */
    private static RoutingQuestionGenerator router(List<LlmProvider> providers) {
        return new RoutingQuestionGenerator(providers, 1, 0);
    }

    @Test
    @DisplayName("Le chiamate si alternano fra i provider configurati")
    void spreadsCallsAcrossProviders() {
        FakeProvider a = new FakeProvider("a", true);
        FakeProvider b = new FakeProvider("b", true);
        RoutingQuestionGenerator router = router(List.of(a, b));

        for (int i = 0; i < 4; i++) {
            router.generate(RICHIESTA);
        }

        assertThat(a.chiamate()).isEqualTo(2);
        assertThat(b.chiamate()).isEqualTo(2);
    }

    @Test
    @DisplayName("Se un provider fallisce si passa all'altro")
    void failsOverToTheOtherProvider() {
        FakeProvider rotto = new FakeProvider("rotto", true).cheFallisce();
        FakeProvider sano = new FakeProvider("sano", true);
        RoutingQuestionGenerator router = router(List.of(rotto, sano));

        GenerationOutcome outcome = router.generate(RICHIESTA);

        assertThat(outcome.domande()).isNotEmpty();
        assertThat(outcome.modello()).isEqualTo("sano");
        assertThat(rotto.chiamate()).isEqualTo(1);
        assertThat(sano.chiamate()).isEqualTo(1);
    }

    @Test
    @DisplayName("Una risposta vuota conta come fallimento e attiva il fallback")
    void emptyAnswerTriggersFailover() {
        FakeProvider vuoto = new FakeProvider("vuoto", true).cheRestituisceVuoto();
        FakeProvider sano = new FakeProvider("sano", true);
        RoutingQuestionGenerator router = router(List.of(vuoto, sano));

        assertThat(router.generate(RICHIESTA).modello()).isEqualTo("sano");
    }

    @Test
    @DisplayName("I provider senza chiave vengono ignorati")
    void skipsUnconfiguredProviders() {
        FakeProvider senzaChiave = new FakeProvider("senza-chiave", false);
        FakeProvider sano = new FakeProvider("sano", true);
        RoutingQuestionGenerator router = router(List.of(senzaChiave, sano));

        router.generate(RICHIESTA);
        router.generate(RICHIESTA);

        assertThat(senzaChiave.chiamate()).isZero();
        assertThat(sano.chiamate()).isEqualTo(2);
    }

    @Test
    @DisplayName("Nessun provider configurato -> 503 con messaggio esplicito")
    void noProviderConfigured_isExplicit() {
        RoutingQuestionGenerator router = router(
                List.of(new FakeProvider("a", false)));

        assertThatThrownBy(() -> router.generate(RICHIESTA))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("GEMINI_API_KEY");
    }

    @Test
    @DisplayName("Se falliscono tutti, l'errore dell'ultimo arriva al chiamante")
    void allProvidersFailing_rethrows() {
        RoutingQuestionGenerator router = router(List.of(
                new FakeProvider("a", true).cheFallisce(),
                new FakeProvider("b", true).cheFallisce()));

        assertThatThrownBy(() -> router.generate(RICHIESTA))
                .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    @DisplayName("Con piu tentativi il provider viene riprovato dopo l'attesa")
    void retriesAfterRateLimit() {
        FakeProvider provider = new FakeProvider("a", true).cheFallisce();
        // 2 giri, attesa 0: verifica il riprovare senza rallentare il test
        var router = new RoutingQuestionGenerator(List.of(provider), 2, 0);

        assertThatThrownBy(() -> router.generate(RICHIESTA))
                .isInstanceOf(ResponseStatusException.class);
        assertThat(provider.chiamate()).isEqualTo(2);
    }

    private static final class FakeProvider implements LlmProvider {
        private final String nome;
        private final boolean configurato;
        private final AtomicInteger chiamate = new AtomicInteger();
        private boolean fallisce;
        private boolean vuoto;

        FakeProvider(String nome, boolean configurato) {
            this.nome = nome;
            this.configurato = configurato;
        }

        FakeProvider cheFallisce() {
            this.fallisce = true;
            return this;
        }

        FakeProvider cheRestituisceVuoto() {
            this.vuoto = true;
            return this;
        }

        int chiamate() {
            return chiamate.get();
        }

        @Override
        public String nome() {
            return nome;
        }

        @Override
        public boolean configurato() {
            return configurato;
        }

        @Override
        public GenerationOutcome generate(GenerationRequest request) {
            chiamate.incrementAndGet();
            if (fallisce) {
                throw new ResponseStatusException(
                        org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE, "sovraccarico");
            }
            if (vuoto) {
                return new GenerationOutcome(List.of(), nome, 0, 0);
            }
            return new GenerationOutcome(
                    List.of(new GeneratedQuestion("Domanda?", "Risposta", "risposta", null, 3)),
                    nome, 10, 20);
        }
    }
}
