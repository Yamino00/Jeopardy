package it.quiz.jeopardy.ia;

import it.quiz.jeopardy.TestcontainersConfiguration;
import it.quiz.jeopardy.banca.Argomento;
import it.quiz.jeopardy.banca.ArgomentoRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end check of the quota: beyond the daily limit the endpoint
 * must answer 429 with a Problem Detail body.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import({TestcontainersConfiguration.class, FakeGeneratorConfiguration.class})
@TestPropertySource(properties = "app.ia.quota-giornaliera=2")
class GenerazioneControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ArgomentoRepository argomentoRepository;

    @Test
    @DisplayName("Oltre la quota giornaliera l'endpoint risponde 429")
    void beyondDailyQuota_returns429() throws Exception {
        // Un argomento nuovo per ogni chiamata: la banca e vuota per quella cella,
        // quindi ogni richiesta arriva all'LLM e consuma quota
        String clientId = UUID.randomUUID().toString();

        for (int i = 0; i < 2; i++) {
            Argomento arg = argomentoRepository.save(
                    new Argomento("quota-" + i, "quota-" + i));
            mockMvc.perform(post("/api/generazioni")
                            .header("X-Client-Id", clientId)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(bodyFor(arg)))
                    .andExpect(status().isOk());
        }

        Argomento arg = argomentoRepository.save(new Argomento("quota-3", "quota-3"));
        mockMvc.perform(post("/api/generazioni")
                        .header("X-Client-Id", clientId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bodyFor(arg)))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.title").value("Quota Exceeded"));
    }

    private static String bodyFor(Argomento arg) {
        return """
                {"argomento_id": %d, "difficolta": 3, "numero": 2}
                """.formatted(arg.getId());
    }

    @Test
    @DisplayName("Senza X-Client-Id la richiesta viene rifiutata")
    void missingClientId_isRejected() throws Exception {
        mockMvc.perform(post("/api/generazioni")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"argomento_id\": 1, \"difficolta\": 3, \"numero\": 2}"))
                .andExpect(status().is4xxClientError());
    }

    @Test
    @DisplayName("Input non valido: difficolta fuori scala -> 400")
    void invalidDifficolta_returns400() throws Exception {
        mockMvc.perform(post("/api/generazioni")
                        .header("X-Client-Id", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"argomento_id\": 1, \"difficolta\": 9, \"numero\": 2}"))
                .andExpect(status().isBadRequest());
    }
}
