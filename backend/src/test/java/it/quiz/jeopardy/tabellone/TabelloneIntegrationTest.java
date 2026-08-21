package it.quiz.jeopardy.tabellone;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import it.quiz.jeopardy.TestcontainersConfiguration;
import it.quiz.jeopardy.banca.Argomento;
import it.quiz.jeopardy.banca.ArgomentoRepository;
import it.quiz.jeopardy.banca.Domanda;
import it.quiz.jeopardy.banca.DomandaRepository;
import it.quiz.jeopardy.banca.StatoDomanda;
import it.quiz.jeopardy.comune.Normalizer;
import it.quiz.jeopardy.ia.FakeGeneratorConfiguration;
import it.quiz.jeopardy.ia.FakeQuestionGenerator;
import it.quiz.jeopardy.ia.GenerationOutcome;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Fase 4 requirements: full board creation, no duplicate cells, wrong edit
 * code rejected, overrides never touching the shared question bank.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import({TestcontainersConfiguration.class, FakeGeneratorConfiguration.class})
class TabelloneIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private DomandaRepository domandaRepository;

    @Autowired
    private ArgomentoRepository argomentoRepository;

    @Autowired
    private FakeQuestionGenerator fakeGenerator;

    @BeforeEach
    void resetFake() {
        fakeGenerator.reset();
    }

    /**
     * Porta a RITIRATA ogni domanda dell'argomento: le celle gia' create
     * continuano a mostrarla, ma nessuna query di ripiego la ripesca.
     */
    private void ritiraTutteLeDomande(String nomeArgomento) {
        String slug = Normalizer.toCanonical(nomeArgomento).replace(' ', '-');
        Argomento argomento = argomentoRepository.findBySlugAndLingua(slug, "it").orElseThrow();
        List<Domanda> attive = domandaRepository
                .findByArgomentoIdAndStato(argomento.getId(), StatoDomanda.ATTIVA);
        attive.forEach(d -> d.setStato(StatoDomanda.RITIRATA));
        domandaRepository.saveAll(attive);
    }

    private JsonNode createBoard(String clientId, String titolo, String... argomenti) throws Exception {
        StringBuilder args = new StringBuilder();
        for (String a : argomenti) {
            if (args.length() > 0) {
                args.append(',');
            }
            args.append('"').append(a).append('"');
        }
        String body = """
                {"titolo": "%s", "argomenti": [%s], "righe": 3, "punti_base": 100}
                """.formatted(titolo, args);
        MvcResult result = mockMvc.perform(post("/api/tabelloni")
                        .header("X-Client-Id", clientId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString());
    }

    @Test
    @DisplayName("Creazione completa: codici validi, celle piene, valori corretti")
    void createBoard_isComplete() throws Exception {
        String clientId = UUID.randomUUID().toString();
        JsonNode board = createBoard(clientId, "Quiz storia", "Storia romana FASE4", "Geografia FASE4");

        assertThat(board.get("codice_pubblico").asText())
                .hasSize(6)
                .matches("[" + CodeGenerator.ALPHABET + "]{6}");
        assertThat(board.get("codice_modifica").asText())
                .hasSize(12)
                .matches("[" + CodeGenerator.ALPHABET + "]{12}");

        JsonNode categorie = board.get("categorie");
        assertThat(categorie).hasSize(2);
        for (JsonNode categoria : categorie) {
            JsonNode celle = categoria.get("celle");
            assertThat(celle).hasSize(3);
            for (JsonNode cella : celle) {
                int riga = cella.get("riga").asInt();
                assertThat(cella.get("valore").asInt()).isEqualTo(100 * riga);
                assertThat(cella.get("testo").asText()).isNotBlank();
                assertThat(cella.get("risposta").asText()).isNotNull();
            }
        }
    }

    @Test
    @DisplayName("Nessuna cella duplicata nel tabellone")
    void createBoard_hasNoDuplicateCells() throws Exception {
        String clientId = UUID.randomUUID().toString();
        JsonNode board = createBoard(clientId, "No dup", "Cinema FASE4", "Musica FASE4");

        Set<String> testi = new HashSet<>();
        int count = 0;
        for (JsonNode categoria : board.get("categorie")) {
            for (JsonNode cella : categoria.get("celle")) {
                testi.add(cella.get("testo").asText());
                count++;
            }
        }
        assertThat(testi).hasSize(count);
    }

    @Test
    @DisplayName("GET pubblico non espone il codice modifica")
    void publicGet_hidesEditCode() throws Exception {
        String clientId = UUID.randomUUID().toString();
        JsonNode board = createBoard(clientId, "Nascosto", "Arte FASE4");

        mockMvc.perform(get("/api/tabelloni/" + board.get("codice_pubblico").asText())
                        .header("X-Client-Id", clientId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.codice_pubblico").exists())
                .andExpect(jsonPath("$.codice_modifica").doesNotExist());
    }

    @Test
    @DisplayName("PUT con codice modifica errato -> 403")
    void update_withWrongEditCode_is403() throws Exception {
        String clientId = UUID.randomUUID().toString();
        JsonNode board = createBoard(clientId, "Protetto", "Scienza FASE4");

        mockMvc.perform(put("/api/tabelloni/" + board.get("codice_pubblico").asText())
                        .header("X-Client-Id", clientId)
                        .header("X-Codice-Modifica", "CODICESBAGLIATO")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"titolo\": \"Hack\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Override della cella: la domanda condivisa non cambia")
    void cellOverride_doesNotTouchSharedQuestion() throws Exception {
        String clientId = UUID.randomUUID().toString();
        JsonNode board = createBoard(clientId, "Override", "Letteratura FASE4");

        String codice = board.get("codice_pubblico").asText();
        String codiceModifica = board.get("codice_modifica").asText();
        JsonNode cella = board.get("categorie").get(0).get("celle").get(0);
        long cellaId = cella.get("id").asLong();
        String testoOriginale = cella.get("testo").asText();

        mockMvc.perform(put("/api/tabelloni/" + codice)
                        .header("X-Client-Id", clientId)
                        .header("X-Codice-Modifica", codiceModifica)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"titolo": "Override rinominato",
                                 "celle": [{"id": %d, "testo": "Testo personalizzato?",
                                            "risposta": "Risposta personalizzata"}]}
                                """.formatted(cellaId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.titolo").value("Override rinominato"));

        // Il GET mostra l'override
        MvcResult after = mockMvc.perform(get("/api/tabelloni/" + codice)
                        .header("X-Client-Id", clientId))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode updated = objectMapper.readTree(after.getResponse().getContentAsString());
        assertThat(updated.get("categorie").get(0).get("celle").get(0).get("testo").asText())
                .isEqualTo("Testo personalizzato?");

        // La domanda in banca e rimasta quella originale
        assertThat(domandaRepository.findAll())
                .extracting(Domanda::getTesto)
                .contains(testoOriginale)
                .doesNotContain("Testo personalizzato?");

        // E la cella non espone piu' un id da segnalare: il testo a schermo e'
        // dell'host, non della banca
        assertThat(updated.get("categorie").get(0).get("celle").get(0)
                .get("domanda_id").isNull()).isTrue();
    }

    @Test
    @DisplayName("Ogni cella espone l'id della domanda, che rende segnalabile la cella")
    void cells_exposeQuestionId() throws Exception {
        String clientId = UUID.randomUUID().toString();
        JsonNode board = createBoard(clientId, "Segnalabile", "Astronomia FASE4");

        for (JsonNode categoria : board.get("categorie")) {
            for (JsonNode cella : categoria.get("celle")) {
                long domandaId = cella.get("domanda_id").asLong();
                assertThat(domandaId).isPositive();
                assertThat(domandaRepository.findById(domandaId)).isPresent();
            }
        }
    }

    @Test
    @DisplayName("Rigenera cella: la domanda cambia e gli override si azzerano")
    void regenerateCell_swapsQuestion() throws Exception {
        String clientId = UUID.randomUUID().toString();
        JsonNode board = createBoard(clientId, "Rigenera", "Sport FASE4");

        String codice = board.get("codice_pubblico").asText();
        String codiceModifica = board.get("codice_modifica").asText();
        JsonNode cella = board.get("categorie").get(0).get("celle").get(0);
        long cellaId = cella.get("id").asLong();
        String testoPrima = cella.get("testo").asText();

        MvcResult result = mockMvc.perform(
                        post("/api/tabelloni/" + codice + "/celle/" + cellaId + "/rigenera")
                                .header("X-Client-Id", clientId)
                                .header("X-Codice-Modifica", codiceModifica))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode esito = objectMapper.readTree(result.getResponse().getContentAsString());
        assertThat(esito.get("rigenerata").asBoolean()).isTrue();
        assertThat(esito.get("cella").get("testo").asText()).isNotEqualTo(testoPrima);
    }

    @Test
    @DisplayName("Rigenera senza alternative: 200 con rigenerata=false, non un errore")
    void regenerateWithoutAlternatives_is200NotAnError() throws Exception {
        String clientId = UUID.randomUUID().toString();
        String argomento = "Argomento senza scorte FASE4";
        JsonNode board = createBoard(clientId, "Esaurito", argomento);

        String codice = board.get("codice_pubblico").asText();
        String codiceModifica = board.get("codice_modifica").asText();
        long cellaId = board.get("categorie").get(0).get("celle").get(0).get("id").asLong();

        // Svuota la banca per questo argomento: le domande gia' sul tabellone
        // restano visibili, ma nessuna e' piu' pescabile
        ritiraTutteLeDomande(argomento);
        // E l'IA non produce niente di nuovo. Insieme, e' la condizione
        // "argomento esaurito", che e' un esito normale del gioco
        fakeGenerator.enqueue(new GenerationOutcome(List.of(), "fake-model", 0, 0));

        mockMvc.perform(post("/api/tabelloni/" + codice + "/celle/" + cellaId + "/rigenera")
                        .header("X-Client-Id", clientId)
                        .header("X-Codice-Modifica", codiceModifica))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rigenerata").value(false))
                .andExpect(jsonPath("$.motivo").value("nessuna_alternativa_disponibile"))
                .andExpect(jsonPath("$.cella.id").value(cellaId));
    }

    @Test
    @DisplayName("Ogni tabellone ha una e una sola cella Daily Double, mai sulla riga piu' facile")
    void everyBoard_hasExactlyOneDailyDouble() throws Exception {
        JsonNode board = createBoard(UUID.randomUUID().toString(),
                "Con Daily Double", "Geografia FASE4");

        List<JsonNode> dailyDoubles = new ArrayList<>();
        for (JsonNode categoria : board.get("categorie")) {
            for (JsonNode cella : categoria.get("celle")) {
                if (cella.get("daily_double").asBoolean()) {
                    dailyDoubles.add(cella);
                }
            }
        }

        assertThat(dailyDoubles).hasSize(1);
        assertThat(dailyDoubles.get(0).get("riga").asInt())
                .as("raddoppiare la posta piu' bassa non cambierebbe niente")
                .isGreaterThan(1);
    }

    @Test
    @DisplayName("Nessuna cella segnaposto: ogni cella ha una domanda vera")
    void noBoardCell_isAPlaceholder() throws Exception {
        JsonNode board = createBoard(UUID.randomUUID().toString(),
                "Senza buchi", "Musica FASE4");

        for (JsonNode categoria : board.get("categorie")) {
            for (JsonNode cella : categoria.get("celle")) {
                assertThat(cella.get("testo").asText())
                        .isNotBlank()
                        .isNotEqualTo("Domanda da completare");
                assertThat(cella.get("risposta").asText()).isNotBlank();
                assertThat(cella.get("domanda_id").isNull())
                        .as("una cella senza domanda condivisa non e' segnalabile")
                        .isFalse();
            }
        }
    }

    @Test
    @DisplayName("Lista dei propri tabelloni")
    void listMine_returnsOwnBoards() throws Exception {
        String clientId = UUID.randomUUID().toString();
        createBoard(clientId, "Mio tabellone", "Filosofia FASE4");

        mockMvc.perform(get("/api/tabelloni")
                        .header("X-Client-Id", clientId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].titolo").value("Mio tabellone"));

        mockMvc.perform(get("/api/tabelloni")
                        .header("X-Client-Id", UUID.randomUUID().toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isEmpty());
    }

    @Test
    @DisplayName("Oltre 3 segnalazioni la domanda passa a 'segnalata'")
    void beyondThreeReports_questionBecomesSegnalata() throws Exception {
        Argomento arg = argomentoRepository.save(
                new Argomento("seg-fase4", "seg-fase4"));
        Domanda domanda = new Domanda();
        domanda.setArgomento(arg);
        domanda.setTesto("Domanda da segnalare?");
        domanda.setRisposta("Risposta contestata");
        domanda.setEntitaCanonica(Normalizer.toCanonical("Risposta contestata"));
        domanda.setHashTesto(Normalizer.hashTesto("Domanda da segnalare?"));
        domanda.setDifficolta((short) 2);
        domanda = domandaRepository.save(domanda);

        for (int i = 0; i < 4; i++) {
            mockMvc.perform(post("/api/domande/" + domanda.getId() + "/segnalazioni")
                            .header("X-Client-Id", UUID.randomUUID().toString())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"motivo\": \"errata\", \"nota\": \"non torna\"}"))
                    .andExpect(status().isCreated());
        }

        Domanda ricaricata = domandaRepository.findById(domanda.getId()).orElseThrow();
        assertThat(ricaricata.getSegnalazioni()).isEqualTo(4);
        assertThat(ricaricata.getStato()).isEqualTo(StatoDomanda.SEGNALATA);
    }
}
