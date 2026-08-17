package it.quiz.jeopardy.comune;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.context.annotation.RequestScope;

import java.util.UUID;

@Configuration
public class ClientContextConfiguration {

    public static final String REQUEST_ATTRIBUTE = "clientId";

    @Bean
    @RequestScope
    public ClientContext clientContext(HttpServletRequest request) {
        UUID clientId = (UUID) request.getAttribute(REQUEST_ATTRIBUTE);
        if (clientId == null) {
            throw new InvalidClientIdException("Missing X-Client-Id header");
        }
        return new ClientContext(clientId);
    }
}
