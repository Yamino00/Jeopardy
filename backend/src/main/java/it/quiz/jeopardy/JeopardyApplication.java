package it.quiz.jeopardy;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class JeopardyApplication {

    public static void main(String[] args) {
        SpringApplication.run(JeopardyApplication.class, args);
    }
}
