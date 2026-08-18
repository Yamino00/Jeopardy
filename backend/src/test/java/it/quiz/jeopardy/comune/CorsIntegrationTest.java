package it.quiz.jeopardy.comune;

import it.quiz.jeopardy.TestcontainersConfiguration;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The Flutter web client lives on another origin, so every call is preceded
 * by a CORS preflight. Preflights never carry custom headers: if the
 * X-Client-Id filter rejected them, no browser could talk to the API.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class CorsIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @DisplayName("Il preflight CORS passa senza X-Client-Id e riceve gli header")
    void corsPreflight_isAllowedWithoutClientId() throws Exception {
        mockMvc.perform(options("/api/tabelloni")
                        .header("Origin", "http://localhost:5173")
                        .header("Access-Control-Request-Method", "POST")
                        .header("Access-Control-Request-Headers", "x-client-id,content-type"))
                .andExpect(status().isOk())
                .andExpect(header().exists("Access-Control-Allow-Origin"));
    }

    @Test
    @DisplayName("La richiesta vera senza X-Client-Id resta rifiutata")
    void realRequest_stillRequiresClientId() throws Exception {
        mockMvc.perform(options("/api/tabelloni")
                        .header("Origin", "http://localhost:5173")
                        .header("Access-Control-Request-Method", "GET"))
                .andExpect(status().isOk());

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .get("/api/tabelloni")
                        .header("Origin", "http://localhost:5173"))
                .andExpect(status().isBadRequest());
    }
}
