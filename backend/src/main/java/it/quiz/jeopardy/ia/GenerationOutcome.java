package it.quiz.jeopardy.ia;

import java.util.List;

/**
 * What a {@link QuestionGenerator} call produced, with token usage for
 * cost tracking.
 */
public record GenerationOutcome(
        List<GeneratedQuestion> domande,
        String modello,
        Integer tokenInput,
        Integer tokenOutput) {
}
