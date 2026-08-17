package it.quiz.jeopardy.partita;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Enables in-process scheduling (see AGENTS.md: @Scheduled, no workers).
 */
@Configuration
@EnableScheduling
public class SchedulingConfiguration {
}
