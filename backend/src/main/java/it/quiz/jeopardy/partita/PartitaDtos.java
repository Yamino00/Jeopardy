package it.quiz.jeopardy.partita;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;

/**
 * Request/response models for the game endpoints. Deliberately permissive:
 * no team-name uniqueness, everything editable mid-game.
 */
public final class PartitaDtos {

    private PartitaDtos() {
    }

    public record CreatePartitaRequest(
            @Valid @Size(max = 12) List<SquadraCreate> squadre) {
    }

    public record SquadraCreate(
            @NotBlank String nome,
            String colore) {
    }

    public record SquadraUpdate(
            String nome,
            String colore,
            Integer punteggio) {
    }

    public record PlayCellaRequest(
            Long squadraId,
            @NotNull EsitoCella esito,
            @NotNull Integer deltaPunti) {
    }

    public record SquadraDto(
            Long id,
            String nome,
            String colore,
            int punteggio,
            short posizione,
            boolean attiva) {

        public static SquadraDto from(Squadra squadra) {
            return new SquadraDto(
                    squadra.getId(),
                    squadra.getNome(),
                    squadra.getColore(),
                    squadra.getPunteggio(),
                    squadra.getPosizione(),
                    squadra.isAttiva());
        }
    }

    public record CellaGiocataDto(
            Long cellaId,
            Long squadraId,
            EsitoCella esito) {

        public static CellaGiocataDto from(CellaGiocata giocata) {
            return new CellaGiocataDto(
                    giocata.getCellaId(),
                    giocata.getSquadraId(),
                    giocata.getEsito());
        }
    }

    public record EventoDto(
            Long id,
            TipoEvento tipo,
            Long squadraId,
            Integer deltaPunti,
            boolean annullato) {

        public static EventoDto from(EventoPartita evento) {
            return new EventoDto(
                    evento.getId(),
                    evento.getTipo(),
                    evento.getSquadraId(),
                    evento.getDeltaPunti(),
                    evento.isAnnullato());
        }
    }

    /**
     * Esito di un annullamento.
     *
     * <p>"Non c'e' niente da annullare" e' lo stato normale a partita appena
     * aperta, non un guasto: prima era un 409, e l'host che premeva annulla per
     * sbaglio si vedeva un errore. Adesso e' un 200 con
     * {@code annullato: false} e nessun evento.
     *
     * @param evento    l'evento annullato, {@code null} se non ce n'erano
     * @param annullato se qualcosa e' stato davvero annullato
     */
    public record AnnullamentoDto(EventoDto evento, boolean annullato) {

        public static AnnullamentoDto fatto(EventoPartita evento) {
            return new AnnullamentoDto(EventoDto.from(evento), true);
        }

        public static AnnullamentoDto nienteDaAnnullare() {
            return new AnnullamentoDto(null, false);
        }
    }

    public record PartitaDto(
            Long id,
            String codiceTabellone,
            StatoPartita stato,
            Long turnoSquadraId,
            Instant iniziataIl,
            Instant conclusaIl,
            List<SquadraDto> squadre,
            List<CellaGiocataDto> celleGiocate) {

        public static PartitaDto from(Partita partita, List<CellaGiocata> celleGiocate) {
            return new PartitaDto(
                    partita.getId(),
                    partita.getTabellone().getCodicePubblico(),
                    partita.getStato(),
                    partita.getTurnoSquadraId(),
                    partita.getIniziataIl(),
                    partita.getConclusaIl(),
                    partita.getSquadre().stream().map(SquadraDto::from).toList(),
                    celleGiocate.stream().map(CellaGiocataDto::from).toList());
        }
    }
}
