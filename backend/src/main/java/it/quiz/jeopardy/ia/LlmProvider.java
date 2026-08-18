package it.quiz.jeopardy.ia;

/**
 * A single LLM backend. Deliberately NOT a {@link QuestionGenerator}: the
 * providers are collected by {@link RoutingQuestionGenerator}, which is the
 * only QuestionGenerator bean, so tests can still swap in a fake generator
 * without colliding with the providers.
 */
public interface LlmProvider {

    /** Short name used in logs and in the {@code generazione} audit row. */
    String nome();

    /** False when the provider has no API key: it is skipped by the router. */
    boolean configurato();

    GenerationOutcome generate(GenerationRequest request);
}
