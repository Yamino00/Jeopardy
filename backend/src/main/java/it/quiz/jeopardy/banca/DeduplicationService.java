package it.quiz.jeopardy.banca;

import it.quiz.jeopardy.comune.Normalizer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.List;
import java.util.Set;

import it.quiz.jeopardy.banca.DeduplicationResult.AcceptedCandidate;
import it.quiz.jeopardy.banca.DeduplicationResult.RejectedCandidate;

/**
 * Dedup cascade for candidate questions, stopping at the first rejection:
 * <ol>
 *   <li>canonical entity already present for the topic (indexed query,
 *       ignoring retired questions);</li>
 *   <li>normalized-text hash already present for the topic;</li>
 *   <li>trigram similarity above threshold, restricted to the topic.</li>
 * </ol>
 * The batch is also deduplicated against itself (same canonical entity or
 * same hash appearing twice), not only against the database.
 */
@Service
public class DeduplicationService {

    private final DomandaRepository domandaRepository;
    private final double sogliaSimilarita;

    public DeduplicationService(DomandaRepository domandaRepository,
                                @Value("${app.dedup.soglia-similarita:0.6}") double sogliaSimilarita) {
        this.domandaRepository = domandaRepository;
        this.sogliaSimilarita = sogliaSimilarita;
    }

    @Transactional(readOnly = true)
    public DeduplicationResult deduplicate(Long argomentoId, List<CandidateQuestion> candidates) {
        List<AcceptedCandidate> accettate = new ArrayList<>();
        List<RejectedCandidate> scartate = new ArrayList<>();

        Set<String> batchEntita = new HashSet<>();
        Set<String> batchHash = new HashSet<>();

        for (CandidateQuestion candidate : candidates) {
            String entitaCanonica = Normalizer.toCanonical(candidate.risposta());
            byte[] hashTesto = Normalizer.hashTesto(candidate.testo());
            String hashKey = HexFormat.of().formatHex(hashTesto);

            if (!batchEntita.add(entitaCanonica)
                    || domandaRepository.existsActiveByArgomentoAndEntita(argomentoId, entitaCanonica)) {
                scartate.add(new RejectedCandidate(candidate, RejectionReason.DUPLICATO_ENTITA));
                continue;
            }
            if (!batchHash.add(hashKey)
                    || domandaRepository.existsByArgomentoIdAndHashTesto(argomentoId, hashTesto)) {
                scartate.add(new RejectedCandidate(candidate, RejectionReason.DUPLICATO_TESTO));
                continue;
            }
            if (domandaRepository.existsSimilarText(argomentoId, candidate.testo(), sogliaSimilarita)) {
                scartate.add(new RejectedCandidate(candidate, RejectionReason.TESTO_SIMILE));
                continue;
            }
            accettate.add(new AcceptedCandidate(candidate, entitaCanonica, hashTesto));
        }
        return new DeduplicationResult(accettate, scartate);
    }
}
