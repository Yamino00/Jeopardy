package it.quiz.jeopardy.comune;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Pure, deterministic normalization used to derive {@code entita_canonica}
 * and {@code hash_testo}. This is the single source of truth: values coming
 * from the LLM are only compared against this, never trusted.
 */
public final class Normalizer {

    private static final Pattern COMBINING_MARKS = Pattern.compile("\\p{M}+");
    private static final Pattern PARENTHETICAL = Pattern.compile("\\([^)]*\\)");
    /**
     * Leading Italian articles: elided form (l') or full form followed by a space.
     */
    private static final Pattern LEADING_ARTICLE =
            Pattern.compile("^(?:l'|(?:il|lo|la|i|gli|le|un|uno|una)\\s+)");
    private static final Pattern PUNCTUATION = Pattern.compile("[\\p{Punct}’‘“”«»]");
    private static final Pattern WHITESPACE = Pattern.compile("\\s+");

    private Normalizer() {
    }

    /**
     * Transforms an answer into its canonical entity:
     * lowercase -> diacritics removal (NFD) -> parenthetical removal ->
     * leading-article removal -> punctuation removal -> whitespace collapse -> trim.
     */
    public static String toCanonical(String risposta) {
        if (risposta == null) {
            return "";
        }
        String s = risposta.toLowerCase(Locale.ITALIAN);
        s = java.text.Normalizer.normalize(s, java.text.Normalizer.Form.NFD);
        s = COMBINING_MARKS.matcher(s).replaceAll("");
        s = PARENTHETICAL.matcher(s).replaceAll(" ");
        s = s.strip();
        s = LEADING_ARTICLE.matcher(s).replaceFirst("");
        s = PUNCTUATION.matcher(s).replaceAll("");
        s = WHITESPACE.matcher(s).replaceAll(" ");
        return s.strip();
    }

    /**
     * SHA-256 of the normalized question text (lowercase, collapsed whitespace,
     * trimmed) so that trivially reformatted texts collide on purpose.
     */
    public static byte[] hashTesto(String testo) {
        String normalized = WHITESPACE.matcher(testo.toLowerCase(Locale.ITALIAN))
                .replaceAll(" ")
                .strip();
        try {
            return MessageDigest.getInstance("SHA-256")
                    .digest(normalized.getBytes(StandardCharsets.UTF_8));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }
}
