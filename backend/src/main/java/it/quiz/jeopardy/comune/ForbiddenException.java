package it.quiz.jeopardy.comune;

/**
 * Raised when the caller lacks the required secret (e.g. wrong edit code).
 * Mapped to 403.
 */
public class ForbiddenException extends RuntimeException {

    public ForbiddenException(String message) {
        super(message);
    }
}
