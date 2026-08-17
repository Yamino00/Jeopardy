package it.quiz.jeopardy.ia;

/**
 * A single question as returned by the LLM. {@code entitaCanonica} is the
 * model's own claim: it is only compared against the Java-computed value for
 * logging, never trusted or persisted as-is.
 */
public record GeneratedQuestion(
        String testo,
        String risposta,
        String entitaCanonica,
        String sottoArgomento,
        int difficolta) {
}
