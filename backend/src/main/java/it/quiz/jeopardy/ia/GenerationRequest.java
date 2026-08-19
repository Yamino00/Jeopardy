package it.quiz.jeopardy.ia;

import java.util.List;

/**
 * Request for the generator: one topic, and how many questions are needed for
 * each difficulty.
 *
 * <p>Chiedere piu' difficolta' in una sola richiesta non e' un dettaglio: i
 * free tier limitano i token al minuto (Groq: 8000), e una chiamata per fascia
 * di difficolta' per categoria esauriva il budget a meta' del primo tabellone.
 */
public record GenerationRequest(
        String argomento,
        String sottoArgomento,
        List<QuotaDifficolta> richieste,
        List<String> blocklist) {

    /** Quante domande servono per una certa difficolta'. */
    public record QuotaDifficolta(short difficolta, int quantita) {
    }

    /** Richiesta per una sola difficolta', usata dall'endpoint a grana fine. */
    public static GenerationRequest singola(String argomento, String sottoArgomento,
                                            short difficolta, int numero,
                                            List<String> blocklist) {
        return new GenerationRequest(argomento, sottoArgomento,
                List.of(new QuotaDifficolta(difficolta, numero)), blocklist);
    }

    /** Totale di domande richieste su tutte le difficolta'. */
    public int numero() {
        return richieste.stream().mapToInt(QuotaDifficolta::quantita).sum();
    }
}
