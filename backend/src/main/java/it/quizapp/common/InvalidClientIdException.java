package it.quizapp.common;

public class InvalidClientIdException extends RuntimeException {

    public InvalidClientIdException(String message) {
        super(message);
    }
}
