package it.quiz.jeopardy.ia;

import it.quiz.jeopardy.banca.Argomento;
import it.quiz.jeopardy.banca.ArgomentoRepository;
import it.quiz.jeopardy.banca.CandidateQuestion;
import it.quiz.jeopardy.banca.DeduplicationResult;
import it.quiz.jeopardy.banca.DeduplicationService;
import it.quiz.jeopardy.banca.Domanda;
import it.quiz.jeopardy.banca.DomandaDto;
import it.quiz.jeopardy.banca.DomandaRepository;
import it.quiz.jeopardy.comune.Normalizer;
import it.quiz.jeopardy.comune.ResourceNotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Generation pipeline. Order matters, and the LLM is the last resort:
 * <ol>
 *   <li>count suitable questions in the bank not yet used by this client;
 *       if enough, NO LLM call: return those;</li>
 *   <li>otherwise consume quota (429 beyond the daily limit), build the
 *       single-cell prompt with the blocklist and ask for N+2 questions in one
 *       call, never retrying on rejection;</li>
 *   <li>validate each candidate, recompute {@code entita_canonica} in Java
 *       (the LLM's value is only logged when divergent);</li>
 *   <li>run the dedup cascade, insert survivors, record the audit row in
 *       {@code generazione}.</li>
 * </ol>
 */
@Service
public class GenerationService {

    private static final Logger log = LoggerFactory.getLogger(GenerationService.class);

    /** Extra questions asked on top of the missing count, to absorb rejects. */
    private static final int OVERPROVISION = 2;

    private final ArgomentoRepository argomentoRepository;
    private final DomandaRepository domandaRepository;
    private final DeduplicationService deduplicationService;
    private final QuestionGenerator questionGenerator;
    private final QuotaService quotaService;
    private final GenerazioneRepository generazioneRepository;
    private final BigDecimal costoPer1kInput;
    private final BigDecimal costoPer1kOutput;

    public GenerationService(ArgomentoRepository argomentoRepository,
                             DomandaRepository domandaRepository,
                             DeduplicationService deduplicationService,
                             QuestionGenerator questionGenerator,
                             QuotaService quotaService,
                             GenerazioneRepository generazioneRepository,
                             @Value("${app.ia.costo-per-1k-input:0}") BigDecimal costoPer1kInput,
                             @Value("${app.ia.costo-per-1k-output:0}") BigDecimal costoPer1kOutput) {
        this.argomentoRepository = argomentoRepository;
        this.domandaRepository = domandaRepository;
        this.deduplicationService = deduplicationService;
        this.questionGenerator = questionGenerator;
        this.quotaService = quotaService;
        this.generazioneRepository = generazioneRepository;
        this.costoPer1kInput = costoPer1kInput;
        this.costoPer1kOutput = costoPer1kOutput;
    }

    @Transactional
    public GenerationResultDto generate(UUID clientId, Long argomentoId,
                                        String sottoArgomento, short difficolta, int numero) {
        Argomento argomento = argomentoRepository.findById(argomentoId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Argomento " + argomentoId + " non trovato"));

        List<Domanda> disponibili = domandaRepository.findAvailableForClient(
                argomentoId, sottoArgomento, difficolta, clientId, numero);
        if (disponibili.size() >= numero) {
            return toResult(disponibili, disponibili.size(), 0, 0, false);
        }

        quotaService.consumeGeneration(clientId);

        int mancanti = numero - disponibili.size();
        List<String> blocklist = domandaRepository.findEntitaCanonicheByArgomento(argomentoId);
        GenerationOutcome outcome = questionGenerator.generate(new GenerationRequest(
                argomento.getNome(), sottoArgomento, difficolta,
                mancanti + OVERPROVISION, blocklist));

        List<CandidateQuestion> candidati = validateAndNormalize(outcome, sottoArgomento, difficolta);
        DeduplicationResult dedup = deduplicationService.deduplicate(argomentoId, candidati);

        List<Domanda> inserite = new ArrayList<>();
        for (DeduplicationResult.AcceptedCandidate accepted : dedup.accettate()) {
            inserite.add(domandaRepository.save(
                    toEntity(accepted, argomento, outcome.modello())));
        }

        recordGenerazione(clientId, argomentoId, outcome, dedup.accettate().size());

        List<Domanda> risultato = new ArrayList<>(disponibili);
        for (Domanda inserita : inserite) {
            if (risultato.size() >= numero) {
                break;
            }
            risultato.add(inserita);
        }
        return toResult(risultato, disponibili.size(), inserite.size(),
                dedup.scartate().size(), true);
    }

    private List<CandidateQuestion> validateAndNormalize(GenerationOutcome outcome,
                                                         String sottoArgomento,
                                                         short difficolta) {
        List<CandidateQuestion> candidati = new ArrayList<>();
        for (GeneratedQuestion generata : outcome.domande()) {
            if (generata.testo() == null || generata.testo().isBlank()
                    || generata.risposta() == null || generata.risposta().isBlank()) {
                log.warn("Domanda generata scartata per campi mancanti: {}", generata);
                continue;
            }
            String canonicaJava = Normalizer.toCanonical(generata.risposta());
            if (generata.entitaCanonica() != null
                    && !canonicaJava.equals(generata.entitaCanonica())) {
                log.info("Divergenza entita_canonica: LLM='{}' Java='{}' (risposta='{}')",
                        generata.entitaCanonica(), canonicaJava, generata.risposta());
            }
            candidati.add(new CandidateQuestion(
                    generata.testo().strip(),
                    generata.risposta().strip(),
                    sottoArgomento,
                    difficolta));
        }
        return candidati;
    }

    private Domanda toEntity(DeduplicationResult.AcceptedCandidate accepted,
                             Argomento argomento, String modello) {
        Domanda domanda = new Domanda();
        domanda.setArgomento(argomento);
        domanda.setTesto(accepted.candidate().testo());
        domanda.setRisposta(accepted.candidate().risposta());
        domanda.setEntitaCanonica(accepted.entitaCanonica());
        domanda.setHashTesto(accepted.hashTesto());
        domanda.setSottoArgomento(accepted.candidate().sottoArgomento());
        domanda.setDifficolta(accepted.candidate().difficolta());
        domanda.setModello(modello);
        return domanda;
    }

    private void recordGenerazione(UUID clientId, Long argomentoId,
                                   GenerationOutcome outcome, int accettate) {
        Generazione generazione = new Generazione();
        generazione.setArgomentoId(argomentoId);
        generazione.setClientId(clientId);
        generazione.setModello(outcome.modello());
        generazione.setRichieste((short) outcome.domande().size());
        generazione.setAccettate((short) accettate);
        generazione.setTokenInput(outcome.tokenInput());
        generazione.setTokenOutput(outcome.tokenOutput());
        generazione.setCostoStimato(estimateCost(outcome));
        generazioneRepository.save(generazione);
    }

    private BigDecimal estimateCost(GenerationOutcome outcome) {
        BigDecimal input = outcome.tokenInput() == null ? BigDecimal.ZERO
                : costoPer1kInput.multiply(BigDecimal.valueOf(outcome.tokenInput()));
        BigDecimal output = outcome.tokenOutput() == null ? BigDecimal.ZERO
                : costoPer1kOutput.multiply(BigDecimal.valueOf(outcome.tokenOutput()));
        return input.add(output)
                .divide(BigDecimal.valueOf(1000), 6, RoundingMode.HALF_UP);
    }

    private GenerationResultDto toResult(List<Domanda> domande, int riusate,
                                         int nuove, int scartate, boolean chiamataLlm) {
        return new GenerationResultDto(
                domande.stream().map(DomandaDto::from).toList(),
                riusate, nuove, scartate, chiamataLlm);
    }
}
