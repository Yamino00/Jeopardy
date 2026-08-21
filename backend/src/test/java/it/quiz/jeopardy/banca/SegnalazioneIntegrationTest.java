package it.quiz.jeopardy.banca;

import it.quiz.jeopardy.TestcontainersConfiguration;
import it.quiz.jeopardy.comune.Normalizer;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * La catena della segnalazione: tre dispositivi diversi disattivano una
 * domanda, un dispositivo solo no, e una domanda disattivata smette di essere
 * pescata per i tabelloni nuovi.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class SegnalazioneIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DomandaRepository domandaRepository;

    @Autowired
    private ArgomentoRepository argomentoRepository;

    private Domanda nuovaDomanda(String suffisso) {
        Argomento argomento = new Argomento();
        argomento.setNome("Segnalazioni " + suffisso);
        argomento.setSlug("segnalazioni-" + suffisso.toLowerCase());
        argomento.setLingua("it");
        argomento = argomentoRepository.save(argomento);

        String testo = "Chi ha inventato il codice segreto " + suffisso + "?";
        Domanda domanda = new Domanda();
        domanda.setArgomento(argomento);
        domanda.setTesto(testo);
        domanda.setRisposta("Nessuno " + suffisso);
        domanda.setEntitaCanonica(Normalizer.toCanonical("Nessuno " + suffisso));
        domanda.setHashTesto(Normalizer.hashTesto(testo));
        domanda.setDifficolta((short) 1);
        return domandaRepository.save(domanda);
    }

    private void segnala(Long domandaId, String clientId, int statoAtteso) throws Exception {
        mockMvc.perform(post("/api/domande/{id}/segnalazioni", domandaId)
                        .header("X-Client-Id", clientId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"motivo": "errata", "nota": "la risposta e' sbagliata"}
                                """))
                .andExpect(status().is(statoAtteso));
    }

    @Test
    @DisplayName("La terza segnalazione disattiva la domanda")
    void terzaSegnalazione_disattivaLaDomanda() throws Exception {
        Domanda domanda = nuovaDomanda("Terza" + UUID.randomUUID().toString().substring(0, 8));

        segnala(domanda.getId(), UUID.randomUUID().toString(), 201);
        segnala(domanda.getId(), UUID.randomUUID().toString(), 201);

        // Due non bastano: la domanda e' ancora giocabile
        assertThat(domandaRepository.findById(domanda.getId()).orElseThrow().getStato())
                .isEqualTo(StatoDomanda.ATTIVA);

        // La terza si': e' l'errore di un'unita' che c'era prima (`>` invece di
        // `>=`), che rendeva necessaria la quarta.
        mockMvc.perform(post("/api/domande/{id}/segnalazioni", domanda.getId())
                        .header("X-Client-Id", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"motivo": "ambigua"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.segnalazioni_totali").value(3))
                .andExpect(jsonPath("$.soglia").value(3))
                .andExpect(jsonPath("$.disattivata").value(true))
                .andExpect(jsonPath("$.gia_segnalata").value(false))
                .andExpect(jsonPath("$.stato_domanda").value("segnalata"));

        assertThat(domandaRepository.findById(domanda.getId()).orElseThrow().getStato())
                .isEqualTo(StatoDomanda.SEGNALATA);
    }

    @Test
    @DisplayName("Lo stesso dispositivo non puo' consumare la soglia da solo")
    void stessoClient_contaUnaVoltaSola() throws Exception {
        Domanda domanda = nuovaDomanda("Solo" + UUID.randomUUID().toString().substring(0, 8));
        String clientId = UUID.randomUUID().toString();

        segnala(domanda.getId(), clientId, 201);

        // 200 e non 201: risegnalare non e' un conflitto, e non e' un errore da
        // raccontare all'utente
        for (int i = 0; i < 3; i++) {
            mockMvc.perform(post("/api/domande/{id}/segnalazioni", domanda.getId())
                            .header("X-Client-Id", clientId)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"motivo": "offensiva"}
                                    """))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.gia_segnalata").value(true))
                    .andExpect(jsonPath("$.segnalazioni_totali").value(1))
                    .andExpect(jsonPath("$.disattivata").value(false));
        }

        assertThat(domandaRepository.findById(domanda.getId()).orElseThrow())
                .satisfies(d -> {
                    assertThat(d.getSegnalazioni()).isEqualTo(1);
                    assertThat(d.getStato()).isEqualTo(StatoDomanda.ATTIVA);
                });
    }

    @Test
    @DisplayName("Una domanda disattivata non viene piu' pescata per i tabelloni")
    void domandaDisattivata_nonVienePiuPescata() throws Exception {
        Domanda domanda = nuovaDomanda("Pesca" + UUID.randomUUID().toString().substring(0, 8));
        Long argomentoId = domanda.getArgomento().getId();
        UUID clientLettore = UUID.randomUUID();

        List<Domanda> prima = domandaRepository.findAvailableForClient(
                argomentoId, null, (short) 1, clientLettore, 10);
        assertThat(prima).extracting(Domanda::getId).contains(domanda.getId());

        for (int i = 0; i < 3; i++) {
            segnala(domanda.getId(), UUID.randomUUID().toString(), 201);
        }

        List<Domanda> dopo = domandaRepository.findAvailableForClient(
                argomentoId, null, (short) 1, clientLettore, 10);
        assertThat(dopo).extracting(Domanda::getId).doesNotContain(domanda.getId());
    }

    @Test
    @DisplayName("Segnalare una domanda che non esiste e' 404")
    void domandaInesistente_e404() throws Exception {
        segnala(999_999_999L, UUID.randomUUID().toString(), 404);
    }

    @Test
    @DisplayName("Il motivo e' obbligatorio")
    void motivoMancante_e400() throws Exception {
        Domanda domanda = nuovaDomanda("Motivo" + UUID.randomUUID().toString().substring(0, 8));
        mockMvc.perform(post("/api/domande/{id}/segnalazioni", domanda.getId())
                        .header("X-Client-Id", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }
}
