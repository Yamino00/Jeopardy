package it.quiz.jeopardy.comune;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.lang.NonNull;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.util.List;

/**
 * CORS for the Flutter web client, which runs on a different origin.
 * Origins are configurable; the default is permissive because the API is
 * anonymous by design (no cookies, no credentials).
 *
 * <p>Lista vuota significa <b>nessuna regola CORS</b>, non "tutti": e' il
 * valore giusto in produzione, dove il client e' un'app Android e i browser
 * non c'entrano. Registrare comunque un mapping con una lista vuota farebbe
 * fallire l'avvio, il che nasconderebbe la scelta dietro un guasto.
 */
@Configuration
public class CorsConfiguration implements WebMvcConfigurer {

    private final List<String> allowedOrigins;

    public CorsConfiguration(
            @Value("${app.cors.allowed-origins:*}") List<String> allowedOrigins) {
        this.allowedOrigins = allowedOrigins.stream()
                .map(String::strip)
                .filter(origine -> !origine.isEmpty())
                .toList();
    }

    @Override
    public void addCorsMappings(@NonNull CorsRegistry registry) {
        if (allowedOrigins.isEmpty()) {
            return;
        }
        registry.addMapping("/api/**")
                .allowedOriginPatterns(allowedOrigins.toArray(String[]::new))
                .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE")
                .allowedHeaders("*");
    }
}
