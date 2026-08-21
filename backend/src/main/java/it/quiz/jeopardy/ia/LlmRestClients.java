package it.quiz.jeopardy.ia;

import org.springframework.boot.web.client.ClientHttpRequestFactories;
import org.springframework.boot.web.client.ClientHttpRequestFactorySettings;
import org.springframework.web.client.RestClient;

import java.time.Duration;

/**
 * Costruisce i client HTTP verso i provider LLM, con i timeout addosso.
 *
 * <p>Esiste per una ragione sola: {@code RestClient.builder().build()} usa il
 * client HTTP del JDK, che <b>non ha un tetto di lettura</b>. Una chiamata a un
 * provider che non risponde piu' non finisce mai, e siccome la creazione di un
 * tabellone le fa in fila, una sola chiamata appesa manda oltre il tempo
 * massimo dell'intera richiesta HTTP. Era il difetto peggiore del percorso di
 * generazione.
 */
final class LlmRestClients {

    private LlmRestClients() {
    }

    /**
     * Il client va costruito pigramente dal chiamante: la factory apre gia' le
     * risorse del client HTTP, e farlo all'avvio del contesto Spring rallenta
     * un avvio che su Azure paghiamo a ogni risveglio da zero repliche.
     */
    static RestClient conTimeout(String baseUrl, Duration connessione, Duration risposta) {
        ClientHttpRequestFactorySettings impostazioni = ClientHttpRequestFactorySettings.DEFAULTS
                .withConnectTimeout(connessione)
                .withReadTimeout(risposta);
        return RestClient.builder()
                .baseUrl(baseUrl)
                .requestFactory(ClientHttpRequestFactories.get(impostazioni))
                .build();
    }
}
