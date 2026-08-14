package it.quizapp.common;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

@Component
public class ClientIdFilter extends OncePerRequestFilter {

    private static final String HEADER_NAME = "X-Client-Id";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String rawClientId = request.getHeader(HEADER_NAME);
        if (rawClientId == null || rawClientId.isBlank()) {
            throw new InvalidClientIdException("Missing X-Client-Id header");
        }
        try {
            UUID clientId = UUID.fromString(rawClientId);
            request.setAttribute(ClientContextConfiguration.REQUEST_ATTRIBUTE, clientId);
        } catch (IllegalArgumentException ex) {
            throw new InvalidClientIdException("Invalid X-Client-Id header");
        }

        filterChain.doFilter(request, response);
    }
}
