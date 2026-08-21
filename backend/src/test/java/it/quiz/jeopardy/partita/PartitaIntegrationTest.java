package it.quiz.jeopardy.partita;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import it.quiz.jeopardy.TestcontainersConfiguration;
import it.quiz.jeopardy.ia.FakeGeneratorConfiguration;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Fase 5: permissive game flow, and the one invariant that matters —
 * every team's score equals the sum of deltas of its non-cancelled events,
 * after any mix of plays, manual corrections and undos.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import({TestcontainersConfiguration.class, FakeGeneratorConfiguration.class})
class PartitaIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private EventoPartitaRepository eventoPartitaRepository;

    @Autowired
    private PartitaRepository partitaRepository;

    @Autowired
    private PartitaCleanupJob cleanupJob;

    private String clientId() {
        return UUID.randomUUID().toString();
    }

    private JsonNode createBoard(String clientId, String argomento) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/tabelloni")
                        .header("X-Client-Id", clientId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"titolo": "Board partita", "argomenti": ["%s"],
                                 "righe": 3, "punti_base": 100}
                                """.formatted(argomento)))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString());
    }

    private JsonNode startPartita(String clientId, String codiceTabellone) throws Exception {
        MvcResult result = mockMvc.perform(
                        post("/api/tabelloni/" + codiceTabellone + "/partite")
                                .header("X-Client-Id", clientId)
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {"squadre": [{"nome": "Rossi", "colore": "#ff0000"},
                                                     {"nome": "Blu", "colore": "#0000ff"}]}
                                        """))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString());
    }

    private void playCella(String clientId, long partitaId, long cellaId,
                           Long squadraId, String esito, int delta) throws Exception {
        mockMvc.perform(post("/api/partite/" + partitaId + "/celle/" + cellaId)
                        .header("X-Client-Id", clientId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"squadra_id": %s, "esito": "%s", "delta_punti": %d}
                                """.formatted(squadraId, esito, delta)))
                .andExpect(status().isOk());
    }

    private JsonNode getPartita(String clientId, long partitaId) throws Exception {
        MvcResult result = mockMvc.perform(get("/api/partite/" + partitaId)
                        .header("X-Client-Id", clientId))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString());
    }

    @Test
    @DisplayName("Avvio partita: squadre create e turno alla prima")
    void startPartita_setsTeamsAndTurn() throws Exception {
        String client = clientId();
        JsonNode board = createBoard(client, "Partita avvio F5");
        JsonNode partita = startPartita(client, board.get("codice_pubblico").asText());

        assertThat(partita.get("stato").asText()).isEqualTo("in_corso");
        assertThat(partita.get("squadre")).hasSize(2);
        long primaSquadra = partita.get("squadre").get(0).get("id").asLong();
        assertThat(partita.get("turno_squadra_id").asLong()).isEqualTo(primaSquadra);
        assertThat(partita.get("celle_giocate")).isEmpty();
    }

    @Test
    @DisplayName("Punteggio = somma dei delta non annullati dopo sequenza mista")
    void score_isAlwaysSumOfNonCancelledDeltas() throws Exception {
        String client = clientId();
        JsonNode board = createBoard(client, "Partita invariante F5");
        String codice = board.get("codice_pubblico").asText();
        JsonNode partita = startPartita(client, codice);

        long partitaId = partita.get("id").asLong();
        long squadraA = partita.get("squadre").get(0).get("id").asLong();
        long squadraB = partita.get("squadre").get(1).get("id").asLong();
        JsonNode celle = board.get("categorie").get(0).get("celle");
        long cella1 = celle.get(0).get("id").asLong();
        long cella2 = celle.get(1).get("id").asLong();
        long cella3 = celle.get(2).get("id").asLong();

        // Assegnazioni normali
        playCella(client, partitaId, cella1, squadraA, "corretta", 100);
        playCella(client, partitaId, cella2, squadraB, "corretta", 200);

        // Correzione manuale del punteggio di A: 100 -> 250
        mockMvc.perform(patch("/api/partite/" + partitaId + "/squadre/" + squadraA)
                        .header("X-Client-Id", client)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"punteggio\": 250}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.punteggio").value(250));

        // Risposta errata di A sulla terza cella
        playCella(client, partitaId, cella3, squadraA, "errata", -300);

        JsonNode dopoErrata = getPartita(client, partitaId);
        assertThat(punteggioDi(dopoErrata, squadraA)).isEqualTo(-50);

        // Annulla l'ultimo evento (la giocata errata)
        mockMvc.perform(post("/api/partite/" + partitaId + "/annulla")
                        .header("X-Client-Id", client))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.annullato").value(true));

        JsonNode statoFinale = getPartita(client, partitaId);
        int punteggioA = punteggioDi(statoFinale, squadraA);
        int punteggioB = punteggioDi(statoFinale, squadraB);
        assertThat(punteggioA).isEqualTo(250);
        assertThat(punteggioB).isEqualTo(200);

        // L'invariante: punteggio == somma dei delta degli eventi non annullati
        assertThat(punteggioA)
                .isEqualTo(eventoPartitaRepository.sumDeltaBySquadra(partitaId, squadraA));
        assertThat(punteggioB)
                .isEqualTo(eventoPartitaRepository.sumDeltaBySquadra(partitaId, squadraB));

        // La cella annullata e di nuovo giocabile
        assertThat(statoFinale.get("celle_giocate")).hasSize(2);
        playCella(client, partitaId, cella3, squadraB, "corretta", 300);
        assertThat(punteggioDi(getPartita(client, partitaId), squadraB)).isEqualTo(500);
    }

    @Test
    @DisplayName("Cella gia giocata -> 409")
    void playingSameCellTwice_is409() throws Exception {
        String client = clientId();
        JsonNode board = createBoard(client, "Partita doppia cella F5");
        JsonNode partita = startPartita(client, board.get("codice_pubblico").asText());
        long partitaId = partita.get("id").asLong();
        long squadraA = partita.get("squadre").get(0).get("id").asLong();
        long cella = board.get("categorie").get(0).get("celle").get(0).get("id").asLong();

        playCella(client, partitaId, cella, squadraA, "corretta", 100);
        mockMvc.perform(post("/api/partite/" + partitaId + "/celle/" + cella)
                        .header("X-Client-Id", client)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"squadra_id\": %d, \"esito\": \"corretta\", \"delta_punti\": 100}"
                                .formatted(squadraA)))
                .andExpect(status().isConflict());
    }

    @Test
    @DisplayName("Squadre: aggiunta a partita iniziata, rinomina, soft delete")
    void teams_areFullyEditableMidGame() throws Exception {
        String client = clientId();
        JsonNode board = createBoard(client, "Partita squadre F5");
        JsonNode partita = startPartita(client, board.get("codice_pubblico").asText());
        long partitaId = partita.get("id").asLong();
        long squadraA = partita.get("squadre").get(0).get("id").asLong();

        // Aggiunta in corsa, nome duplicato ammesso
        mockMvc.perform(post("/api/partite/" + partitaId + "/squadre")
                        .header("X-Client-Id", client)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nome\": \"Rossi\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.posizione").value(3));

        // Rinomina e cambio colore
        mockMvc.perform(patch("/api/partite/" + partitaId + "/squadre/" + squadraA)
                        .header("X-Client-Id", client)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nome\": \"Rossi Reloaded\", \"colore\": \"#cc0000\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nome").value("Rossi Reloaded"));

        // Soft delete: la squadra resta nello stato ma inattiva
        mockMvc.perform(delete("/api/partite/" + partitaId + "/squadre/" + squadraA)
                        .header("X-Client-Id", client))
                .andExpect(status().isNoContent());

        JsonNode stato = getPartita(client, partitaId);
        JsonNode squadraDto = null;
        for (JsonNode s : stato.get("squadre")) {
            if (s.get("id").asLong() == squadraA) {
                squadraDto = s;
            }
        }
        assertThat(squadraDto).isNotNull();
        assertThat(squadraDto.get("attiva").asBoolean()).isFalse();
    }

    @Test
    @DisplayName("Concludi: stato finale e nessuna giocata ulteriore")
    void concludi_freezesTheGame() throws Exception {
        String client = clientId();
        JsonNode board = createBoard(client, "Partita conclusa F5");
        JsonNode partita = startPartita(client, board.get("codice_pubblico").asText());
        long partitaId = partita.get("id").asLong();
        long squadraA = partita.get("squadre").get(0).get("id").asLong();
        long cella = board.get("categorie").get(0).get("celle").get(0).get("id").asLong();

        mockMvc.perform(post("/api/partite/" + partitaId + "/concludi")
                        .header("X-Client-Id", client))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stato").value("conclusa"));

        mockMvc.perform(post("/api/partite/" + partitaId + "/celle/" + cella)
                        .header("X-Client-Id", client)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"squadra_id\": %d, \"esito\": \"corretta\", \"delta_punti\": 100}"
                                .formatted(squadraA)))
                .andExpect(status().isConflict());
    }

    @Test
    @DisplayName("A partita conclusa il server rifiuta anche modifiche e annullamenti")
    void concludi_alsoBlocksSquadreAndUndo() throws Exception {
        String client = clientId();
        JsonNode board = createBoard(client, "Partita bloccata F5");
        JsonNode partita = startPartita(client, board.get("codice_pubblico").asText());
        long partitaId = partita.get("id").asLong();
        long squadraA = partita.get("squadre").get(0).get("id").asLong();

        mockMvc.perform(post("/api/partite/" + partitaId + "/concludi")
                        .header("X-Client-Id", client))
                .andExpect(status().isOk());

        // Il client gia' impone questi tre divieti: prima il server no, ed
        // era il server a essere piu' permissivo del suo unico chiamante
        mockMvc.perform(patch("/api/partite/" + partitaId + "/squadre/" + squadraA)
                        .header("X-Client-Id", client)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"punteggio\": 9999}"))
                .andExpect(status().isConflict());

        mockMvc.perform(delete("/api/partite/" + partitaId + "/squadre/" + squadraA)
                        .header("X-Client-Id", client))
                .andExpect(status().isConflict());

        mockMvc.perform(post("/api/partite/" + partitaId + "/annulla")
                        .header("X-Client-Id", client))
                .andExpect(status().isConflict());
    }

    @Test
    @DisplayName("Annulla senza eventi: 200 con annullato=false, non un errore")
    void undoWithNothingToUndo_is200NotAnError() throws Exception {
        String client = clientId();
        JsonNode board = createBoard(client, "Partita appena aperta F5");
        JsonNode partita = startPartita(client, board.get("codice_pubblico").asText());
        long partitaId = partita.get("id").asLong();

        // Nessuna giocata: e' lo stato normale a partita appena cominciata, e
        // l'host che preme annulla di riflesso non deve vedere un errore
        mockMvc.perform(post("/api/partite/" + partitaId + "/annulla")
                        .header("X-Client-Id", client))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.annullato").value(false))
                .andExpect(jsonPath("$.evento").isEmpty());
    }

    @Test
    @DisplayName("Il job di pulizia rimuove solo le partite scadute non concluse")
    void cleanupJob_removesOnlyExpiredUnfinishedGames() throws Exception {
        String client = clientId();
        JsonNode board = createBoard(client, "Partita pulizia F5");
        String codice = board.get("codice_pubblico").asText();

        long scaduta = startPartita(client, codice).get("id").asLong();
        long inCorso = startPartita(client, codice).get("id").asLong();
        long conclusaScaduta = startPartita(client, codice).get("id").asLong();

        mockMvc.perform(post("/api/partite/" + conclusaScaduta + "/concludi")
                        .header("X-Client-Id", client))
                .andExpect(status().isOk());

        Instant passato = Instant.now().minus(1, ChronoUnit.DAYS);
        for (long id : List.of(scaduta, conclusaScaduta)) {
            Partita p = partitaRepository.findById(id).orElseThrow();
            p.setScadeIl(passato);
            partitaRepository.save(p);
        }

        cleanupJob.pulisciPartiteScadute();

        assertThat(partitaRepository.findById(scaduta)).isEmpty();
        assertThat(partitaRepository.findById(inCorso)).isPresent();
        assertThat(partitaRepository.findById(conclusaScaduta)).isPresent();
    }

    private static int punteggioDi(JsonNode partita, long squadraId) {
        for (JsonNode squadra : partita.get("squadre")) {
            if (squadra.get("id").asLong() == squadraId) {
                return squadra.get("punteggio").asInt();
            }
        }
        throw new AssertionError("Squadra " + squadraId + " non trovata");
    }
}
