package it.quiz.jeopardy.banca;

import it.quiz.jeopardy.comune.ClientContext;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SegnalazioneController {

    private final SegnalazioneService segnalazioneService;
    private final ClientContext clientContext;

    public SegnalazioneController(SegnalazioneService segnalazioneService,
                                  ClientContext clientContext) {
        this.segnalazioneService = segnalazioneService;
        this.clientContext = clientContext;
    }

    @PostMapping("/api/domande/{domandaId}/segnalazioni")
    @ResponseStatus(HttpStatus.CREATED)
    public SegnalazioneService.SegnalazioneDto segnala(
            @PathVariable Long domandaId,
            @Valid @RequestBody SegnalazioneRequest request) {
        return segnalazioneService.segnala(
                clientContext.getClientId(), domandaId, request.motivo(), request.nota());
    }

    public record SegnalazioneRequest(
            @NotNull MotivoSegnalazione motivo,
            @Size(max = 500) String nota) {
    }
}
