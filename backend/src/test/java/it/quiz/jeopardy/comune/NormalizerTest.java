package it.quiz.jeopardy.comune;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Unit tests for the canonical-entity normalization pipeline.
 * These cases are the contract required by the project prompt (Fase 2).
 */
class NormalizerTest {

    @ParameterizedTest(name = "\"{0}\" e \"{1}\" -> stessa entita")
    @CsvSource({
            "Giulio Cesare, giulio cesare",
            "Il Colosseo, Colosseo",
            "Perù, Peru",
            "Napoleone (imperatore), Napoleone",
            "44 a.C., 44 aC",
    })
    @DisplayName("Coppie equivalenti producono la stessa entita canonica")
    void equivalentAnswers_produceSameCanonicalEntity(String a, String b) {
        assertThat(Normalizer.toCanonical(a)).isEqualTo(Normalizer.toCanonical(b));
    }

    @Test
    @DisplayName("Risposte diverse producono entita diverse")
    void differentAnswers_produceDifferentEntities() {
        assertThat(Normalizer.toCanonical("Giulio Cesare"))
                .isNotEqualTo(Normalizer.toCanonical("Augusto"));
    }

    @Test
    @DisplayName("Minuscolo, senza accenti, senza articolo, senza parentesi")
    void pipelineSteps_areAllApplied() {
        assertThat(Normalizer.toCanonical("Giulio Cesare")).isEqualTo("giulio cesare");
        assertThat(Normalizer.toCanonical("Il Colosseo")).isEqualTo("colosseo");
        assertThat(Normalizer.toCanonical("Perù")).isEqualTo("peru");
        assertThat(Normalizer.toCanonical("Napoleone (imperatore)")).isEqualTo("napoleone");
        assertThat(Normalizer.toCanonical("44 a.C.")).isEqualTo("44 ac");
    }

    @Test
    @DisplayName("Articolo con apostrofo (l') viene rimosso")
    void elidedArticle_isRemoved() {
        assertThat(Normalizer.toCanonical("L'Aquila")).isEqualTo("aquila");
        assertThat(Normalizer.toCanonical("l'aquila")).isEqualTo("aquila");
    }

    @Test
    @DisplayName("Tutti gli articoli iniziali vengono rimossi")
    void allLeadingArticles_areRemoved() {
        assertThat(Normalizer.toCanonical("Lo Stivale")).isEqualTo("stivale");
        assertThat(Normalizer.toCanonical("La Divina Commedia")).isEqualTo("divina commedia");
        assertThat(Normalizer.toCanonical("I Promessi Sposi")).isEqualTo("promessi sposi");
        assertThat(Normalizer.toCanonical("Gli Uffizi")).isEqualTo("uffizi");
        assertThat(Normalizer.toCanonical("Le Alpi")).isEqualTo("alpi");
        assertThat(Normalizer.toCanonical("Un Americano a Roma")).isEqualTo("americano a roma");
        assertThat(Normalizer.toCanonical("Uno Stradivari")).isEqualTo("stradivari");
        assertThat(Normalizer.toCanonical("Una Vita")).isEqualTo("vita");
    }

    @Test
    @DisplayName("L'articolo non viene rimosso in mezzo alla frase")
    void articleInsideText_isKept() {
        assertThat(Normalizer.toCanonical("Il nome della rosa")).isEqualTo("nome della rosa");
        assertThat(Normalizer.toCanonical("Vasco Rossi il Blasco")).isEqualTo("vasco rossi il blasco");
    }

    @Test
    @DisplayName("Spazi multipli collassati e trim finale")
    void whitespace_isCollapsedAndTrimmed() {
        assertThat(Normalizer.toCanonical("  Giulio    Cesare  ")).isEqualTo("giulio cesare");
    }

    @Test
    @DisplayName("La normalizzazione è idempotente")
    void normalization_isIdempotent() {
        String once = Normalizer.toCanonical("L'Onorevole Perù (politico)");
        assertThat(Normalizer.toCanonical(once)).isEqualTo(once);
    }

    @Test
    @DisplayName("null viene normalizzato a stringa vuota")
    void nullInput_becomesEmptyString() {
        assertThat(Normalizer.toCanonical(null)).isEmpty();
    }

    @Test
    @DisplayName("hashTesto: stesso testo a meno di maiuscole e spazi -> stesso hash")
    void hashTesto_isCaseAndWhitespaceInsensitive() {
        byte[] h1 = Normalizer.hashTesto("Chi fu il primo imperatore romano?");
        byte[] h2 = Normalizer.hashTesto("  chi fu il primo   imperatore romano?  ");
        assertThat(h1).isEqualTo(h2);
    }

    @Test
    @DisplayName("hashTesto: testi diversi -> hash diversi, lunghezza 32 byte")
    void hashTesto_differsForDifferentTexts() {
        byte[] h1 = Normalizer.hashTesto("Chi fu il primo imperatore romano?");
        byte[] h2 = Normalizer.hashTesto("Chi vinse la battaglia di Azio?");
        assertThat(h1).isNotEqualTo(h2);
        assertThat(h1).hasSize(32);
    }
}
