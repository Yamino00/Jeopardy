package it.quiz.jeopardy.banca;

import java.util.List;

/**
 * Outcome of the dedup cascade for a batch of candidates.
 */
public record DeduplicationResult(
        List<AcceptedCandidate> accettate,
        List<RejectedCandidate> scartate) {

    /**
     * An accepted candidate, enriched with the canonical entity and text hash
     * computed in Java, ready to be persisted.
     */
    public record AcceptedCandidate(
            CandidateQuestion candidate,
            String entitaCanonica,
            byte[] hashTesto) {
    }

    public record RejectedCandidate(
            CandidateQuestion candidate,
            RejectionReason motivo) {
    }
}
