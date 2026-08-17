package it.quiz.jeopardy.ia;

/**
 * Raised when a client exceeds the daily generation quota. Mapped to 429.
 */
public class QuotaExceededException extends RuntimeException {

    public QuotaExceededException(String message) {
        super(message);
    }
}
