package it.quiz.jeopardy.banca;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface DomandaRepository extends JpaRepository<Domanda, Long> {

    /**
     * Step 1 of the dedup cascade: canonical entity already present for the
     * topic, ignoring retired questions (mirrors the partial unique index
     * {@code ux_domanda_entita}).
     */
    @Query("""
            select count(d) > 0 from Domanda d
            where d.argomento.id = :argomentoId
              and d.entitaCanonica = :entitaCanonica
              and d.stato <> it.quiz.jeopardy.banca.StatoDomanda.RITIRATA
            """)
    boolean existsActiveByArgomentoAndEntita(@Param("argomentoId") Long argomentoId,
                                             @Param("entitaCanonica") String entitaCanonica);

    /**
     * Step 2: same normalized text already present for the topic (mirrors the
     * unique index {@code ux_domanda_hash} on {@code (argomento_id, hash_testo)}).
     */
    boolean existsByArgomentoIdAndHashTesto(Long argomentoId, byte[] hashTesto);

    /**
     * Step 3: trigram similarity above the threshold, restricted to the same
     * topic. Requires the pg_trgm extension (migration V1).
     */
    @Query(value = """
            SELECT EXISTS (
                SELECT 1 FROM domanda
                WHERE argomento_id = :argomentoId
                  AND similarity(testo, :testo) > :soglia
            )
            """, nativeQuery = true)
    boolean existsSimilarText(@Param("argomentoId") Long argomentoId,
                              @Param("testo") String testo,
                              @Param("soglia") double soglia);

    List<Domanda> findByArgomentoIdAndStato(Long argomentoId, StatoDomanda stato);

    /**
     * Active questions for a cell (argomento, sotto_argomento, difficolta) not
     * yet used in any tabellone created by this client, least-used first.
     */
    @Query(value = """
            SELECT d.* FROM domanda d
            WHERE d.argomento_id = :argomentoId
              AND d.stato = 'attiva'
              AND d.difficolta = :difficolta
              AND (CAST(:sottoArgomento AS text) IS NULL
                   OR d.sotto_argomento = CAST(:sottoArgomento AS text))
              AND NOT EXISTS (
                  SELECT 1 FROM cella c
                  JOIN categoria cat ON cat.id = c.categoria_id
                  JOIN tabellone t ON t.id = cat.tabellone_id
                  WHERE c.domanda_id = d.id AND t.client_creatore = :clientId
              )
            ORDER BY d.volte_usata ASC, d.id ASC
            LIMIT :limite
            """, nativeQuery = true)
    List<Domanda> findAvailableForClient(@Param("argomentoId") Long argomentoId,
                                         @org.springframework.lang.Nullable
                                         @Param("sottoArgomento") String sottoArgomento,
                                         @Param("difficolta") short difficolta,
                                         @Param("clientId") java.util.UUID clientId,
                                         @Param("limite") int limite);

    /**
     * Ripiego: domande attive di <b>qualunque</b> difficolta' non ancora usate
     * da questo client, meno usate per prime.
     *
     * <p>Serve quando la deduplicazione non lascia abbastanza domande della
     * fascia giusta. Una domanda di difficolta' vicina sulla riga sbagliata e'
     * un difetto piccolo; una cella con scritto "Domanda da completare" e'
     * una cella rotta davanti a chi sta giocando.
     *
     * @param esclusi id gia' scelti in questo stesso giro. Non passare mai una
     *                lista vuota: usare {@code List.of(-1L)}, perche' un
     *                {@code not in ()} non e' SQL valido.
     */
    @Query("""
            select d from Domanda d
            where d.argomento.id = :argomentoId
              and d.stato = it.quiz.jeopardy.banca.StatoDomanda.ATTIVA
              and (:sottoArgomento is null or d.sottoArgomento = :sottoArgomento)
              and d.id not in :esclusi
              and not exists (
                  select 1 from Cella c
                  where c.domanda = d
                    and c.categoria.tabellone.clientCreatore = :clientId
              )
            order by d.volteUsata asc, d.id asc
            """)
    List<Domanda> findRipiegoNonUsateDalClient(@Param("argomentoId") Long argomentoId,
                                               @org.springframework.lang.Nullable
                                               @Param("sottoArgomento") String sottoArgomento,
                                               @Param("clientId") java.util.UUID clientId,
                                               @Param("esclusi") List<Long> esclusi,
                                               org.springframework.data.domain.Pageable limite);

    /**
     * Ultimo gradino: domande attive dell'argomento anche se questo client le
     * ha gia' viste, meno usate per prime. Una ripetizione e' il male minore
     * rispetto a un tabellone con i buchi.
     *
     * @param esclusi come sopra, mai vuota.
     */
    @Query("""
            select d from Domanda d
            where d.argomento.id = :argomentoId
              and d.stato = it.quiz.jeopardy.banca.StatoDomanda.ATTIVA
              and (:sottoArgomento is null or d.sottoArgomento = :sottoArgomento)
              and d.id not in :esclusi
            order by d.volteUsata asc, d.id asc
            """)
    List<Domanda> findRipiegoAncheGiaUsate(@Param("argomentoId") Long argomentoId,
                                           @org.springframework.lang.Nullable
                                           @Param("sottoArgomento") String sottoArgomento,
                                           @Param("esclusi") List<Long> esclusi,
                                           org.springframework.data.domain.Pageable limite);

    /**
     * Blocklist for the LLM prompt: canonical entities already present for the
     * topic (retired questions excluded, matching the unique index).
     */
    @Query("""
            select d.entitaCanonica from Domanda d
            where d.argomento.id = :argomentoId
              and d.stato <> it.quiz.jeopardy.banca.StatoDomanda.RITIRATA
            """)
    List<String> findEntitaCanonicheByArgomento(@Param("argomentoId") Long argomentoId);

    /**
     * La domanda con la riga bloccata in scrittura, per la segnalazione.
     *
     * Serve perche' la soglia e' un invariante: due segnalazioni simultanee
     * sulla stessa domanda, senza lock, contano entrambe le righe committate
     * *prima* di loro e nessuna delle due fa scattare la disattivazione. Con il
     * blocco la seconda aspetta la prima e vede il conteggio giusto.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select d from Domanda d where d.id = :id")
    Optional<Domanda> findByIdBloccando(@Param("id") Long id);
}
