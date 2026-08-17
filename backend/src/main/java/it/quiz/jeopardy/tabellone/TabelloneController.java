package it.quiz.jeopardy.tabellone;

import it.quiz.jeopardy.comune.ClientContext;
import it.quiz.jeopardy.tabellone.TabelloneDtos.CreateTabelloneRequest;
import it.quiz.jeopardy.tabellone.TabelloneDtos.TabelloneDto;
import it.quiz.jeopardy.tabellone.TabelloneDtos.TabelloneSintesiDto;
import it.quiz.jeopardy.tabellone.TabelloneDtos.UpdateTabelloneRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/tabelloni")
public class TabelloneController {

    public static final String EDIT_CODE_HEADER = "X-Codice-Modifica";

    private final TabelloneService tabelloneService;
    private final ClientContext clientContext;

    public TabelloneController(TabelloneService tabelloneService,
                               ClientContext clientContext) {
        this.tabelloneService = tabelloneService;
        this.clientContext = clientContext;
    }

    /** Creation is the only response carrying the edit code. */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public TabelloneDto create(@Valid @RequestBody CreateTabelloneRequest request) {
        return tabelloneService.create(clientContext.getClientId(), request);
    }

    @GetMapping("/{codicePubblico}")
    public TabelloneDto get(@PathVariable String codicePubblico) {
        return tabelloneService.get(codicePubblico);
    }

    @GetMapping
    public List<TabelloneSintesiDto> listMine() {
        return tabelloneService.listByClient(clientContext.getClientId());
    }

    @PutMapping("/{codicePubblico}")
    public TabelloneDto update(@PathVariable String codicePubblico,
                               @RequestHeader(name = EDIT_CODE_HEADER, required = false)
                               String codiceModifica,
                               @Valid @RequestBody UpdateTabelloneRequest request) {
        return tabelloneService.update(codicePubblico, codiceModifica, request);
    }

    @PostMapping("/{codicePubblico}/celle/{cellaId}/rigenera")
    public TabelloneDtos.CellaDto rigenera(@PathVariable String codicePubblico,
                                           @RequestHeader(name = EDIT_CODE_HEADER, required = false)
                                           String codiceModifica,
                                           @PathVariable Long cellaId) {
        return tabelloneService.rigenera(codicePubblico, codiceModifica, cellaId);
    }
}
