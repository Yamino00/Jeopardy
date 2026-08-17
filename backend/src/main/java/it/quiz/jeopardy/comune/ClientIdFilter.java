package it.quiz.jeopardy.comune;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Extracts UUID from X-Client-Id header and stores it as a request attribute.
 * Public paths (health check, etc.) are excluded from the requirement.
 * Errors are written directly as Problem Detail: exceptions thrown from a
 * filter would bypass the @RestControllerAdvice.
 */
@Component
public class ClientIdFilter extends OncePerRequestFilter {

    private static final String HEADER_NAME = "X-Client-Id";

    private final ObjectMapper objectMapper;

    /** Paths that do not require X-Client-Id, configurable via app.percorsi-pubblici. */
    private final Set<String> publicPaths;

    public ClientIdFilter(ObjectMapper objectMapper,
                          @Value("${app.percorsi-pubblici:/api/salute}") List<String> publicPaths) {
        this.objectMapper = objectMapper;
        this.publicPaths = Set.copyOf(publicPaths);
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {

        String path = request.getRequestURI();

        if (publicPaths.contains(path)) {
            filterChain.doFilter(request, response);
            return;
        }

        String rawClientId = request.getHeader(HEADER_NAME);
        if (rawClientId == null || rawClientId.isBlank()) {
            writeProblem(response, "Missing X-Client-Id header");
            return;
        }
        try {
            UUID clientId = UUID.fromString(rawClientId);
            request.setAttribute(ClientContextConfiguration.REQUEST_ATTRIBUTE, clientId);
        } catch (IllegalArgumentException ex) {
            writeProblem(response, "Invalid X-Client-Id header");
            return;
        }

        filterChain.doFilter(request, response);
    }

    private void writeProblem(HttpServletResponse response, String detail) throws IOException {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, detail);
        problem.setTitle("Invalid Request Header");
        response.setStatus(HttpStatus.BAD_REQUEST.value());
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), problem);
    }
}
