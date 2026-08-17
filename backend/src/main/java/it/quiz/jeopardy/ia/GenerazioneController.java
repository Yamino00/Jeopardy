package it.quiz.jeopardy.ia;

import it.quiz.jeopardy.comune.ClientContext;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/generazioni")
public class GenerazioneController {

    private final GenerationService generationService;
    private final ClientContext clientContext;

    public GenerazioneController(GenerationService generationService,
                                 ClientContext clientContext) {
        this.generationService = generationService;
        this.clientContext = clientContext;
    }

    @PostMapping
    public GenerationResultDto generate(@Valid @RequestBody GenerationRequestDto request) {
        return generationService.generate(
                clientContext.getClientId(),
                request.argomentoId(),
                request.sottoArgomento(),
                request.difficolta(),
                request.numero());
    }
}
