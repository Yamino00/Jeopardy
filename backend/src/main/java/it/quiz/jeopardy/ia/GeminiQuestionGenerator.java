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
 * Real generator backed by the Gemini REST API (free tier). The API key comes
 * from configuration; when it is missing the bean still exists (so the
 * application can start without it) but any call fails fast.
 */
@Component
public class GeminiQuestionGenerator implements QuestionGenerator {

    private static final Logger log = LoggerFactory.getLogger(GeminiQuestionGenerator.class);

    private final ObjectMapper objectMapper;
    private final String endpoint;
    private final String apiKey;
    private final String modello;
    private final double temperature;

    /** Built lazily: the JDK HttpClient opens sockets already at build time. */
    private volatile RestClient restClient;

    public GeminiQuestionGenerator(ObjectMapper objectMapper,
                                   @Value("${app.ia.gemini.endpoint}") String endpoint,
                                   @Value("${app.ia.gemini.api-key:}") String apiKey,
                                   @Value("${app.ia.gemini.modello}") String modello,
                                   @Value("${app.ia.gemini.temperature:0.9}") double temperature) {
        this.objectMapper = objectMapper;
        this.endpoint = endpoint;
        this.apiKey = apiKey;
        this.modello = modello;
        this.temperature = temperature;
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
        if (apiKey == null || apiKey.isBlank()) {
            // 503 esplicito: senza chiave il resto dell'app resta usabile e chi
            // testa capisce subito cosa manca
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
                    "Generazione IA non configurata: impostare GEMINI_API_KEY "
                            + "(app.ia.gemini.api-key)");
        }

        Map<String, Object> body = Map.of(
                "contents", List.of(Map.of(
                        "parts", List.of(Map.of("text", buildPrompt(request))))),
                "generationConfig", Map.of(
                        "responseMimeType", "application/json",
                        "temperature", temperature));

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

    private String buildPrompt(GenerationRequest request) {
        StringBuilder sb = new StringBuilder();
        sb.append("Genera esattamente ").append(request.numero())
                .append(" domande di quiz in italiano, stile Jeopardy, sull'argomento \"")
                .append(request.argomento()).append('"');
        if (request.sottoArgomento() != null && !request.sottoArgomento().isBlank()) {
            sb.append(", sotto-argomento \"").append(request.sottoArgomento()).append('"');
        }
        sb.append(", con difficolta ").append(request.difficolta())
                .append(" su una scala da 1 (facile) a 5 (difficile).\n\n")
                .append("Rispondi SOLO con JSON valido, con questo schema esatto:\n")
                .append("{\"domande\":[{\"testo\":\"...\",\"risposta\":\"...\",")
                .append("\"entita_canonica\":\"...\",\"sotto_argomento\":\"...\",\"difficolta\":")
                .append(request.difficolta()).append("}]}\n\n")
                .append("Regole:\n")
                // Senza questo vincolo il modello risponde "Chi e Annibale?" e la
                // entita_canonica calcolata in Java diventa "chi e annibale",
                // rendendo inefficace la deduplicazione
                .append("- \"risposta\" deve contenere SOLO il nome dell'entita, ")
                .append("mai una frase interrogativa: \"Annibale\", non \"Chi e Annibale?\".\n")
                .append("- \"testo\" e la domanda o l'indizio mostrato ai giocatori.\n")
                .append("- \"entita_canonica\" e la risposta normalizzata: minuscola, senza accenti, ")
                .append("senza articoli iniziali, senza contenuto fra parentesi.\n")
                .append("- Ogni domanda deve avere una risposta diversa dalle altre.\n");
        if (!request.blocklist().isEmpty()) {
            sb.append("- NON generare domande la cui risposta normalizzata sia una di queste ")
                    .append("(gia presenti in banca): ")
                    .append(String.join(", ", request.blocklist()))
                    .append('\n');
        }
        return sb.toString();
    }

    private GenerationOutcome parseResponse(String rawResponse) {
        try {
            JsonNode root = objectMapper.readTree(rawResponse);
            JsonNode payload = objectMapper.readTree(extractText(root));

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

            return new GenerationOutcome(domande, modello, tokenInput, tokenOutput);
        } catch (Exception e) {
            log.warn("Risposta Gemini non conforme allo schema JSON atteso", e);
            return new GenerationOutcome(List.of(), modello, null, null);
        }
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
