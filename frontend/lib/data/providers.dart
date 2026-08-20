import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/storage/client_id_storage.dart';
import '../core/storage/cache_tabelloni.dart';
import '../core/storage/codici_modifica_storage.dart';
import '../models/evento.dart';
import '../models/partita.dart';
import '../models/tabellone.dart';
import 'partita_repository.dart';
import 'tabellone_repository.dart';

final clientIdStorageProvider = Provider<ClientIdStorage>(
  (ref) => ClientIdStorage(),
);

final codiciModificaStorageProvider = Provider<CodiciModificaStorage>(
  (ref) => CodiciModificaStorage(),
);

/// Il codice di modifica salvato per un tabellone, se questo dispositivo lo ha
/// creato. Nullo altrimenti — ed è quel nullo che decide se la placca offre le
/// azioni di riparazione.
final codiceModificaProvider =
    FutureProvider.family<String?, String>((ref, codicePubblico) {
  return ref
      .watch(codiciModificaStorageProvider)
      .perTabellone(codicePubblico);
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(clientIdStorage: ref.watch(clientIdStorageProvider)),
);

final cacheTabelloniProvider = Provider<CacheTabelloni>(
  (ref) => CacheTabelloni(),
);

final tabelloneRepositoryProvider = Provider<TabelloneRepository>(
  (ref) => TabelloneRepository(
    ref.watch(apiClientProvider),
    ref.watch(cacheTabelloniProvider),
  ),
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

/// Lo stato della partita in corso.
///
/// Il backend resta la sorgente di verità: dopo ogni azione lo stato si rilegge
/// da lì, così il punteggio riflette sempre il registro degli eventi.
final partitaProvider =
    AsyncNotifierProvider.family<PartitaNotifier, Partita, int>(
  PartitaNotifier.new,
);

/// L'ultimo evento annullato, per la partita indicata.
///
/// Esiste perché il backend restituisce l'evento annullato e prima lo
/// scartavamo (D4): senza questo, l'annulla non può dire *cosa* ha annullato.
final ultimoAnnullatoProvider =
    NotifierProvider.family<UltimoAnnullatoNotifier, EventoPartita?, int>(
  UltimoAnnullatoNotifier.new,
);

class UltimoAnnullatoNotifier extends FamilyNotifier<EventoPartita?, int> {
  @override
  EventoPartita? build(int arg) => null;

  void registra(EventoPartita evento) => state = evento;
  void dimentica() => state = null;
}

class PartitaNotifier extends FamilyAsyncNotifier<Partita, int> {
  @override
  Future<Partita> build(int arg) {
    return ref.watch(partitaRepositoryProvider).byId(arg);
  }

  PartitaRepository get _repo => ref.read(partitaRepositoryProvider);

  /// E7: una guardia contro il doppio invio. Due tocchi nello stesso frame,
  /// prima che il rebuild nasconda il pulsante, mandavano due POST.
  bool _inCorso = false;

  /// Esegue [azione] e poi rilegge lo stato.
  ///
  /// S4: prima era `state = AsyncValue.data(await ...)` senza guardia. Se la
  /// mutazione riusciva ma la rilettura falliva, l'eccezione risaliva al
  /// chiamante e **lo stato restava quello vecchio**: il tabellone continuava a
  /// mostrare il punteggio di prima. Un desync silenzioso, che in partita
  /// significa punti sbagliati sullo schermo.
  Future<T> _muta<T>(Future<T> Function() azione) async {
    if (_inCorso) {
      throw StateError('Azione già in corso');
    }
    _inCorso = true;
    try {
      final risultato = await azione();
      state = await AsyncValue.guard(() => _repo.byId(arg));
      return risultato;
    } finally {
      _inCorso = false;
    }
  }

  Future<EventoPartita> giocaCella({
    required int cellaId,
    required String esito,
    required int deltaPunti,
    int? squadraId,
  }) {
    return _muta(() async {
      final evento = await _repo.giocaCella(
        partitaId: arg,
        cellaId: cellaId,
        esito: esito,
        deltaPunti: deltaPunti,
        squadraId: squadraId,
      );
      // Una nuova azione rende stantia la conferma dell'annulla precedente.
      ref.read(ultimoAnnullatoProvider(arg).notifier).dimentica();
      return evento;
    });
  }

  Future<void> aggiungiSquadra(String nome, {String? colore}) {
    return _muta(() => _repo.aggiungiSquadra(arg, nome, colore: colore));
  }

  Future<void> aggiornaSquadra(int squadraId,
      {String? nome, String? colore, int? punteggio}) {
    return _muta(() => _repo.aggiornaSquadra(arg, squadraId,
        nome: nome, colore: colore, punteggio: punteggio));
  }

  Future<void> rimuoviSquadra(int squadraId) {
    return _muta(() => _repo.rimuoviSquadra(arg, squadraId));
  }

  /// Annulla l'ultima azione e **ricorda quale**, così la UI può dirlo.
  Future<EventoPartita> annulla() {
    return _muta(() async {
      final evento = await _repo.annulla(arg);
      ref.read(ultimoAnnullatoProvider(arg).notifier).registra(evento);
      return evento;
    });
  }

  Future<Partita> concludi() async {
    final partita = await _repo.concludi(arg);
    state = AsyncValue.data(partita);
    return partita;
  }
}
