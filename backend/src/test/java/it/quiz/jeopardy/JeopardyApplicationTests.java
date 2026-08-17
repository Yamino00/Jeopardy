package it.quiz.jeopardy;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

@SpringBootTest
@Import(TestcontainersConfiguration.class)
class JeopardyApplicationTests {

    @Test
    void contextLoads() {
        // Verifies that the Spring context starts successfully
        // and all Flyway migrations apply without errors.
    }
}
