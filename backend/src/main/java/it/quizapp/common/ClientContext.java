package it.quizapp.common;

import java.util.UUID;

public class ClientContext {

    private final UUID clientId;

    public ClientContext(UUID clientId) {
        this.clientId = clientId;
    }

    public UUID getClientId() {
        return clientId;
    }
}
