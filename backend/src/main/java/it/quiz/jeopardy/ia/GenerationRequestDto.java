package it.quiz.jeopardy.ia;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/**
 * Body of POST /api/generazioni: one cell (argomento, sotto_argomento,
 * difficolta) and how many questions are needed.
 */
public record GenerationRequestDto(
        @NotNull Long argomentoId,
        String sottoArgomento,
        @NotNull @Min(1) @Max(5) Short difficolta,
        @NotNull @Min(1) @Max(10) Integer numero) {
}
