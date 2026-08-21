package it.quiz.jeopardy.ia;

import it.quiz.jeopardy.comune.ClientContext;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;

@RestController
@RequestMapping("/api/generazioni")
public class GenerazioneController {

    private final GenerationService generationService;
    private final ClientContext clientContext;
    private final Duration budget;

    public GenerazioneController(GenerationService generationService,
                                 ClientContext clientContext,
                                 @Value("${app.ia.budget-richiesta-secondi:60}") int budgetSecondi) {
        this.generationService = generationService;
        this.clientContext = clientContext;
        this.budget = Duration.ofSeconds(budgetSecondi);
    }

    @PostMapping
    public GenerationResultDto generate(@Valid @RequestBody GenerationRequestDto request) {
        return generationService.generate(
                clientContext.getClientId(),
                request.argomentoId(),
                request.sottoArgomento(),
                request.difficolta(),
                request.numero(),
                Scadenza.fra(budget));
    }
}
