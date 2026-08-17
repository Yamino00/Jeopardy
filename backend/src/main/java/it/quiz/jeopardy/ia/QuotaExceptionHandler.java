package it.quiz.jeopardy.ia;

import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Maps quota exhaustion to 429 Too Many Requests (Problem Detail).
 * Lives in the ia package so comune stays independent from the contexts.
 */
@RestControllerAdvice
@Order(0)
public class QuotaExceptionHandler {

    @ExceptionHandler(QuotaExceededException.class)
    public ProblemDetail handleQuotaExceeded(QuotaExceededException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.TOO_MANY_REQUESTS, ex.getMessage());
        problem.setTitle("Quota Exceeded");
        return problem;
    }
}
