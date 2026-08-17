package it.quiz.jeopardy.ia;

import it.quiz.jeopardy.banca.DomandaDto;

import java.util.List;

/**
 * Outcome of a generation request: the questions to use, plus how they were
 * obtained (reused from the bank vs freshly generated) for UI feedback.
 */
public record GenerationResultDto(
        List<DomandaDto> domande,
        int riusate,
        int nuoveGenerate,
        int scartate,
        boolean chiamataLlm) {
}
