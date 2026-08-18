@Tags(['e2e'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/storage/client_id_storage.dart';
import 'package:frontend/data/partita_repository.dart';
import 'package:frontend/data/tabellone_repository.dart';
import 'package:frontend/models/partita.dart';
import 'package:uuid/uuid.dart';

/// End-to-end flow against the REAL backend (docker compose up -d).
/// Opt-in: `flutter test --tags e2e --run-skipped`. Exercises the same
/// repositories and
/// models the UI uses, so a schema drift on either side fails here.
///
/// Requires the seeded bank (scripts/seed-banca.sql) so no LLM call is needed.
void main() {
  late TabelloneRepository tabelloni;
  late PartitaRepository partite;

  /// flutter_test installs an HttpOverrides that fails every real request,
  /// and does so right before each test body: the reset has to live here.
  void abilitaReteReale() {
    HttpOverrides.global = null;
    final api = ApiClient(clientIdStorage: _FixedClientIdStorage());
    tabelloni = TabelloneRepository(api);
    partite = PartitaRepository(api);
  }

  test('crea tabellone, gioca tre celle, annulla, concludi', () async {
    abilitaReteReale();

    // 1. Creazione: due categorie servite dalla banca seedata
    final tabellone = await tabelloni.crea(
      titolo: 'E2E Flutter',
      argomenti: ['Storia romana', 'Geografia'],
      righe: 3,
      puntiBase: 100,
    );
    expect(tabellone.codicePubblico.length, 6);
    expect(tabellone.codiceModifica, isNotNull);
    expect(tabellone.categorie, hasLength(2));
    for (final categoria in tabellone.categorie) {
      expect(categoria.celle, hasLength(3));
      for (final cella in categoria.celle) {
        expect(cella.testo, isNotEmpty);
        expect(cella.valore, 100 * cella.riga);
      }
    }

    // Il GET pubblico non espone il codice di modifica
    final pubblico = await tabelloni.byCodice(tabellone.codicePubblico);
    expect(pubblico.codiceModifica, isNull);

    // Il tabellone compare fra i miei
    final miei = await tabelloni.miei();
    expect(miei.map((t) => t.codicePubblico), contains(tabellone.codicePubblico));

    // 2. Avvio partita con due squadre
    var partita = await partite.avvia(tabellone.codicePubblico, [
      (nome: 'Rossi', colore: '#e53935'),
      (nome: 'Blu', colore: '#1e88e5'),
    ]);
    expect(partita.inCorso, isTrue);
    expect(partita.squadreAttive, hasLength(2));
    final rossi = partita.squadre[0];
    final blu = partita.squadre[1];
    expect(partita.turnoSquadraId, rossi.id);

    // 3. Gioca tre celle: due corrette e una errata
    final celle = tabellone.categorie.first.celle;
    await partite.giocaCella(
      partitaId: partita.id,
      cellaId: celle[0].id,
      esito: 'corretta',
      deltaPunti: celle[0].valore,
      squadraId: rossi.id,
    );
    await partite.giocaCella(
      partitaId: partita.id,
      cellaId: celle[1].id,
      esito: 'corretta',
      deltaPunti: celle[1].valore,
      squadraId: blu.id,
    );
    await partite.giocaCella(
      partitaId: partita.id,
      cellaId: celle[2].id,
      esito: 'errata',
      deltaPunti: -celle[2].valore,
      squadraId: rossi.id,
    );

    partita = await partite.byId(partita.id);
    expect(partita.celleGiocate, hasLength(3));
    expect(_punteggio(partita, rossi.id), celle[0].valore - celle[2].valore);
    expect(_punteggio(partita, blu.id), celle[1].valore);

    // Rigiocare la stessa cella e' rifiutato
    await expectLater(
      partite.giocaCella(
        partitaId: partita.id,
        cellaId: celle[0].id,
        esito: 'corretta',
        deltaPunti: 100,
        squadraId: rossi.id,
      ),
      throwsA(isA<ApiException>()),
    );

    // 4. Annulla: l'errata sparisce, il punteggio torna e la cella si libera
    await partite.annulla(partita.id);
    partita = await partite.byId(partita.id);
    expect(partita.celleGiocate, hasLength(2));
    expect(partita.cellaGiaGiocata(celle[2].id), isFalse);
    expect(_punteggio(partita, rossi.id), celle[0].valore);

    // 5. Concludi: la partita si congela
    partita = await partite.concludi(partita.id);
    expect(partita.inCorso, isFalse);
    expect(partita.stato, 'conclusa');

    await expectLater(
      partite.giocaCella(
        partitaId: partita.id,
        cellaId: celle[2].id,
        esito: 'corretta',
        deltaPunti: 100,
        squadraId: rossi.id,
      ),
      throwsA(isA<ApiException>()),
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('codice tabellone inesistente -> errore leggibile', () async {
    abilitaReteReale();
    await expectLater(
      tabelloni.byCodice('ZZZZZZ'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', contains('non trovato')),
      ),
    );
  });
}

int _punteggio(Partita partita, int squadraId) =>
    partita.squadre.firstWhere((s) => s.id == squadraId).punteggio;

/// Stable client id for the whole run: SharedPreferences is not available
/// outside the app, and a fresh id keeps each run isolated from previous
/// boards (the bank excludes questions already used by the same client).
class _FixedClientIdStorage implements ClientIdStorage {
  static final String _id = const Uuid().v4();

  @override
  Future<String> getOrCreateClientId() async => _id;
}
