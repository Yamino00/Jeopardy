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

    public record CellaDto(
            Long id,
            short riga,
            int valore,
            boolean dailyDouble,
            String testo,
            String risposta) {

        public static CellaDto from(Cella cella) {
            return new CellaDto(
                    cella.getId(),
                    cella.getRiga(),
                    cella.getValore(),
                    cella.isDailyDouble(),
                    cella.testoEffettivo(),
                    cella.rispostaEffettiva());
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
