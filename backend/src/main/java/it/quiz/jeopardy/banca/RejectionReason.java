package it.quiz.jeopardy.banca;

/**
 * Why a candidate question was rejected by the dedup cascade.
 */
public enum RejectionReason {
    /** Canonical entity already present for the topic (in DB or earlier in the batch). */
    DUPLICATO_ENTITA,
    /** Same normalized text already present for the topic (in DB or earlier in the batch). */
    DUPLICATO_TESTO,
    /** Trigram similarity above threshold against an existing question of the topic. */
    TESTO_SIMILE
}
