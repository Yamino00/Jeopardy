package it.quiz.jeopardy.comune;

/**
 * Raised when a requested resource does not exist. Mapped to 404.
 */
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String message) {
        super(message);
    }
}
