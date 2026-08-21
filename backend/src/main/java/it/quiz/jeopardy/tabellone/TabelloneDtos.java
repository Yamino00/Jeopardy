package it.quiz.jeopardy.tabellone;

import com.fasterxml.jackson.annotation.JsonInclude;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;

/**
 * Request/response models for the tabellone endpoints.
 * The edit code is serialized only when present (creation response).
 */
public final class TabelloneDtos {

    private TabelloneDtos() {
    }

    public record CreateTabelloneRequest(
            @NotBlank String titolo,
            @NotEmpty @Size(min = 1, max = 6) List<@NotBlank String> argomenti,
            @Min(3) @Max(5) Short righe,
            @Min(10) @Max(1000) Integer puntiBase) {
    }

    public record UpdateTabelloneRequest(
            String titolo,
            @Valid List<CategoriaUpdate> categorie,
            @Valid List<CellaUpdate> celle) {

        public record CategoriaUpdate(@NotNull Long id, String nomeDisplay) {
        }

        /** Text edits become cell overrides, never touching the shared question. */
        public record CellaUpdate(@NotNull Long id, String testo, String risposta) {
        }
    }

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record TabelloneDto(
            String codicePubblico,
            String codiceModifica,
            String titolo,
            short righe,
            int puntiBase,
            List<CategoriaDto> categorie) {

        public static TabelloneDto from(Tabellone tabellone, boolean includeEditCode) {
            return new TabelloneDto(
                    tabellone.getCodicePubblico(),
                    includeEditCode ? tabellone.getCodiceModifica() : null,
                    tabellone.getTitolo(),
                    tabellone.getRighe(),
                    tabellone.getPuntiBase(),
                    tabellone.getCategorie().stream().map(CategoriaDto::from).toList());
        }
    }

    public record CategoriaDto(
            Long id,
            String nomeDisplay,
            short posizione,
            List<CellaDto> celle) {

        public static CategoriaDto from(Categoria categoria) {
            return new CategoriaDto(
                    categoria.getId(),
                    categoria.getNomeDisplay(),
                    categoria.getPosizione(),
                    categoria.getCelle().stream().map(CellaDto::from).toList());
        }
    }

    /**
     * @param domandaId l'id nella banca condivisa <b>del testo che si sta
     *                  leggendo</b>. Serve al client per raggiungere
     *                  {@code POST /api/domande/{id}/segnalazioni}: senza,
     *                  l'endpoint di segnalazione esisteva ma era
     *                  irraggiungibile.
     *                  <p>E' {@code null} quando la cella non ha una domanda
     *                  (i vecchi tabelloni con celle segnaposto) e anche
     *                  quando ne ha una ma il testo e' stato riscritto a mano:
     *                  in quel caso chi gioca legge l'override, non la domanda
     *                  condivisa, e segnalarla significherebbe accusare un
     *                  testo mai visto.
     */
    public record CellaDto(
            Long id,
            Long domandaId,
            short riga,
            int valore,
            boolean dailyDouble,
            String testo,
            String risposta) {

        public static CellaDto from(Cella cella) {
            return new CellaDto(
                    cella.getId(),
                    cella.idDomandaVisibile(),
                    cella.getRiga(),
                    cella.getValore(),
                    cella.isDailyDouble(),
                    cella.testoEffettivo(),
                    cella.rispostaEffettiva());
        }
    }

    /**
     * Esito di una rigenerazione.
     *
     * <p>Esiste perche' "non ci sono altre domande per questa cella" e' una
     * risposta, non un guasto: prima era un 409, che il client doveva
     * riconoscere fra gli errori veri per non mostrare un allarme rosso a chi
     * aveva solo esaurito le alternative. Adesso e' un 200 con
     * {@code rigenerata: false} e un motivo da raccontare.
     *
     * @param cella      la cella, nuova se e' cambiata, invariata altrimenti
     * @param rigenerata se la domanda e' stata effettivamente sostituita
     * @param motivo     perche' no, quando {@code rigenerata} e' falso; il
     *                   client decide come dirlo, questo non e' testo da
     *                   mostrare cosi' com'e'
     */
    public record RigenerazioneDto(CellaDto cella, boolean rigenerata, String motivo) {

        public static RigenerazioneDto fatta(Cella cella) {
            return new RigenerazioneDto(CellaDto.from(cella), true, null);
        }

        public static RigenerazioneDto nessunaAlternativa(Cella cella) {
            return new RigenerazioneDto(CellaDto.from(cella), false,
                    "nessuna_alternativa_disponibile");
        }
    }

    public record TabelloneSintesiDto(
            String codicePubblico,
            String titolo,
            short righe,
            int puntiBase,
            Instant creatoIl) {

        public static TabelloneSintesiDto from(Tabellone tabellone) {
            return new TabelloneSintesiDto(
                    tabellone.getCodicePubblico(),
                    tabellone.getTitolo(),
                    tabellone.getRighe(),
                    tabellone.getPuntiBase(),
                    tabellone.getCreatoIl());
        }
    }
}
