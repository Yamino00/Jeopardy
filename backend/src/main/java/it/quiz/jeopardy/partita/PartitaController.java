package it.quiz.jeopardy.partita;

import it.quiz.jeopardy.partita.PartitaDtos.CreatePartitaRequest;
import it.quiz.jeopardy.partita.PartitaDtos.EventoDto;
import it.quiz.jeopardy.partita.PartitaDtos.PartitaDto;
import it.quiz.jeopardy.partita.PartitaDtos.PlayCellaRequest;
import it.quiz.jeopardy.partita.PartitaDtos.SquadraCreate;
import it.quiz.jeopardy.partita.PartitaDtos.SquadraDto;
import it.quiz.jeopardy.partita.PartitaDtos.SquadraUpdate;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class PartitaController {

    private final PartitaService partitaService;

    public PartitaController(PartitaService partitaService) {
        this.partitaService = partitaService;
    }

    @PostMapping("/api/tabelloni/{codicePubblico}/partite")
    @ResponseStatus(HttpStatus.CREATED)
    public PartitaDto start(@PathVariable String codicePubblico,
                            @Valid @RequestBody(required = false) CreatePartitaRequest request) {
        return partitaService.start(codicePubblico,
                request == null ? new CreatePartitaRequest(null) : request);
    }

    @GetMapping("/api/partite/{id}")
    public PartitaDto get(@PathVariable Long id) {
        return partitaService.get(id);
    }

    @PostMapping("/api/partite/{id}/squadre")
    @ResponseStatus(HttpStatus.CREATED)
    public SquadraDto addSquadra(@PathVariable Long id,
                                 @Valid @RequestBody SquadraCreate request) {
        return partitaService.addSquadra(id, request);
    }

    @PatchMapping("/api/partite/{id}/squadre/{squadraId}")
    public SquadraDto updateSquadra(@PathVariable Long id,
                                    @PathVariable Long squadraId,
                                    @Valid @RequestBody SquadraUpdate request) {
        return partitaService.updateSquadra(id, squadraId, request);
    }

    @DeleteMapping("/api/partite/{id}/squadre/{squadraId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeSquadra(@PathVariable Long id, @PathVariable Long squadraId) {
        partitaService.removeSquadra(id, squadraId);
    }

    @PostMapping("/api/partite/{id}/celle/{cellaId}")
    public EventoDto playCella(@PathVariable Long id,
                               @PathVariable Long cellaId,
                               @Valid @RequestBody PlayCellaRequest request) {
        return partitaService.playCella(id, cellaId, request);
    }

    /**
     * Risponde 200 anche quando non c'era niente da annullare: lo dice
     * {@code annullato} nel corpo. Vedi {@link PartitaDtos.AnnullamentoDto}.
     */
    @PostMapping("/api/partite/{id}/annulla")
    public PartitaDtos.AnnullamentoDto annulla(@PathVariable Long id) {
        return partitaService.annulla(id);
    }

    @PostMapping("/api/partite/{id}/concludi")
    public PartitaDto concludi(@PathVariable Long id) {
        return partitaService.concludi(id);
    }
}
