-- Seed della banca domande per testare il backend SENZA GEMINI_API_KEY.
-- Idempotente: rilanciarlo non crea duplicati (ON CONFLICT DO NOTHING).
--
-- Uso:
--   docker exec -i jeopardy-postgres psql -U jeopardy -d jeopardy < scripts/seed-banca.sql
--
-- Gli slug corrispondono ai nomi 'Storia romana' e 'Geografia' normalizzati:
-- creando un tabellone con quegli argomenti, le celle si riempiono dalla banca.

INSERT INTO argomento (nome, slug, lingua) VALUES
    ('Storia romana', 'storia-romana', 'it'),
    ('Geografia', 'geografia', 'it')
ON CONFLICT DO NOTHING;

-- Due domande per ogni difficolta (1-5): bastano per un tabellone da 5 righe
-- e lasciano una domanda di riserva per testare la rigenerazione delle celle.
WITH arg AS (SELECT id FROM argomento WHERE slug = 'storia-romana')
INSERT INTO domanda (argomento_id, testo, risposta, entita_canonica, hash_testo, difficolta)
SELECT arg.id, d.testo, d.risposta, d.entita,
       sha256(convert_to(lower(d.testo), 'UTF8')), d.diff
FROM arg, (VALUES
    ('Chi fu il primo imperatore romano?',                       'Augusto',            'augusto',            1),
    ('In quale citta si trova il Colosseo?',                     'Roma',               'roma',               1),
    ('Chi attraverso il Rubicone nel 49 a.C.?',                  'Giulio Cesare',      'giulio cesare',      2),
    ('Come si chiamava il senato di eta repubblicana?',          'Il Senato romano',   'senato romano',      2),
    ('Chi fu l''ultimo re di Roma?',                             'Tarquinio il Superbo', 'tarquinio il superbo', 3),
    ('Quale generale cartaginese attraverso le Alpi?',           'Annibale',           'annibale',           3),
    ('In quale battaglia Ottaviano sconfisse Antonio?',          'Azio',               'azio',               4),
    ('Chi scrisse il De Bello Gallico?',                         'Cesare',             'cesare',             4),
    ('In che anno cadde l''Impero Romano d''Occidente?',         'Il 476 d.C.',        '476 dc',             5),
    ('Quale imperatore divise l''impero in tetrarchia?',         'Diocleziano',        'diocleziano',        5)
) AS d(testo, risposta, entita, diff)
ON CONFLICT DO NOTHING;

WITH arg AS (SELECT id FROM argomento WHERE slug = 'geografia')
INSERT INTO domanda (argomento_id, testo, risposta, entita_canonica, hash_testo, difficolta)
SELECT arg.id, d.testo, d.risposta, d.entita,
       sha256(convert_to(lower(d.testo), 'UTF8')), d.diff
FROM arg, (VALUES
    ('Qual e la capitale della Francia?',                        'Parigi',             'parigi',             1),
    ('Quale fiume attraversa Roma?',                             'Il Tevere',          'tevere',             1),
    ('Qual e il monte piu alto d''Europa?',                      'Il Monte Bianco',    'monte bianco',       2),
    ('In quale continente si trova il deserto del Gobi?',        'Asia',               'asia',               2),
    ('Qual e il lago piu grande d''Italia?',                     'Il Lago di Garda',   'lago di garda',      3),
    ('Quale stretto separa l''Europa dall''Africa?',             'Gibilterra',         'gibilterra',         3),
    ('Qual e la capitale dell''Australia?',                      'Canberra',           'canberra',           4),
    ('Quale catena montuosa separa Europa e Asia?',              'Gli Urali',          'urali',              4),
    ('Qual e il punto piu profondo degli oceani?',               'La Fossa delle Marianne', 'fossa delle marianne', 5),
    ('Quale paese ha piu fusi orari al mondo?',                  'La Francia',         'francia',            5)
) AS d(testo, risposta, entita, diff)
ON CONFLICT DO NOTHING;
