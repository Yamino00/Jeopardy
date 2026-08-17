package it.quiz.jeopardy.banca;

import it.quiz.jeopardy.TestcontainersConfiguration;
import it.quiz.jeopardy.comune.Normalizer;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Integration tests for the dedup cascade against a real PostgreSQL
 * (partial unique indexes and pg_trgm are not available on H2).
 */
@SpringBootTest
@Import(TestcontainersConfiguration.class)
class DeduplicationServiceIntegrationTest {

    @Autowired
    private DeduplicationService deduplicationService;

    @Autowired
    private ArgomentoRepository argomentoRepository;

    @Autowired
    private DomandaRepository domandaRepository;

    private Argomento newArgomento(String slug) {
        return argomentoRepository.save(new Argomento(slug, slug));
    }

    private Domanda insertDomanda(Argomento argomento, String testo, String risposta,
                                  StatoDomanda stato) {
        Domanda d = new Domanda();
        d.setArgomento(argomento);
        d.setTesto(testo);
        d.setRisposta(risposta);
        d.setEntitaCanonica(Normalizer.toCanonical(risposta));
        d.setHashTesto(Normalizer.hashTesto(testo));
        d.setDifficolta((short) 3);
        d.setStato(stato);
        return domandaRepository.save(d);
    }

    private static CandidateQuestion candidate(String testo, String risposta) {
        return new CandidateQuestion(testo, risposta, null, (short) 3);
    }

    @Test
    @DisplayName("Entita canonica gia presente per l'argomento -> DUPLICATO_ENTITA")
    void existingCanonicalEntity_isRejected() {
        Argomento arg = newArgomento("dedup-entita");
        insertDomanda(arg, "Chi fu il primo imperatore romano?", "Augusto", StatoDomanda.ATTIVA);

        DeduplicationResult result = deduplicationService.deduplicate(arg.getId(), List.of(
                candidate("Quale imperatore fondo il principato?", "L'Augusto (imperatore)")));

        assertThat(result.accettate()).isEmpty();
        assertThat(result.scartate()).hasSize(1);
        assertThat(result.scartate().get(0).motivo()).isEqualTo(RejectionReason.DUPLICATO_ENTITA);
    }

    @Test
    @DisplayName("Stessa entita su argomento diverso -> accettata")
    void sameEntityOnDifferentTopic_isAccepted() {
        Argomento storia = newArgomento("dedup-storia");
        Argomento arte = newArgomento("dedup-arte");
        insertDomanda(storia, "Chi fu il primo imperatore romano?", "Augusto", StatoDomanda.ATTIVA);

        DeduplicationResult result = deduplicationService.deduplicate(arte.getId(), List.of(
                candidate("A chi e dedicata l'Ara Pacis?", "Augusto")));

        assertThat(result.accettate()).hasSize(1);
        assertThat(result.scartate()).isEmpty();
    }

    @Test
    @DisplayName("Domanda ritirata non blocca la stessa entita")
    void retiredQuestion_doesNotBlock() {
        Argomento arg = newArgomento("dedup-ritirata");
        insertDomanda(arg, "Chi compose il Requiem in re minore?", "Mozart", StatoDomanda.RITIRATA);

        DeduplicationResult result = deduplicationService.deduplicate(arg.getId(), List.of(
                candidate("Chi compose Le nozze di Figaro?", "Mozart")));

        assertThat(result.accettate()).hasSize(1);
        assertThat(result.scartate()).isEmpty();
    }

    @Test
    @DisplayName("Stesso testo normalizzato (hash) -> DUPLICATO_TESTO")
    void sameNormalizedText_isRejected() {
        Argomento arg = newArgomento("dedup-hash");
        insertDomanda(arg, "Chi dipinse la Gioconda?", "Leonardo da Vinci", StatoDomanda.ATTIVA);

        DeduplicationResult result = deduplicationService.deduplicate(arg.getId(), List.of(
                candidate("  chi dipinse la GIOCONDA?  ", "Leonardo")));

        assertThat(result.accettate()).isEmpty();
        assertThat(result.scartate()).hasSize(1);
        assertThat(result.scartate().get(0).motivo()).isEqualTo(RejectionReason.DUPLICATO_TESTO);
    }

    @Test
    @DisplayName("Testo simile (trigram > 0.6) sullo stesso argomento -> TESTO_SIMILE")
    void similarText_isRejected() {
        Argomento arg = newArgomento("dedup-trgm");
        insertDomanda(arg, "Quale fiume attraversa la citta di Roma?", "Il Tevere", StatoDomanda.ATTIVA);

        DeduplicationResult result = deduplicationService.deduplicate(arg.getId(), List.of(
                candidate("Quale fiume attraversa la citta di Parigi?", "La Senna")));

        assertThat(result.accettate()).isEmpty();
        assertThat(result.scartate()).hasSize(1);
        assertThat(result.scartate().get(0).motivo()).isEqualTo(RejectionReason.TESTO_SIMILE);
    }

    @Test
    @DisplayName("Testo simile ma su argomento diverso -> accettata")
    void similarTextOnDifferentTopic_isAccepted() {
        Argomento geo = newArgomento("dedup-trgm-geo");
        Argomento cinema = newArgomento("dedup-trgm-cinema");
        insertDomanda(geo, "Quale citta e famosa per il Colosseo e i Fori Imperiali?",
                "Roma", StatoDomanda.ATTIVA);

        DeduplicationResult result = deduplicationService.deduplicate(cinema.getId(), List.of(
                candidate("Quale citta e famosa per il Colosseo e i Fori Imperiali nel cinema?",
                        "Roma citta aperta")));

        assertThat(result.accettate()).hasSize(1);
        assertThat(result.scartate()).isEmpty();
    }

    @Test
    @DisplayName("Duplicati dentro il batch: stessa entita -> secondo scartato")
    void intraBatchDuplicateEntity_isRejected() {
        Argomento arg = newArgomento("dedup-batch-entita");

        DeduplicationResult result = deduplicationService.deduplicate(arg.getId(), List.of(
                candidate("Chi scrisse la Divina Commedia?", "Dante Alighieri"),
                candidate("Chi e l'autore dell'Inferno?", "dante alighieri")));

        assertThat(result.accettate()).hasSize(1);
        assertThat(result.scartate()).hasSize(1);
        assertThat(result.scartate().get(0).motivo()).isEqualTo(RejectionReason.DUPLICATO_ENTITA);
        assertThat(result.scartate().get(0).candidate().risposta()).isEqualTo("dante alighieri");
    }

    @Test
    @DisplayName("Duplicati dentro il batch: stesso testo -> secondo scartato")
    void intraBatchDuplicateText_isRejected() {
        Argomento arg = newArgomento("dedup-batch-testo");

        DeduplicationResult result = deduplicationService.deduplicate(arg.getId(), List.of(
                candidate("Chi unifico l'Italia nel 1861?", "Vittorio Emanuele II"),
                candidate("CHI UNIFICO l'italia NEL 1861?", "Garibaldi")));

        assertThat(result.accettate()).hasSize(1);
        assertThat(result.scartate()).hasSize(1);
        assertThat(result.scartate().get(0).motivo()).isEqualTo(RejectionReason.DUPLICATO_TESTO);
    }

    @Test
    @DisplayName("Batch pulito: tutte accettate e arricchite con entita e hash")
    void cleanBatch_isFullyAccepted() {
        Argomento arg = newArgomento("dedup-pulito");

        DeduplicationResult result = deduplicationService.deduplicate(arg.getId(), List.of(
                candidate("In che anno cadde l'Impero Romano d'Occidente?", "Il 476 d.C."),
                candidate("Chi attraverso le Alpi con gli elefanti?", "Annibale")));

        assertThat(result.scartate()).isEmpty();
        assertThat(result.accettate()).hasSize(2);
        assertThat(result.accettate().get(0).entitaCanonica()).isEqualTo("476 dc");
        assertThat(result.accettate().get(0).hashTesto()).hasSize(32);
        assertThat(result.accettate().get(1).entitaCanonica()).isEqualTo("annibale");
    }
}
