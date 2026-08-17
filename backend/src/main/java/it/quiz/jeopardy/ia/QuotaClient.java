package it.quiz.jeopardy.ia;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;
import java.util.UUID;

/**
 * Daily generation counter per anonymous client.
 */
@Entity
@Table(name = "quota_client")
@Getter
@Setter
@NoArgsConstructor
public class QuotaClient {

    @Id
    @Column(name = "client_id")
    private UUID clientId;

    @Column(nullable = false)
    private LocalDate giorno = LocalDate.now();

    @Column(name = "generazioni_oggi", nullable = false)
    private short generazioniOggi;

    @Column(nullable = false)
    private boolean bloccato;

    public QuotaClient(UUID clientId) {
        this.clientId = clientId;
    }
}
