package it.quiz.jeopardy.ia;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.server.ResponseStatusException;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Provider backed by Groq, whose API is OpenAI-compatible. Serves the same
 * prompt as Gemini so the questions keep the same shape; having a second
 * backend is what keeps board creation working when one of the two is
 * rate-limited or overloaded.
 */
@Component
public class GroqQuestionGenerator implements LlmProvider {

    private static final Logger log = LoggerFactory.getLogger(GroqQuestionGenerator.class);

    private final ObjectMapper objectMapper;
    private final String endpoint;
    private final String apiKey;
    private final String modello;
    private final double temperature;

    private volatile RestClient restClient;

    public GroqQuestionGenerator(ObjectMapper objectMapper,
                                 @Value("${app.ia.groq.endpoint}") String endpoint,
                                 @Value("${app.ia.groq.api-key:}") String apiKey,
                                 @Value("${app.ia.groq.modello}") String modello,
                                 @Value("${app.ia.groq.temperature:0.9}") double temperature) {
        this.objectMapper = objectMapper;
        this.endpoint = endpoint;
        this.apiKey = apiKey;
        this.modello = modello;
        this.temperature = temperature;
    }

    @Override
    public String nome() {
        return "groq/" + modello;
    }

    @Override
    public boolean configurato() {
        return apiKey != null && !apiKey.isBlank();
    }

    private RestClient restClient() {
        RestClient client = restClient;
        if (client == null) {
            synchronized (this) {
                if (restClient == null) {
                    restClient = RestClient.builder().baseUrl(endpoint).build();
                }
                client = restClient;
            }
        }
        return client;
    }

    @Override
    public GenerationOutcome generate(GenerationRequest request) {
        if (!configurato()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Groq non configurato: impostare GROQ_API_KEY");
        }

        Map<String, Object> body = Map.of(
                "model", modello,
                "temperature", temperature,
                "response_format", Map.of("type", "json_object"),
                "messages", List.of(Map.of(
                        "role", "user",
                        "content", PromptBuilder.build(request))));

        String rawResponse;
        try {
            rawResponse = restClient().post()
                    .uri("/chat/completions")
                    .header("Authorization", "Bearer " + apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(String.class);
        } catch (HttpStatusCodeException ex) {
            throw translateUpstreamError(ex);
        } catch (RestClientException ex) {
            log.warn("Chiamata a Groq fallita", ex);
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "Servizio di generazione non raggiungibile", ex);
        }

        return parseResponse(rawResponse);
    }

    private ResponseStatusException translateUpstreamError(HttpStatusCodeException ex) {
        int status = ex.getStatusCode().value();
        log.warn("Groq ha risposto {} per il modello {}: {}",
                status, modello, ex.getResponseBodyAsString());

        return switch (status) {
            case 401, 403 -> new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Chiave Groq non valida o senza accesso al modello " + modello);
            case 404 -> new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Il modello '" + modello + "' non esiste su Groq: "
                            + "aggiornare app.ia.groq.modello");
            case 429 -> new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                    "Limite di frequenza Groq raggiunto: riprovare fra poco");
            case 503 -> new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Il modello " + modello + " e' sovraccarico: riprovare fra poco");
            default -> new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "Errore dal servizio di generazione (HTTP " + status + ")");
        };
    }

    private GenerationOutcome parseResponse(String rawResponse) {
        String text = "";
        String finishReason = "?";
        try {
            JsonNode root = objectMapper.readTree(rawResponse);
            JsonNode choice = root.path("choices").path(0);
            finishReason = choice.path("finish_reason").asText("?");
            text = choice.path("message").path("content").asText("");
            JsonNode payload = objectMapper.readTree(text);

            List<GeneratedQuestion> domande = new ArrayList<>();
            for (JsonNode nodo : payload.path("domande")) {
                domande.add(new GeneratedQuestion(
                        nodo.path("testo").asText(null),
                        nodo.path("risposta").asText(null),
                        nodo.path("entita_canonica").asText(null),
                        nodo.path("sotto_argomento").asText(null),
                        nodo.path("difficolta").asInt()));
            }

            JsonNode usage = root.path("usage");
            Integer tokenInput = usage.hasNonNull("prompt_tokens")
                    ? usage.get("prompt_tokens").asInt() : null;
            Integer tokenOutput = usage.hasNonNull("completion_tokens")
                    ? usage.get("completion_tokens").asInt() : null;

            return new GenerationOutcome(domande, nome(), tokenInput, tokenOutput);
        } catch (Exception e) {
            log.warn("Risposta Groq non conforme (finish_reason={}, {} caratteri): {}",
                    finishReason, text.length(),
                    text.isEmpty() ? "(vuoto)" : text.substring(0, Math.min(300, text.length())), e);
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "Risposta di Groq non interpretabile (finish_reason=" + finishReason + ")");
        }
    }
}
