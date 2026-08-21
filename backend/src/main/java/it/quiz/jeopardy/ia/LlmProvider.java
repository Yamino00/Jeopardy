package it.quiz.jeopardy.ia;

import java.time.Duration;

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

    /**
     * Quanto al massimo questo provider puo' far aspettare una singola
     * chiamata. Il router lo chiede prima di tentare: se nel budget non ci sta
     * un'altra chiamata intera, e' meglio fermarsi subito che partire sapendo
     * gia' di poter sforare.
     */
    Duration timeoutRisposta();

    GenerationOutcome generate(GenerationRequest request);
}
