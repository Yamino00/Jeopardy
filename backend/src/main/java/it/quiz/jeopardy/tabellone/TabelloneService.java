package it.quiz.jeopardy.tabellone;

import it.quiz.jeopardy.banca.Argomento;
import it.quiz.jeopardy.banca.ArgomentoRepository;
import it.quiz.jeopardy.banca.Domanda;
import it.quiz.jeopardy.banca.DomandaRepository;
import it.quiz.jeopardy.comune.ForbiddenException;
import it.quiz.jeopardy.comune.Normalizer;
import it.quiz.jeopardy.comune.ResourceNotFoundException;
import it.quiz.jeopardy.ia.GenerationResultDto;
import it.quiz.jeopardy.ia.GenerationService;
import it.quiz.jeopardy.tabellone.TabelloneDtos.CreateTabelloneRequest;
import it.quiz.jeopardy.tabellone.TabelloneDtos.TabelloneDto;
import it.quiz.jeopardy.tabellone.TabelloneDtos.TabelloneSintesiDto;
import it.quiz.jeopardy.tabellone.TabelloneDtos.UpdateTabelloneRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import static org.springframework.http.HttpStatus.BAD_REQUEST;

/**
 * Board lifecycle. Cell selection always goes through
 * {@link GenerationService}: bank first (excluding questions already used by
 * this client, least-used first), LLM only for what is missing. Every question
 * placed on a board increments {@code volte_usata}.
 */
@Service
public class TabelloneService {

    private static final Logger log = LoggerFactory.getLogger(TabelloneService.class);

    private final TabelloneRepository tabelloneRepository;
    private final CellaRepository cellaRepository;
    private final ArgomentoRepository argomentoRepository;
    private final DomandaRepository domandaRepository;
    private final GenerationService generationService;
    private final CodeGenerator codeGenerator;
    private final short righeDefault;
    private final int puntiBaseDefault;
    private final String lingua;
    private final String placeholderTesto;

    public TabelloneService(TabelloneRepository tabelloneRepository,
                            CellaRepository cellaRepository,
                            ArgomentoRepository argomentoRepository,
                            DomandaRepository domandaRepository,
                            GenerationService generationService,
                            CodeGenerator codeGenerator,
                            @Value("${app.tabellone.righe-default:5}") short righeDefault,
                            @Value("${app.tabellone.punti-base-default:200}") int puntiBaseDefault,
                            @Value("${app.lingua:it}") String lingua,
                            @Value("${app.tabellone.placeholder-testo:Domanda da completare}")
                            String placeholderTesto) {
        this.tabelloneRepository = tabelloneRepository;
        this.cellaRepository = cellaRepository;
        this.argomentoRepository = argomentoRepository;
        this.domandaRepository = domandaRepository;
        this.generationService = generationService;
        this.codeGenerator = codeGenerator;
        this.righeDefault = righeDefault;
        this.puntiBaseDefault = puntiBaseDefault;
        this.lingua = lingua;
        this.placeholderTesto = placeholderTesto;
    }

    @Transactional
    public TabelloneDto create(UUID clientId, CreateTabelloneRequest request) {
        List<String> nomi = request.argomenti().stream().map(String::strip).toList();
        if (Set.copyOf(nomi.stream().map(Normalizer::toCanonical).toList()).size() < nomi.size()) {
            throw new ResponseStatusException(BAD_REQUEST, "Argomenti duplicati nella richiesta");
        }

        Tabellone tabellone = new Tabellone();
        tabellone.setTitolo(request.titolo().strip());
        tabellone.setClientCreatore(clientId);
        tabellone.setRighe(request.righe() == null ? righeDefault : request.righe());
        tabellone.setPuntiBase(request.puntiBase() == null ? puntiBaseDefault : request.puntiBase());
        tabellone.setCodicePubblico(uniquePublicCode());
        tabellone.setCodiceModifica(codeGenerator.editCode());

        short posizione = 1;
        for (String nome : nomi) {
            Argomento argomento = findOrCreateArgomento(nome);
            Categoria categoria = new Categoria();
            categoria.setArgomento(argomento);
            categoria.setNomeDisplay(nome);
            categoria.setPosizione(posizione++);
            tabellone.addCategoria(categoria);
            fillCategoria(clientId, tabellone, categoria);
        }
        return TabelloneDto.from(tabelloneRepository.save(tabellone), true);
    }

    private void fillCategoria(UUID clientId, Tabellone tabellone, Categoria categoria) {
        // Group rows by difficulty band so each band costs at most one LLM call
        Map<Short, List<Short>> rowsByDifficulty = new HashMap<>();
        for (short riga = 1; riga <= tabellone.getRighe(); riga++) {
            rowsByDifficulty
                    .computeIfAbsent(difficultyForRow(riga, tabellone.getRighe()), k -> new java.util.ArrayList<>())
                    .add(riga);
        }

        for (Map.Entry<Short, List<Short>> band : rowsByDifficulty.entrySet()) {
            List<Short> righe = band.getValue();
            GenerationResultDto generated = generationService.generate(
                    clientId, categoria.getArgomento().getId(), null,
                    band.getKey(), righe.size());

            for (int i = 0; i < righe.size(); i++) {
                short riga = righe.get(i);
                Cella cella = new Cella();
                cella.setRiga(riga);
                cella.setValore(tabellone.getPuntiBase() * riga);
                if (i < generated.domande().size()) {
                    Domanda domanda = domandaRepository
                            .findById(generated.domande().get(i).id()).orElseThrow();
                    domanda.setVolteUsata(domanda.getVolteUsata() + 1);
                    cella.setDomanda(domanda);
                } else {
                    // Not enough questions survived dedup: leave an editable
                    // placeholder instead of failing the whole board
                    log.warn("Cella senza domanda per argomento {} difficolta {}: placeholder",
                            categoria.getNomeDisplay(), band.getKey());
                    cella.setTestoOverride(placeholderTesto);
                    cella.setRispostaOverride("");
                }
                categoria.addCella(cella);
            }
        }
    }

    /** Linear map of row index onto the 1..5 difficulty scale. */
    static short difficultyForRow(short riga, short righe) {
        if (righe <= 1) {
            return 3;
        }
        return (short) Math.round(1 + (riga - 1) * 4.0 / (righe - 1));
    }

    private Argomento findOrCreateArgomento(String nome) {
        String slug = Normalizer.toCanonical(nome).replace(' ', '-');
        return argomentoRepository.findBySlugAndLingua(slug, lingua)
                .orElseGet(() -> argomentoRepository.save(new Argomento(nome, slug)));
    }

    private String uniquePublicCode() {
        for (int attempt = 0; attempt < 10; attempt++) {
            String code = codeGenerator.publicCode();
            if (!tabelloneRepository.existsByCodicePubblico(code)) {
                return code;
            }
        }
        throw new IllegalStateException("Impossibile generare un codice pubblico unico");
    }

    @Transactional(readOnly = true)
    public TabelloneDto get(String codicePubblico) {
        return TabelloneDto.from(loadByCodice(codicePubblico), false);
    }

    @Transactional(readOnly = true)
    public List<TabelloneSintesiDto> listByClient(UUID clientId) {
        return tabelloneRepository.findByClientCreatoreOrderByCreatoIlDesc(clientId)
                .stream().map(TabelloneSintesiDto::from).toList();
    }

    @Transactional
    public TabelloneDto update(String codicePubblico, String codiceModifica,
                               UpdateTabelloneRequest request) {
        Tabellone tabellone = loadByCodice(codicePubblico);
        requireEditCode(tabellone, codiceModifica);

        if (request.titolo() != null && !request.titolo().isBlank()) {
            tabellone.setTitolo(request.titolo().strip());
        }
        if (request.categorie() != null) {
            for (UpdateTabelloneRequest.CategoriaUpdate update : request.categorie()) {
                Categoria categoria = tabellone.getCategorie().stream()
                        .filter(c -> c.getId().equals(update.id()))
                        .findFirst()
                        .orElseThrow(() -> new ResourceNotFoundException(
                                "Categoria " + update.id() + " non trovata nel tabellone"));
                if (update.nomeDisplay() != null && !update.nomeDisplay().isBlank()) {
                    categoria.setNomeDisplay(update.nomeDisplay().strip());
                }
            }
        }
        if (request.celle() != null) {
            for (UpdateTabelloneRequest.CellaUpdate update : request.celle()) {
                Cella cella = findCella(tabellone, update.id());
                // Overrides only: the shared question must never change
                if (update.testo() != null) {
                    cella.setTestoOverride(update.testo());
                }
                if (update.risposta() != null) {
                    cella.setRispostaOverride(update.risposta());
                }
            }
        }
        return TabelloneDto.from(tabellone, false);
    }

    @Transactional
    public TabelloneDtos.CellaDto rigenera(String codicePubblico, String codiceModifica,
                                           Long cellaId) {
        Tabellone tabellone = loadByCodice(codicePubblico);
        requireEditCode(tabellone, codiceModifica);
        Cella cella = findCella(tabellone, cellaId);
        Categoria categoria = cella.getCategoria();
        if (categoria.getArgomento() == null) {
            throw new ResponseStatusException(BAD_REQUEST,
                    "La categoria non ha un argomento: impossibile rigenerare");
        }

        // The creator's client id drives both the used-questions exclusion
        // (the current question is on this board, so it cannot come back)
        // and the quota
        GenerationResultDto generated = generationService.generate(
                tabellone.getClientCreatore(), categoria.getArgomento().getId(), null,
                difficultyForRow(cella.getRiga(), tabellone.getRighe()), 1);
        if (generated.domande().isEmpty()) {
            throw new ResponseStatusException(org.springframework.http.HttpStatus.CONFLICT,
                    "Nessuna domanda alternativa disponibile per questa cella");
        }

        Domanda nuova = domandaRepository
                .findById(generated.domande().get(0).id()).orElseThrow();
        nuova.setVolteUsata(nuova.getVolteUsata() + 1);
        cella.setDomanda(nuova);
        cella.setTestoOverride(null);
        cella.setRispostaOverride(null);
        return TabelloneDtos.CellaDto.from(cella);
    }

    private Tabellone loadByCodice(String codicePubblico) {
        return tabelloneRepository.findByCodicePubblico(codicePubblico)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Tabellone " + codicePubblico + " non trovato"));
    }

    private Cella findCella(Tabellone tabellone, Long cellaId) {
        return tabellone.getCategorie().stream()
                .flatMap(c -> c.getCelle().stream())
                .filter(c -> c.getId().equals(cellaId))
                .findFirst()
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Cella " + cellaId + " non trovata nel tabellone"));
    }

    private static void requireEditCode(Tabellone tabellone, String codiceModifica) {
        if (codiceModifica == null || !codiceModifica.equals(tabellone.getCodiceModifica())) {
            throw new ForbiddenException("Codice modifica errato");
        }
    }
}
