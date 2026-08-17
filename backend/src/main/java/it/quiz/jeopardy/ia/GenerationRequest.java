package it.quiz.jeopardy.ia;

import java.util.List;

/**
 * Request for the generator: always a single cell
 * (argomento, sotto_argomento, difficolta), never a generic topic prompt.
 * The blocklist contains the canonical entities already present for the topic.
 */
public record GenerationRequest(
        String argomento,
        String sottoArgomento,
        short difficolta,
        int numero,
        List<String> blocklist) {
}
