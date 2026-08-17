package it.quiz.jeopardy.comune;

import java.util.UUID;

/**
 * Request-scoped container for the client identity extracted from X-Client-Id header.
 */
public class ClientContext {

    private final UUID clientId;

    public ClientContext(UUID clientId) {
        this.clientId = clientId;
    }

    public UUID getClientId() {
        return clientId;
    }
}
