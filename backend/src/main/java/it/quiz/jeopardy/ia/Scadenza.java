package it.quiz.jeopardy.ia;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;

/**
 * Il momento entro cui una generazione deve avere finito, qualunque cosa sia
 * successa nel frattempo.
 *
 * <p>Serve perche' la creazione di un tabellone e' sincrona e composta da molte
 * chiamate in fila: una per categoria, ciascuna con fino a due giri su due
 * provider e un'attesa fra i giri. Senza un limite complessivo la somma non ha
 * un tetto, e chi taglia la connessione e' il proxy davanti al servizio, che
 * non ha niente di utile da dire all'utente. Con un limite, e' il servizio a
 * rispondere per primo e a spiegare cos'e' successo.
 *
 * <p>La catena dei margini e', dal piu' stretto al piu' largo: budget di
 * creazione (150s) &lt; {@code receiveTimeout} del client Dio (180s) &lt;
 * timeout dell'ingress di Azure Container Apps (240s).
 */
public record Scadenza(Instant limite) {

    /** Tetto convenzionale per {@link #illimitata()}: finito, per non far straripare i conti. */
    private static final Duration MOLTO_TEMPO = Duration.ofDays(365);

    /** Scadenza fra {@code durata} a partire da adesso. */
    public static Scadenza fra(Duration durata) {
        return new Scadenza(Instant.now().plus(durata));
    }

    /**
     * Nessun limite pratico. Esiste per i percorsi che un budget non ce l'hanno
     * davvero: e' esplicito di proposito, cosi' un {@code null} non passa
     * inosservato.
     */
    public static Scadenza illimitata() {
        return new Scadenza(Instant.now().plus(MOLTO_TEMPO));
    }

    /** Quanto tempo resta; mai negativo. */
    public Duration residuo() {
        Duration rimasto = Duration.between(Instant.now(), limite);
        return rimasto.isNegative() ? Duration.ZERO : rimasto;
    }

    public boolean scaduta() {
        return residuo().isZero();
    }

    /**
     * Il tempo concesso a una singola chiamata: il minimo fra il timeout
     * configurato e quel che resta del budget. Senza questo, l'ultima chiamata
     * di un tabellone quasi scaduto aspetterebbe comunque il timeout pieno e
     * sforerebbe il budget proprio sul finale.
     */
    public Duration cap(Duration timeout) {
        Duration rimasto = residuo();
        return rimasto.compareTo(timeout) < 0 ? rimasto : timeout;
    }

    /**
     * Ferma la generazione se il tempo e' finito. 504 e non 500: la richiesta
     * era valida, e' il tempo a non essere bastato, e il client lo racconta
     * diversamente.
     */
    public void verifica(String cosa) {
        if (scaduta()) {
            throw new ResponseStatusException(HttpStatus.GATEWAY_TIMEOUT,
                    "Tempo esaurito durante " + cosa
                            + ": riprovare con meno categorie o meno righe");
        }
    }
}
