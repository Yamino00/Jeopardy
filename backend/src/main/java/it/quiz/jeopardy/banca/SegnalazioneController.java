package it.quiz.jeopardy.banca;

import it.quiz.jeopardy.comune.ClientContext;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
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

    /**
     * Segnala una domanda della banca condivisa.
     *
     * <p>201 quando la segnalazione e' nuova, <b>200 quando questo dispositivo
     * l'aveva gia' segnalata</b>: risegnalare non e' un conflitto, e rispondere
     * 409 costringerebbe il client a raccontare come errore una condizione
     * normale.
     */
    @PostMapping("/api/domande/{domandaId}/segnalazioni")
    public ResponseEntity<SegnalazioneService.SegnalazioneDto> segnala(
            @PathVariable Long domandaId,
            @Valid @RequestBody SegnalazioneRequest request) {
        SegnalazioneService.SegnalazioneDto esito = segnalazioneService.segnala(
                clientContext.getClientId(), domandaId, request.motivo(), request.nota());
        return ResponseEntity
                .status(esito.giaSegnalata() ? HttpStatus.OK : HttpStatus.CREATED)
                .body(esito);
    }

    public record SegnalazioneRequest(
            @NotNull MotivoSegnalazione motivo,
            @Size(max = 500) String nota) {
    }
}
