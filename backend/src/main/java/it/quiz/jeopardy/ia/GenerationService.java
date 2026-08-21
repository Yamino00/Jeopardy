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
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.IntFunction;
import java.util.stream.Collectors;

/**
 * Generation pipeline. Order matters, and the LLM is the last resort:
 * <ol>
 *   <li>count suitable questions in the bank not yet used by this client;</li>
 *   <li>if some are missing, consume quota and ask the LLM <b>once</b> for
 *       everything that is missing across all the requested difficulties;</li>
 *   <li>validate, recompute {@code entita_canonica} in Java, deduplicate,
 *       insert the survivors and record the audit row.</li>
 * </ol>
 *
 * <p>Il punto 2 e' quello che tiene in piedi il free tier: una chiamata per
 * fascia di difficolta' per categoria consumava ~18.000 token per un tabellone
 * 2x5, contro gli 8.000 al minuto concessi da Groq.
 */
@Service
public class GenerationService {

    private static final Logger log = LoggerFactory.getLogger(GenerationService.class);

    private final ArgomentoRepository argomentoRepository;
    private final DomandaRepository domandaRepository;
    private final DeduplicationService deduplicationService;
    private final QuestionGenerator questionGenerator;
    private final QuotaService quotaService;
    private final GenerazioneRepository generazioneRepository;
    private final BigDecimal costoPer1kInput;
    private final BigDecimal costoPer1kOutput;

    /** Extra questions asked on top of the missing count, to absorb rejects. */
    private final int overprovisioning;

    public GenerationService(ArgomentoRepository argomentoRepository,
                             DomandaRepository domandaRepository,
                             DeduplicationService deduplicationService,
                             QuestionGenerator questionGenerator,
                             QuotaService quotaService,
                             GenerazioneRepository generazioneRepository,
                             @Value("${app.ia.costo-per-1k-input:0}") BigDecimal costoPer1kInput,
                             @Value("${app.ia.costo-per-1k-output:0}") BigDecimal costoPer1kOutput,
                             @Value("${app.ia.overprovisioning:2}") int overprovisioning) {
        this.argomentoRepository = argomentoRepository;
        this.domandaRepository = domandaRepository;
        this.deduplicationService = deduplicationService;
        this.questionGenerator = questionGenerator;
        this.quotaService = quotaService;
        this.generazioneRepository = generazioneRepository;
        this.costoPer1kInput = costoPer1kInput;
        this.costoPer1kOutput = costoPer1kOutput;
        this.overprovisioning = overprovisioning;
    }

    /**
     * Endpoint a grana fine: una sola difficolta'.
     *
     * <p>Non ripiega su domande gia' viste dal client: chi chiama questo
     * metodo sta chiedendo qualcosa di nuovo, e una risposta vuota e' una
     * risposta legittima. Vedi {@link Ripiego}.
     */
    @Transactional
    public GenerationResultDto generate(UUID clientId, Long argomentoId,
                                        String sottoArgomento, short difficolta, int numero,
                                        Scadenza scadenza) {
        Esito esito = generaPerFasce(clientId, argomentoId, sottoArgomento,
                Map.of(difficolta, numero), scadenza, Ripiego.SOLO_NUOVE_PER_IL_CLIENT);
        List<DomandaDto> domande = esito.perDifficolta().getOrDefault(difficolta, List.of())
                .stream().map(DomandaDto::from).toList();
        return new GenerationResultDto(domande, esito.riusate(), esito.nuove(),
                esito.scartate(), esito.chiamataLlm());
    }

    /**
     * Genera per piu' fasce di difficolta' con una sola chiamata all'LLM.
     * Ritorna, per ogni difficolta' richiesta, le domande utilizzabili.
     */
    @Transactional
    public Esito generaPerFasce(UUID clientId, Long argomentoId, String sottoArgomento,
                                Map<Short, Integer> richieste, Scadenza scadenza,
                                Ripiego ripiego) {
        Argomento argomento = argomentoRepository.findById(argomentoId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Argomento " + argomentoId + " non trovato"));

        // 1. Quel che la banca offre gia', fascia per fascia
        Map<Short, List<Domanda>> disponibili = new LinkedHashMap<>();
        Map<Short, Integer> mancanti = new LinkedHashMap<>();
        int totaleRiusate = 0;

        for (Map.Entry<Short, Integer> richiesta : richieste.entrySet()) {
            short difficolta = richiesta.getKey();
            int quantita = richiesta.getValue();
            List<Domanda> dallaBanca = domandaRepository.findAvailableForClient(
                    argomentoId, sottoArgomento, difficolta, clientId, quantita);
            disponibili.put(difficolta, new ArrayList<>(dallaBanca));
            totaleRiusate += dallaBanca.size();
            if (dallaBanca.size() < quantita) {
                mancanti.put(difficolta, quantita - dallaBanca.size());
            }
        }

        if (mancanti.isEmpty()) {
            return new Esito(disponibili, totaleRiusate, 0, 0, false);
        }

        // 2. Una sola chiamata per tutto cio' che manca. La quota si controlla
        // adesso ma si consuma dopo: cominciare un lavoro lungo che la quota
        // gia' vieta fa aspettare l'utente per niente, e addebitarlo prima di
        // sapere se l'LLM ha risposto lo fa pagare per niente
        quotaService.verificaDisponibilita(clientId);
        scadenza.verifica("la preparazione della richiesta all'IA");

        List<GenerationRequest.QuotaDifficolta> quote = mancanti.entrySet().stream()
                .map(e -> new GenerationRequest.QuotaDifficolta(e.getKey(), e.getValue()))
                .toList();
        // L'overprovisioning va sulla fascia piu' numerosa, non moltiplicato
        // per ogni fascia: serve ad assorbire gli scarti, non a gonfiare
        List<GenerationRequest.QuotaDifficolta> conRiserva = new ArrayList<>(quote);
        if (!conRiserva.isEmpty()) {
            GenerationRequest.QuotaDifficolta prima = conRiserva.get(0);
            conRiserva.set(0, new GenerationRequest.QuotaDifficolta(
                    prima.difficolta(), prima.quantita() + overprovisioning));
        }

        List<String> blocklist = domandaRepository.findEntitaCanonicheByArgomento(argomentoId);
        GenerationOutcome outcome = questionGenerator.generate(new GenerationRequest(
                argomento.getNome(), sottoArgomento, conRiserva, blocklist, scadenza));

        // L'LLM ha risposto: adesso la generazione e' stata davvero erogata
        quotaService.consumeGeneration(clientId);

        // 3. Validazione + deduplicazione + inserimento
        List<CandidateQuestion> candidati = validateAndNormalize(outcome, sottoArgomento);
        DeduplicationResult dedup = deduplicationService.deduplicate(argomentoId, candidati);

        Map<Short, Deque<Domanda>> nuovePerDifficolta = new HashMap<>();
        int inserite = 0;
        for (DeduplicationResult.AcceptedCandidate accepted : dedup.accettate()) {
            Domanda salvata = domandaRepository.save(
                    toEntity(accepted, argomento, outcome.modello()));
            nuovePerDifficolta
                    .computeIfAbsent(salvata.getDifficolta(), k -> new ArrayDeque<>())
                    .add(salvata);
            inserite++;
        }

        recordGenerazione(clientId, argomentoId, outcome, dedup.accettate().size());

        // 4. Completa le fasce ancora scoperte, prima con la difficolta' esatta
        // poi con qualunque altra fra le nuove
        for (Map.Entry<Short, Integer> richiesta : richieste.entrySet()) {
            short difficolta = richiesta.getKey();
            List<Domanda> lista = disponibili.get(difficolta);
            Deque<Domanda> esatte = nuovePerDifficolta.get(difficolta);
            while (lista.size() < richiesta.getValue() && esatte != null && !esatte.isEmpty()) {
                lista.add(esatte.poll());
            }
            while (lista.size() < richiesta.getValue()) {
                Domanda daAltraFascia = qualsiasiDisponibile(nuovePerDifficolta);
                if (daAltraFascia == null) {
                    break;
                }
                lista.add(daAltraFascia);
            }
        }

        // 5. Se dopo l'LLM manca ancora qualcosa, si ripiega sulla banca invece
        // di lasciare un buco: prima domande mai viste da questo client anche
        // se di un'altra fascia, poi domande che ha gia' visto. Una ripetizione
        // si nota; una cella con scritto "Domanda da completare" e' rotta
        completaDallaBanca(clientId, argomentoId, sottoArgomento, richieste, disponibili, ripiego);

        return new Esito(disponibili, totaleRiusate, inserite, dedup.scartate().size(), true);
    }

    /**
     * Riempie le fasce ancora scoperte pescando dalla banca, allentando i
     * vincoli un gradino per volta. Non tocca il vincolo unico su
     * {@code (argomento_id, entita_canonica)}: qui si sceglie fra domande che
     * esistono gia', non se ne creano di nuove.
     */
    private void completaDallaBanca(UUID clientId, Long argomentoId, String sottoArgomento,
                                    Map<Short, Integer> richieste,
                                    Map<Short, List<Domanda>> disponibili,
                                    Ripiego ripiego) {
        Set<Long> giaScelte = disponibili.values().stream()
                .flatMap(List::stream)
                .map(Domanda::getId)
                .collect(Collectors.toCollection(HashSet::new));

        // I gradini si valutano pigramente: il secondo interroga il database
        // solo se il primo non e' bastato
        List<IntFunction<List<Domanda>>> gradini = new ArrayList<>();
        gradini.add(mancano -> domandaRepository.findRipiegoNonUsateDalClient(
                argomentoId, sottoArgomento, clientId,
                esclusioni(giaScelte), PageRequest.ofSize(mancano)));
        if (ripiego == Ripiego.ANCHE_GIA_VISTE) {
            gradini.add(mancano -> domandaRepository.findRipiegoAncheGiaUsate(
                    argomentoId, sottoArgomento,
                    esclusioni(giaScelte), PageRequest.ofSize(mancano)));
        }

        for (Map.Entry<Short, Integer> richiesta : richieste.entrySet()) {
            List<Domanda> lista = disponibili.get(richiesta.getKey());

            for (IntFunction<List<Domanda>> gradino : gradini) {
                int mancano = richiesta.getValue() - lista.size();
                if (mancano <= 0) {
                    break;
                }
                for (Domanda domanda : gradino.apply(mancano)) {
                    if (lista.size() >= richiesta.getValue()) {
                        break;
                    }
                    giaScelte.add(domanda.getId());
                    log.info("Cella completata dalla banca con la domanda {} (fascia {})",
                            domanda.getId(), domanda.getDifficolta());
                    lista.add(domanda);
                }
            }
        }
    }

    /** {@code not in ()} non e' SQL valido: la lista non deve mai essere vuota. */
    private static List<Long> esclusioni(Set<Long> giaScelte) {
        return giaScelte.isEmpty() ? List.of(-1L) : List.copyOf(giaScelte);
    }

    private static Domanda qualsiasiDisponibile(Map<Short, Deque<Domanda>> per) {
        for (Deque<Domanda> coda : per.values()) {
            if (!coda.isEmpty()) {
                return coda.poll();
            }
        }
        return null;
    }

    private List<CandidateQuestion> validateAndNormalize(GenerationOutcome outcome,
                                                         String sottoArgomento) {
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
            // La difficolta' la dichiara il modello: va riportata nella scala
            // ammessa dal CHECK sul database
            short difficolta = (short) Math.clamp(generata.difficolta(), 1, 5);
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

    /** Domande per difficolta', piu' i contatori per l'interfaccia. */
    public record Esito(
            Map<Short, List<Domanda>> perDifficolta,
            int riusate,
            int nuove,
            int scartate,
            boolean chiamataLlm) {
    }
}
