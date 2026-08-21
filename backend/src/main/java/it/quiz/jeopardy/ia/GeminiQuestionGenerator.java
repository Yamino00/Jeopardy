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

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Provider backed by the Gemini REST API (free tier).
 *
 * <p>Thinking is disabled on purpose: the 3.x models otherwise burn ~2000
 * "thought" tokens per call, which makes every cell take ~20s and can eat the
 * output budget until the JSON comes back truncated. With
 * {@code thinkingBudget: 0} the same request answers in ~4s.
 */
@Component
public class GeminiQuestionGenerator implements LlmProvider {

    private static final Logger log = LoggerFactory.getLogger(GeminiQuestionGenerator.class);

    private final ObjectMapper objectMapper;
    private final String endpoint;
    private final String apiKey;
    private final String modello;
    private final double temperature;
    private final int maxOutputTokens;
    private final Duration timeoutConnessione;
    private final Duration timeoutRisposta;

    /** Built lazily: the JDK HttpClient opens sockets already at build time. */
    private volatile RestClient restClient;

    public GeminiQuestionGenerator(ObjectMapper objectMapper,
                                   @Value("${app.ia.gemini.endpoint}") String endpoint,
                                   @Value("${app.ia.gemini.api-key:}") String apiKey,
                                   @Value("${app.ia.gemini.modello}") String modello,
                                   @Value("${app.ia.gemini.temperature:0.9}") double temperature,
                                   @Value("${app.ia.gemini.max-output-tokens:4096}") int maxOutputTokens,
                                   @Value("${app.ia.timeout-connessione-secondi:5}") int timeoutConnessioneSecondi,
                                   @Value("${app.ia.timeout-risposta-secondi:45}") int timeoutRispostaSecondi) {
        this.objectMapper = objectMapper;
        this.endpoint = endpoint;
        this.apiKey = apiKey;
        this.modello = modello;
        this.temperature = temperature;
        this.maxOutputTokens = maxOutputTokens;
        this.timeoutConnessione = Duration.ofSeconds(timeoutConnessioneSecondi);
        this.timeoutRisposta = Duration.ofSeconds(timeoutRispostaSecondi);
    }

    @Override
    public String nome() {
        return "gemini/" + modello;
    }

    @Override
    public boolean configurato() {
        return apiKey != null && !apiKey.isBlank();
    }

    @Override
    public Duration timeoutRisposta() {
        return timeoutRisposta;
    }

    private RestClient restClient() {
        RestClient client = restClient;
        if (client == null) {
            synchronized (this) {
                if (restClient == null) {
                    restClient = LlmRestClients.conTimeout(
                            endpoint, timeoutConnessione, timeoutRisposta);
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
                    "Gemini non configurato: impostare GEMINI_API_KEY");
        }
        request.scadenza().verifica("la chiamata a " + nome());

        Map<String, Object> body = Map.of(
                "contents", List.of(Map.of(
                        "parts", List.of(Map.of("text", PromptBuilder.build(request))))),
                "generationConfig", Map.of(
                        "responseMimeType", "application/json",
                        "temperature", temperature,
                        "maxOutputTokens", maxOutputTokens,
                        "thinkingConfig", Map.of("thinkingBudget", 0)));

        String rawResponse;
        try {
            rawResponse = restClient().post()
                    .uri(uri -> uri.path("/models/{modello}:generateContent").build(modello))
                    // Header anziche' ?key=: la chiave non finisce in URL e log
                    .header("x-goog-api-key", apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(String.class);
        } catch (HttpStatusCodeException ex) {
            throw translateUpstreamError(ex);
        } catch (RestClientException ex) {
            log.warn("Chiamata a Gemini fallita", ex);
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "Servizio di generazione non raggiungibile", ex);
        }

        return parseResponse(rawResponse);
    }

    /**
     * Upstream failures must not surface as a generic 500: the caller needs to
     * tell apart "model gone / key wrong" (fix the config) from "try again".
     */
    private ResponseStatusException translateUpstreamError(HttpStatusCodeException ex) {
        int status = ex.getStatusCode().value();
        log.warn("Gemini ha risposto {} per il modello {}: {}",
                status, modello, ex.getResponseBodyAsString());

        return switch (status) {
            case 400, 403 -> new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Chiave Gemini non valida o senza accesso al modello " + modello);
            case 404 -> new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Il modello '" + modello + "' non esiste o non e' piu disponibile: "
                            + "aggiornare app.ia.gemini.modello");
            case 429 -> new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
                    "Quota del free tier Gemini esaurita: riprovare piu tardi");
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
            finishReason = root.path("candidates").path(0).path("finishReason").asText("?");
            text = extractText(root);
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

            JsonNode usage = root.path("usageMetadata");
            Integer tokenInput = usage.hasNonNull("promptTokenCount")
                    ? usage.get("promptTokenCount").asInt() : null;
            Integer tokenOutput = usage.hasNonNull("candidatesTokenCount")
                    ? usage.get("candidatesTokenCount").asInt() : null;

            return new GenerationOutcome(domande, nome(), tokenInput, tokenOutput);
        } catch (Exception e) {
            // Il motivo piu' comune e' MAX_TOKENS con JSON troncato: senza
            // finishReason e un estratto del testo l'errore e' indiagnosticabile
            log.warn("Risposta Gemini non conforme (finishReason={}, {} caratteri): {}",
                    finishReason, text.length(), estratto(text), e);
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "Risposta di Gemini non interpretabile (finishReason=" + finishReason + ")");
        }
    }

    private static String estratto(String text) {
        if (text == null || text.isEmpty()) {
            return "(vuoto)";
        }
        return text.substring(0, Math.min(300, text.length()));
    }

    /**
     * The answer text is not always the first part: reasoning models emit
     * thought parts alongside it, so skip those and take the first real text.
     */
    private static String extractText(JsonNode root) {
        JsonNode parts = root.path("candidates").path(0).path("content").path("parts");
        for (JsonNode part : parts) {
            if (part.path("thought").asBoolean(false)) {
                continue;
            }
            String text = part.path("text").asText("");
            if (!text.isBlank()) {
                return text;
            }
        }
        return "";
    }
}
