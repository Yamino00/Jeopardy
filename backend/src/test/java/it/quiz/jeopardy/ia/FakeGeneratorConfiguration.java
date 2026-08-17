package it.quiz.jeopardy.ia;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/**
 * Replaces the real Gemini generator with the fake in integration tests.
 */
@TestConfiguration(proxyBeanMethods = false)
public class FakeGeneratorConfiguration {

    @Bean
    @Primary
    FakeQuestionGenerator fakeQuestionGenerator() {
        return new FakeQuestionGenerator();
    }
}
