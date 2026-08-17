package it.quiz.jeopardy.ia;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface QuotaClientRepository extends JpaRepository<QuotaClient, UUID> {
}
