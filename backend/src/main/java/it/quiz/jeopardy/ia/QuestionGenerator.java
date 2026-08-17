package it.quiz.jeopardy.ia;

/**
 * Abstraction over the LLM. The single real implementation talks to Gemini
 * via REST; tests use a fake. No test may ever perform a real network call.
 */
public interface QuestionGenerator {

    GenerationOutcome generate(GenerationRequest request);
}
