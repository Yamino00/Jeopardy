import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/storage/client_id_storage.dart';
import '../models/partita.dart';
import '../models/tabellone.dart';
import 'partita_repository.dart';
import 'tabellone_repository.dart';

final clientIdStorageProvider = Provider<ClientIdStorage>(
  (ref) => ClientIdStorage(),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(clientIdStorage: ref.watch(clientIdStorageProvider)),
);

final tabelloneRepositoryProvider = Provider<TabelloneRepository>(
  (ref) => TabelloneRepository(ref.watch(apiClientProvider)),
);

final partitaRepositoryProvider = Provider<PartitaRepository>(
  (ref) => PartitaRepository(ref.watch(apiClientProvider)),
);

/// Board by public code. keepAlive: the game screen re-reads it without
/// refetching, and the board itself never changes mid-game.
final tabelloneProvider =
    FutureProvider.family<Tabellone, String>((ref, codice) {
  return ref.watch(tabelloneRepositoryProvider).byCodice(codice);
});

final mieiTabelloniProvider = FutureProvider<List<TabelloneSintesi>>((ref) {
  return ref.watch(tabelloneRepositoryProvider).miei();
});

/// Live game state, reloaded from the backend after every action so the
/// score always reflects the event log (the backend is the source of truth).
final partitaProvider =
    AsyncNotifierProvider.family<PartitaNotifier, Partita, int>(
  PartitaNotifier.new,
);

class PartitaNotifier extends FamilyAsyncNotifier<Partita, int> {
  @override
  Future<Partita> build(int arg) {
    return ref.watch(partitaRepositoryProvider).byId(arg);
  }

  PartitaRepository get _repo => ref.read(partitaRepositoryProvider);

  Future<void> _refresh() async {
    state = AsyncValue.data(await _repo.byId(arg));
  }

  Future<void> giocaCella({
    required int cellaId,
    required String esito,
    required int deltaPunti,
    int? squadraId,
  }) async {
    await _repo.giocaCella(
      partitaId: arg,
      cellaId: cellaId,
      esito: esito,
      deltaPunti: deltaPunti,
      squadraId: squadraId,
    );
    await _refresh();
  }

  Future<void> aggiungiSquadra(String nome, {String? colore}) async {
    await _repo.aggiungiSquadra(arg, nome, colore: colore);
    await _refresh();
  }

  Future<void> aggiornaSquadra(int squadraId,
      {String? nome, String? colore, int? punteggio}) async {
    await _repo.aggiornaSquadra(arg, squadraId,
        nome: nome, colore: colore, punteggio: punteggio);
    await _refresh();
  }

  Future<void> rimuoviSquadra(int squadraId) async {
    await _repo.rimuoviSquadra(arg, squadraId);
    await _refresh();
  }

  Future<void> annulla() async {
    await _repo.annulla(arg);
    await _refresh();
  }

  Future<Partita> concludi() async {
    final partita = await _repo.concludi(arg);
    state = AsyncValue.data(partita);
    return partita;
  }
}
