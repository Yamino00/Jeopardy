-- Una segnalazione per dispositivo, garantita dal database.
--
-- La regola vive gia' in SegnalazioneService, che prima di inserire blocca la
-- riga della domanda e controlla se questo client l'ha gia' segnalata. Questo
-- indice la rende strutturale: nessun percorso futuro — un job, uno script,
-- un secondo servizio — puo' aggirarla per distrazione.
--
-- Perche' conta: la domanda e' condivisa fra tutti i tabelloni, e la soglia che
-- la disattiva presuppone pareri di dispositivi diversi. Senza questo vincolo
-- un solo telefono puo' consumare la soglia da solo.

-- 1. Le righe che il vincolo rifiuterebbe. Sopravvive la piu' vecchia: e' la
--    segnalazione che l'utente ha davvero voluto fare, le altre sono ritocchi.
DELETE FROM segnalazione doppia
USING segnalazione originale
WHERE doppia.domanda_id = originale.domanda_id
  AND doppia.client_id  = originale.client_id
  AND doppia.client_id IS NOT NULL
  AND doppia.id > originale.id;

-- 2. Il vincolo. Parziale su client_id NOT NULL per dirlo esplicitamente:
--    in PostgreSQL i NULL sono gia' distinti fra loro in un indice unico, e
--    una segnalazione senza client non e' attribuibile a nessuno, quindi non
--    deve bloccarne altre.
CREATE UNIQUE INDEX ux_segnalazione_client
    ON segnalazione (domanda_id, client_id)
    WHERE client_id IS NOT NULL;

-- 3. Il contatore torna a coincidere con le righe rimaste. Da qui in avanti il
--    servizio lo ricalcola a ogni segnalazione invece di incrementarlo, quindi
--    questa e' l'ultima volta che puo' divergere.
UPDATE domanda d
SET segnalazioni = (
    SELECT count(*) FROM segnalazione s WHERE s.domanda_id = d.id
)
WHERE d.segnalazioni <> (
    SELECT count(*) FROM segnalazione s WHERE s.domanda_id = d.id
);

-- Nota deliberata: `stato` non si tocca. Una domanda disattivata resta
-- disattivata anche se la deduplicazione le ha tolto delle segnalazioni.
-- Riattivarla sarebbe una decisione di merito, e una migrazione non e' il
-- posto dove si prendono decisioni di merito su contenuti che qualcuno ha
-- gia' giudicato sbagliati.
