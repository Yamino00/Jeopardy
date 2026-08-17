package it.quiz.jeopardy.banca;

/**
 * A candidate question, typically produced by the LLM, before deduplication.
 * The canonical entity and text hash are NOT part of the candidate: they are
 * always recomputed by the {@link DeduplicationService}.
 */
public record CandidateQuestion(
        String testo,
        String risposta,
        String sottoArgomento,
        short difficolta) {
}
