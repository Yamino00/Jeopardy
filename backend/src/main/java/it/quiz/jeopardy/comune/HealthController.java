package it.quiz.jeopardy.comune;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.sql.Connection;
import java.util.Map;

/**
 * Health check endpoint verifying database connectivity.
 */
@RestController
public class HealthController {

    private final DataSource dataSource;

    public HealthController(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @GetMapping("/api/salute")
    public ResponseEntity<Map<String, String>> health() {
        try (Connection conn = dataSource.getConnection()) {
            conn.createStatement().execute("SELECT 1");
            return ResponseEntity.ok(Map.of(
                    "stato", "ok",
                    "database", "connesso"
            ));
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of(
                    "stato", "errore",
                    "database", e.getMessage()
            ));
        }
    }
}
