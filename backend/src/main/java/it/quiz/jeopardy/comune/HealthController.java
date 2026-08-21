package it.quiz.jeopardy.comune;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.sql.Connection;
import java.util.Map;

/**
 * Sonde di salute, separate perche' rispondono a due domande diverse.
 *
 * <p><b>Liveness</b> ({@code /api/salute/vivo}) chiede solo se il processo e'
 * vivo, e non tocca il database di proposito: e' la sonda che, quando fallisce,
 * fa <b>riavviare</b> il container. Il database e' su un servizio che si
 * sospende da solo dopo qualche minuto di inattivita', quindi legarci il
 * riavvio significherebbe riavviare l'applicazione ogni volta che nessuno
 * gioca — curando un problema che non c'e' col rimedio piu' costoso.
 *
 * <p><b>Readiness</b> ({@code /api/salute/pronto}) chiede se ha senso mandarci
 * traffico adesso, e quindi il database lo verifica: se non risponde, nessuna
 * richiesta utile puo' andare a buon fine, ma il processo non va riavviato.
 *
 * <p>{@code /api/salute} resta come sinonimo di readiness: e' l'indirizzo che
 * il client e gli script gia' conoscono.
 */
@RestController
public class HealthController {

    private final DataSource dataSource;

    public HealthController(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    /** Liveness: nessuna dipendenza esterna, altrimenti non e' una liveness. */
    @GetMapping("/api/salute/vivo")
    public Map<String, String> vivo() {
        return Map.of("stato", "ok");
    }

    @GetMapping({"/api/salute", "/api/salute/pronto"})
    public ResponseEntity<Map<String, String>> health() {
        try (Connection conn = dataSource.getConnection()) {
            conn.createStatement().execute("SELECT 1");
            return ResponseEntity.ok(Map.of(
                    "stato", "ok",
                    "database", "connesso"
            ));
        } catch (Exception e) {
            return ResponseEntity.status(503).body(Map.of(
                    "stato", "errore",
                    "database", e.getMessage()
            ));
        }
    }
}
