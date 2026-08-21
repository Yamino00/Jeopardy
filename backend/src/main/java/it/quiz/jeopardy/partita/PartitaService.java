package it.quiz.jeopardy.partita;

import it.quiz.jeopardy.comune.ResourceNotFoundException;
import it.quiz.jeopardy.partita.PartitaDtos.CreatePartitaRequest;
import it.quiz.jeopardy.partita.PartitaDtos.EventoDto;
import it.quiz.jeopardy.partita.PartitaDtos.PartitaDto;
import it.quiz.jeopardy.partita.PartitaDtos.PlayCellaRequest;
import it.quiz.jeopardy.partita.PartitaDtos.SquadraCreate;
import it.quiz.jeopardy.partita.PartitaDtos.SquadraDto;
import it.quiz.jeopardy.partita.PartitaDtos.SquadraUpdate;
import it.quiz.jeopardy.tabellone.Cella;
import it.quiz.jeopardy.tabellone.CellaRepository;
import it.quiz.jeopardy.tabellone.Tabellone;
import it.quiz.jeopardy.tabellone.TabelloneRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.Map;

/**
 * Game orchestration. The one hard rule: a team's score must always be
 * derivable as the sum of {@code delta_punti} of its non-cancelled events —
 * plays, manual corrections and undos all go through the event log.
 */
@Service
public class PartitaService {

    private final PartitaRepository partitaRepository;
    private final SquadraRepository squadraRepository;
    private final CellaGiocataRepository cellaGiocataRepository;
    private final EventoPartitaRepository eventoPartitaRepository;
    private final TabelloneRepository tabelloneRepository;
    private final CellaRepository cellaRepository;
    private final int scadenzaGiorni;

    public PartitaService(PartitaRepository partitaRepository,
                          SquadraRepository squadraRepository,
                          CellaGiocataRepository cellaGiocataRepository,
                          EventoPartitaRepository eventoPartitaRepository,
                          TabelloneRepository tabelloneRepository,
                          CellaRepository cellaRepository,
                          @Value("${app.partita.scadenza-giorni:30}") int scadenzaGiorni) {
        this.partitaRepository = partitaRepository;
        this.squadraRepository = squadraRepository;
        this.cellaGiocataRepository = cellaGiocataRepository;
        this.eventoPartitaRepository = eventoPartitaRepository;
        this.tabelloneRepository = tabelloneRepository;
        this.cellaRepository = cellaRepository;
        this.scadenzaGiorni = scadenzaGiorni;
    }

    @Transactional
    public PartitaDto start(String codicePubblico, CreatePartitaRequest request) {
        Tabellone tabellone = tabelloneRepository.findByCodicePubblico(codicePubblico)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Tabellone " + codicePubblico + " non trovato"));
        tabellone.setUltimoUsoIl(Instant.now());

        Partita partita = new Partita();
        partita.setTabellone(tabellone);
        partita.setScadeIl(Instant.now().plus(scadenzaGiorni, ChronoUnit.DAYS));

        short posizione = 1;
        if (request.squadre() != null) {
            for (SquadraCreate creazione : request.squadre()) {
                partita.addSquadra(newSquadra(creazione, posizione++));
            }
        }
        partita = partitaRepository.save(partita);
        if (!partita.getSquadre().isEmpty()) {
            partita.setTurnoSquadraId(partita.getSquadre().get(0).getId());
        }
        return toDto(partita);
    }

    @Transactional(readOnly = true)
    public PartitaDto get(Long partitaId) {
        return toDto(loadPartita(partitaId));
    }

    @Transactional
    public SquadraDto addSquadra(Long partitaId, SquadraCreate request) {
        Partita partita = loadPartita(partitaId);
        requireInCorso(partita);
        short posizione = (short) (partita.getSquadre().stream()
                .mapToInt(Squadra::getPosizione).max().orElse(0) + 1);
        Squadra squadra = newSquadra(request, posizione);
        partita.addSquadra(squadra);
        squadraRepository.save(squadra);
        if (partita.getTurnoSquadraId() == null) {
            partita.setTurnoSquadraId(squadra.getId());
        }
        return SquadraDto.from(squadra);
    }

    @Transactional
    public SquadraDto updateSquadra(Long partitaId, Long squadraId, SquadraUpdate request) {
        Partita partita = loadPartita(partitaId);
        requireInCorso(partita);
        Squadra squadra = findSquadra(partita, squadraId);
        if (request.nome() != null && !request.nome().isBlank()) {
            squadra.setNome(request.nome().strip());
        }
        if (request.colore() != null) {
            squadra.setColore(request.colore());
        }
        if (request.punteggio() != null && request.punteggio() != squadra.getPunteggio()) {
            // Manual fix goes through the log so the score stays derivable
            int delta = request.punteggio() - squadra.getPunteggio();
            appendEvento(partita.getId(), squadra.getId(), TipoEvento.CORREZIONE, delta,
                    Map.of("da", squadra.getPunteggio(), "a", request.punteggio()));
            squadra.setPunteggio(request.punteggio());
        }
        return SquadraDto.from(squadra);
    }

    @Transactional
    public void removeSquadra(Long partitaId, Long squadraId) {
        Partita partita = loadPartita(partitaId);
        requireInCorso(partita);
        Squadra squadra = findSquadra(partita, squadraId);
        squadra.setAttiva(false);
        if (squadraId.equals(partita.getTurnoSquadraId())) {
            partita.setTurnoSquadraId(nextTurno(partita, squadra));
        }
    }

    @Transactional
    public EventoDto playCella(Long partitaId, Long cellaId, PlayCellaRequest request) {
        Partita partita = loadPartita(partitaId);
        requireInCorso(partita);

        Cella cella = cellaRepository.findById(cellaId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Cella " + cellaId + " non trovata"));
        Long tabelloneCella = cella.getCategoria().getTabellone().getId();
        if (!tabelloneCella.equals(partita.getTabellone().getId())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "La cella non appartiene al tabellone di questa partita");
        }
        if (cellaGiocataRepository.existsById(new CellaGiocataId(partitaId, cellaId))) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "Cella gia giocata in questa partita");
        }

        Squadra squadra = request.squadraId() == null
                ? null : findSquadra(partita, request.squadraId());

        cellaGiocataRepository.save(new CellaGiocata(
                partitaId, cellaId, request.squadraId(), request.esito()));

        Map<String, Object> payload = new HashMap<>();
        payload.put("cella_id", cellaId);
        payload.put("esito", request.esito().dbValue());
        EventoPartita evento = appendEvento(partitaId, request.squadraId(),
                TipoEvento.CELLA_GIOCATA, request.deltaPunti(), payload);

        if (squadra != null) {
            squadra.setPunteggio(squadra.getPunteggio() + request.deltaPunti());
            partita.setTurnoSquadraId(nextTurno(partita, squadra));
        }
        return EventoDto.from(evento);
    }

    /**
     * Cancels the newest non-cancelled event and recomputes the affected
     * team's score from the log. A cell play also frees the cell for replay.
     *
     * <p>A registro vuoto non e' un errore: risponde
     * {@link PartitaDtos.AnnullamentoDto#nienteDaAnnullare()}. L'annulla e'
     * il pulsante che l'host preme di corsa quando sbaglia ad assegnare i
     * punti, e premerlo una volta di troppo non deve produrre un allarme.
     */
    @Transactional
    public PartitaDtos.AnnullamentoDto annulla(Long partitaId) {
        Partita partita = loadPartita(partitaId);
        requireInCorso(partita);
        EventoPartita evento = eventoPartitaRepository
                .findFirstByPartitaIdAndAnnullatoFalseOrderByIdDesc(partitaId)
                .orElse(null);
        if (evento == null) {
            return PartitaDtos.AnnullamentoDto.nienteDaAnnullare();
        }

        evento.setAnnullato(true);

        if (evento.getTipo() == TipoEvento.CELLA_GIOCATA && evento.getPayload() != null) {
            Number cellaId = (Number) evento.getPayload().get("cella_id");
            if (cellaId != null) {
                cellaGiocataRepository.deleteById(
                        new CellaGiocataId(partitaId, cellaId.longValue()));
            }
        }
        if (evento.getSquadraId() != null) {
            partita.getSquadre().stream()
                    .filter(s -> s.getId().equals(evento.getSquadraId()))
                    .findFirst()
                    .ifPresent(s -> s.setPunteggio(
                            eventoPartitaRepository.sumDeltaBySquadra(partitaId, s.getId())));
        }
        return PartitaDtos.AnnullamentoDto.fatto(evento);
    }

    @Transactional
    public PartitaDto concludi(Long partitaId) {
        Partita partita = loadPartita(partitaId);
        requireInCorso(partita);
        partita.setStato(StatoPartita.CONCLUSA);
        partita.setConclusaIl(Instant.now());
        return toDto(partita);
    }

    private Squadra newSquadra(SquadraCreate request, short posizione) {
        Squadra squadra = new Squadra();
        squadra.setNome(request.nome().strip());
        squadra.setColore(request.colore());
        squadra.setPosizione(posizione);
        return squadra;
    }

    private EventoPartita appendEvento(Long partitaId, Long squadraId, TipoEvento tipo,
                                       Integer deltaPunti, Map<String, Object> payload) {
        EventoPartita evento = new EventoPartita();
        evento.setPartitaId(partitaId);
        evento.setSquadraId(squadraId);
        evento.setTipo(tipo);
        evento.setDeltaPunti(deltaPunti);
        evento.setPayload(payload);
        return eventoPartitaRepository.save(evento);
    }

    /** Next active team by position after the given one, wrapping around. */
    private Long nextTurno(Partita partita, Squadra corrente) {
        var attive = partita.getSquadre().stream().filter(Squadra::isAttiva).toList();
        if (attive.isEmpty()) {
            return null;
        }
        int index = attive.indexOf(corrente);
        return attive.get((index + 1) % attive.size()).getId();
    }

    private Partita loadPartita(Long partitaId) {
        return partitaRepository.findById(partitaId)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Partita " + partitaId + " non trovata"));
    }

    private Squadra findSquadra(Partita partita, Long squadraId) {
        return partita.getSquadre().stream()
                .filter(s -> s.getId().equals(squadraId))
                .findFirst()
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Squadra " + squadraId + " non trovata nella partita"));
    }

    private static void requireInCorso(Partita partita) {
        if (partita.getStato() != StatoPartita.IN_CORSO) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "La partita non e in corso");
        }
    }

    private PartitaDto toDto(Partita partita) {
        return PartitaDto.from(partita,
                cellaGiocataRepository.findByPartitaIdOrderByGiocataIlAsc(partita.getId()));
    }
}
