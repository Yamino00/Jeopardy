package it.quiz.jeopardy.banca;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;

import it.quiz.jeopardy.TestcontainersConfiguration;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Integration test verifying that Flyway migrations create the expected schema
 * constraints on a real PostgreSQL instance via Testcontainers.
 */
@SpringBootTest
@Import(TestcontainersConfiguration.class)
class SchemaConstraintIntegrationTest {

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    @DisplayName("Vincolo unico (argomento_id, entita_canonica) rifiuta doppione")
    void uniqueConstraintOnEntitaCanonica_rejectsDuplicate() {
        // Setup: create an argomento
        jdbc.update("""
                INSERT INTO argomento (nome, slug, lingua)
                VALUES ('Storia', 'storia', 'it')
                """);

        Long argomentoId = jdbc.queryForObject(
                "SELECT id FROM argomento WHERE slug = 'storia'", Long.class);

        byte[] hash1 = sha256("chi fu il primo imperatore romano");
        byte[] hash2 = sha256("domanda diversa sul primo imperatore romano");

        // Insert first domanda
        jdbc.update("""
                INSERT INTO domanda (argomento_id, testo, risposta, entita_canonica, 
                                     hash_testo, difficolta)
                VALUES (?, 'Chi fu il primo imperatore romano?', 'Augusto', 
                        'augusto', ?, 1)
                """, argomentoId, hash1);

        // Attempt to insert a duplicate with same entita_canonica should fail
        assertThatThrownBy(() -> jdbc.update("""
                INSERT INTO domanda (argomento_id, testo, risposta, entita_canonica, 
                                     hash_testo, difficolta)
                VALUES (?, 'Quale imperatore fondò il principato?', 'Augusto', 
                        'augusto', ?, 2)
                """, argomentoId, hash2))
                .hasMessageContaining("ux_domanda_entita");
    }

    @Test
    @DisplayName("Stessa entita_canonica su argomento diverso è ammessa")
    void sameEntitaCanonica_differentArgomento_isAllowed() {
        jdbc.update("""
                INSERT INTO argomento (nome, slug, lingua)
                VALUES ('Letteratura', 'letteratura', 'it')
                """);
        jdbc.update("""
                INSERT INTO argomento (nome, slug, lingua)
                VALUES ('Cinema', 'cinema', 'it')
                """);

        Long letteraturaId = jdbc.queryForObject(
                "SELECT id FROM argomento WHERE slug = 'letteratura'", Long.class);
        Long cinemaId = jdbc.queryForObject(
                "SELECT id FROM argomento WHERE slug = 'cinema'", Long.class);

        byte[] hash1 = sha256("chi scrisse il nome della rosa letteratura");
        byte[] hash2 = sha256("chi diresse il nome della rosa cinema");

        // Insert on first argomento
        jdbc.update("""
                INSERT INTO domanda (argomento_id, testo, risposta, entita_canonica,
                                     hash_testo, difficolta)
                VALUES (?, 'Chi scrisse Il nome della rosa?', 'Umberto Eco',
                        'umberto eco', ?, 2)
                """, letteraturaId, hash1);

        // Same entita_canonica on different argomento should succeed
        jdbc.update("""
                INSERT INTO domanda (argomento_id, testo, risposta, entita_canonica,
                                     hash_testo, difficolta)
                VALUES (?, 'Chi diresse il film Il nome della rosa?', 'Umberto Eco',
                        'umberto eco', ?, 3)
                """, cinemaId, hash2);

        int count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM domanda WHERE entita_canonica = 'umberto eco'",
                Integer.class);
        assertThat(count).isEqualTo(2);
    }

    @Test
    @DisplayName("Hash testo duplicato sullo stesso argomento è rifiutato")
    void duplicateHashTesto_sameArgomento_isRejected() {
        jdbc.update("""
                INSERT INTO argomento (nome, slug, lingua)
                VALUES ('Scienza', 'scienza', 'it')
                """);

        Long argomentoId = jdbc.queryForObject(
                "SELECT id FROM argomento WHERE slug = 'scienza'", Long.class);

        byte[] sameHash = sha256("stessa domanda sulla scienza");

        jdbc.update("""
                INSERT INTO domanda (argomento_id, testo, risposta, entita_canonica,
                                     hash_testo, difficolta)
                VALUES (?, 'Qual è la velocità della luce?', '300000 km/s',
                        '300000 kms', ?, 3)
                """, argomentoId, sameHash);

        assertThatThrownBy(() -> jdbc.update("""
                INSERT INTO domanda (argomento_id, testo, risposta, entita_canonica,
                                     hash_testo, difficolta)
                VALUES (?, 'Qual è la velocità della luce?', 'circa 300.000 km/s',
                        'circa 300000 kms', ?, 2)
                """, argomentoId, sameHash))
                .hasMessageContaining("ux_domanda_hash");
    }

    @Test
    @DisplayName("Domande ritirate non occupano slot entita_canonica")
    void retiredQuestions_doNotBlockNewOnes() {
        jdbc.update("""
                INSERT INTO argomento (nome, slug, lingua)
                VALUES ('Musica', 'musica', 'it')
                """);

        Long argomentoId = jdbc.queryForObject(
                "SELECT id FROM argomento WHERE slug = 'musica'", Long.class);

        byte[] hash1 = sha256("domanda musica mozart 1");
        byte[] hash2 = sha256("domanda musica mozart 2");

        // Insert and retire a domanda
        jdbc.update("""
                INSERT INTO domanda (argomento_id, testo, risposta, entita_canonica,
                                     hash_testo, difficolta, stato)
                VALUES (?, 'Chi compose il Requiem?', 'Mozart',
                        'mozart', ?, 2, 'ritirata')
                """, argomentoId, hash1);

        // Same entita_canonica should now be allowed (retired doesn't occupy slot)
        jdbc.update("""
                INSERT INTO domanda (argomento_id, testo, risposta, entita_canonica,
                                     hash_testo, difficolta)
                VALUES (?, 'Chi compose le Nozze di Figaro?', 'Mozart',
                        'mozart', ?, 3)
                """, argomentoId, hash2);

        int activeCount = jdbc.queryForObject("""
                SELECT COUNT(*) FROM domanda 
                WHERE entita_canonica = 'mozart' AND stato = 'attiva'
                """, Integer.class);
        assertThat(activeCount).isEqualTo(1);
    }

    private static byte[] sha256(String text) {
        try {
            return MessageDigest.getInstance("SHA-256")
                    .digest(text.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException(e);
        }
    }
}
