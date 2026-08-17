package it.quiz.jeopardy.ia;

import it.quiz.jeopardy.TestcontainersConfiguration;
import it.quiz.jeopardy.banca.Argomento;
import it.quiz.jeopardy.banca.ArgomentoRepository;
import it.quiz.jeopardy.banca.Domanda;
import it.quiz.jeopardy.banca.DomandaRepository;
import it.quiz.jeopardy.comune.Normalizer;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Fase 3 requirements, with the fake generator: a populated bank must prevent
 * the LLM call; batch duplicates must be rejected; the audit row must be saved.
 */
@SpringBootTest
@Import({TestcontainersConfiguration.class, FakeGeneratorConfiguration.class})
class GenerationServiceIntegrationTest {

    @Autowired
    private GenerationService generationService;

    @Autowired
    private ArgomentoRepository argomentoRepository;

    @Autowired
    private DomandaRepository domandaRepository;

    @Autowired
    private GenerazioneRepository generazioneRepository;

    @Autowired
    private FakeQuestionGenerator fakeGenerator;

    @BeforeEach
    void resetFake() {
        fakeGenerator.reset();
    }

    private Argomento newArgomento(String slug) {
        return argomentoRepository.save(new Argomento(slug, slug));
    }

    private void insertDomanda(Argomento argomento, String testo, String risposta) {
        Domanda d = new Domanda();
        d.setArgomento(argomento);
        d.setTesto(testo);
        d.setRisposta(risposta);
        d.setEntitaCanonica(Normalizer.toCanonical(risposta));
        d.setHashTesto(Normalizer.hashTesto(testo));
        d.setDifficolta((short) 3);
        domandaRepository.save(d);
    }

    @Test
    @DisplayName("Banca gia popolata: l'LLM non viene chiamato")
    void populatedBank_skipsLlmCall() {
        Argomento arg = newArgomento("gen-banca-piena");
        insertDomanda(arg, "Chi vinse la battaglia di Zama?", "Scipione l'Africano");
        insertDomanda(arg, "Chi attraverso il Rubicone nel 49 a.C.?", "Giulio Cesare");
        insertDomanda(arg, "Chi fu l'ultimo re di Roma?", "Tarquinio il Superbo");

        GenerationResultDto result = generationService.generate(
                UUID.randomUUID(), arg.getId(), null, (short) 3, 3);

        assertThat(fakeGenerator.calls()).isZero();
        assertThat(result.chiamataLlm()).isFalse();
        assertThat(result.riusate()).isEqualTo(3);
        assertThat(result.nuoveGenerate()).isZero();
        assertThat(result.domande()).hasSize(3);
    }

    @Test
    @DisplayName("Duplicati nel batch scartati, accettate inserite, audit registrato")
    void batchDuplicates_areRejected_andAuditIsRecorded() {
        Argomento arg = newArgomento("gen-batch-dup");
        fakeGenerator.enqueue(new GenerationOutcome(List.of(
                new GeneratedQuestion("Chi dipinse la Cappella Sistina?",
                        "Michelangelo", "michelangelo", null, 3),
                new GeneratedQuestion("Chi sculpi il David conservato a Firenze?",
                        "Michelangelo Buonarroti (Michelangelo)", "michelangelo", null, 3),
                new GeneratedQuestion("Chi progetto la cupola di Santa Maria del Fiore?",
                        "Brunelleschi", "brunelleschi", null, 3)),
                "fake-model", 120, 340));

        GenerationResultDto result = generationService.generate(
                UUID.randomUUID(), arg.getId(), null, (short) 3, 2);

        assertThat(fakeGenerator.calls()).isEqualTo(1);
        assertThat(result.chiamataLlm()).isTrue();
        // "Michelangelo Buonarroti (Michelangelo)" normalizza a "michelangelo buonarroti",
        // quindi il duplicato vero e solo la coppia con stessa entita
        assertThat(result.nuoveGenerate() + result.scartate()).isEqualTo(3);
        assertThat(result.domande()).hasSizeLessThanOrEqualTo(2);

        Generazione audit = generazioneRepository.findAll().stream()
                .filter(g -> arg.getId().equals(g.getArgomentoId()))
                .findFirst().orElseThrow();
        assertThat(audit.getRichieste()).isEqualTo((short) 3);
        assertThat(audit.getAccettate()).isEqualTo((short) result.nuoveGenerate());
        assertThat(audit.getTokenInput()).isEqualTo(120);
        assertThat(audit.getTokenOutput()).isEqualTo(340);
        assertThat(audit.getModello()).isEqualTo("fake-model");
    }

    @Test
    @DisplayName("Batch con entita gia in banca: il duplicato viene scartato")
    void candidateDuplicatingBank_isRejected() {
        Argomento arg = newArgomento("gen-dup-banca");
        insertDomanda(arg, "Chi scrisse I Promessi Sposi?", "Alessandro Manzoni");
        fakeGenerator.enqueue(new GenerationOutcome(List.of(
                new GeneratedQuestion("Chi e l'autore del Fermo e Lucia?",
                        "Alessandro Manzoni", "alessandro manzoni", null, 3),
                new GeneratedQuestion("Chi scrisse lo Zibaldone?",
                        "Giacomo Leopardi", "giacomo leopardi", null, 3)),
                "fake-model", 100, 200));

        GenerationResultDto result = generationService.generate(
                UUID.randomUUID(), arg.getId(), null, (short) 3, 2);

        assertThat(result.scartate()).isEqualTo(1);
        assertThat(result.nuoveGenerate()).isEqualTo(1);
        // banca: Manzoni riusata + Leopardi appena inserita
        assertThat(result.domande()).hasSize(2);
    }
}
