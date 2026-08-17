package it.quiz.jeopardy.tabellone;

import org.springframework.stereotype.Component;

import java.security.SecureRandom;

/**
 * Generates board codes over an alphabet without ambiguous characters
 * (no 0/O, 1/I/L): the codes are read aloud and typed by players.
 */
@Component
public class CodeGenerator {

    public static final String ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    public static final int PUBLIC_CODE_LENGTH = 6;
    public static final int EDIT_CODE_LENGTH = 12;

    private final SecureRandom random = new SecureRandom();

    public String publicCode() {
        return randomCode(PUBLIC_CODE_LENGTH);
    }

    public String editCode() {
        return randomCode(EDIT_CODE_LENGTH);
    }

    private String randomCode(int length) {
        StringBuilder sb = new StringBuilder(length);
        for (int i = 0; i < length; i++) {
            sb.append(ALPHABET.charAt(random.nextInt(ALPHABET.length())));
        }
        return sb.toString();
    }
}
