package it.quiz.jeopardy.tabellone;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.security.SecureRandom;

/**
 * Generates board codes over an alphabet without ambiguous characters
 * (no 0/O, 1/I/L): the codes are read aloud and typed by players.
 */
@Component
public class CodeGenerator {

    public static final String ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

    private final SecureRandom random = new SecureRandom();
    private final int publicCodeLength;
    private final int editCodeLength;

    public CodeGenerator(
            @Value("${app.tabellone.codice-pubblico-lunghezza:6}") int publicCodeLength,
            @Value("${app.tabellone.codice-modifica-lunghezza:12}") int editCodeLength) {
        this.publicCodeLength = publicCodeLength;
        this.editCodeLength = editCodeLength;
    }

    public String publicCode() {
        return randomCode(publicCodeLength);
    }

    public String editCode() {
        return randomCode(editCodeLength);
    }

    private String randomCode(int length) {
        StringBuilder sb = new StringBuilder(length);
        for (int i = 0; i < length; i++) {
            sb.append(ALPHABET.charAt(random.nextInt(ALPHABET.length())));
        }
        return sb.toString();
    }
}
