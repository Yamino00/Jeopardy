import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/storage/client_id_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/api/errore_api.dart';
import '../core/storage/cache_tabelloni.dart';
import '../core/storage/coda_azioni.dart';
import '../core/storage/codici_modifica_storage.dart';
import '../models/azione_locale.dart';
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

final codaAzioniProvider = Provider<CodaAzioni>((ref) => CodaAzioni());

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

/// Le giocate che l'host ha fatto e che non sono ancora arrivate al server.
///
/// È visibile alla UI di proposito: l'host deve sapere che cosa non è ancora
/// stato salvato, invece di scoprirlo alla fine della partita.
final azioniInAttesaProvider = NotifierProvider.family<AzioniInAttesaNotifier,
    List<AzioneLocale>, int>(AzioniInAttesaNotifier.new);

class AzioniInAttesaNotifier extends FamilyNotifier<List<AzioneLocale>, int> {
  @override
  List<AzioneLocale> build(int arg) {
    // Caricamento asincrono dallo storage: parte vuota e si popola.
    ref.read(codaAzioniProvider).leggi(arg).then((salvate) {
      if (salvate.isNotEmpty) state = salvate;
    });
    return const [];
  }

  Future<void> _persisti() =>
      ref.read(codaAzioniProvider).scrivi(arg, state);

  Future<void> accoda(AzioneLocale azione) async {
    state = [...state, azione];
    await _persisti();
  }

  /// Toglie l'ultima azione accodata, che è quello che fa l'annulla offline.
  Future<AzioneLocale?> togliUltima() async {
    if (state.isEmpty) return null;
    final ultima = state.last;
    state = state.sublist(0, state.length - 1);
    await _persisti();
    return ultima;
  }

  Future<void> confermata(String idLocale) async {
    state = [for (final a in state) if (a.idLocale != idLocale) a];
    await _persisti();
  }

  Future<void> svuota() async {
    state = const [];
    await _persisti();
  }
}

/// **Quello che l'host deve vedere**: la verità del server più le giocate che
/// non ci sono ancora arrivate.
///
/// Tenere separati i due provider è ciò che permette al tabellone di reagire al
/// tocco anche senza rete senza mai far ripartire una richiesta che non può
/// riuscire. Il notifier resta la verità; questo è la proiezione.
final partitaVisualizzataProvider =
    Provider.family<AsyncValue<Partita>, int>((ref, partitaId) {
  final dalServer = ref.watch(partitaProvider(partitaId));
  final inAttesa = ref.watch(azioniInAttesaProvider(partitaId));
  return dalServer.whenData((p) => proietta(p, inAttesa));
});

class PartitaNotifier extends FamilyAsyncNotifier<Partita, int> {
  /// **La verità del server, e solo quella.**
  ///
  /// Non guarda la coda di proposito: se ne dipendesse, ogni giocata accodata
  /// mentre si è offline farebbe ripartire una richiesta di rete che non può
  /// riuscire. Quello che l'host vede è [partitaVisualizzataProvider], che
  /// mette insieme questo e la coda.
  @override
  Future<Partita> build(int arg) {
    return ref.watch(partitaRepositoryProvider).byId(arg);
  }

  PartitaRepository get _repo => ref.read(partitaRepositoryProvider);

  AzioniInAttesaNotifier get _coda =>
      ref.read(azioniInAttesaProvider(arg).notifier);

  List<AzioneLocale> get _inAttesa => ref.read(azioniInAttesaProvider(arg));



  /// E7: una guardia contro il doppio invio. Due tocchi nello stesso frame,
  /// prima che il rebuild nasconda il pulsante, mandavano due POST.
  bool _inCorso = false;

  /// Vero da quando una richiesta è fallita per la rete.
  ///
  /// Serve a **non ritentare a ogni tocco**: con un timeout di connessione di
  /// dieci secondi, riprovare a ogni giocata bloccherebbe il tabellone per
  /// dieci secondi alla volta proprio mentre il gruppo sta giocando. Una volta
  /// saputo che la rete non c'è, le giocate vanno in coda subito e si ritenta
  /// solo quando l'host lo chiede.
  bool _offline = false;

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

  /// Gioca una cella.
  ///
  /// Restituisce l'evento quando il server lo conferma, e `null` quando
  /// l'azione è stata **accodata** perché la rete non c'era: in quel caso il
  /// tabellone si aggiorna lo stesso, e l'host vede quante azioni sono in
  /// attesa.
  Future<EventoPartita?> giocaCella({
    required int cellaId,
    required String esito,
    required int deltaPunti,
    int? squadraId,
  }) async {
    final azione = AzioneLocale(
      idLocale: const Uuid().v4(),
      cellaId: cellaId,
      esito: esito,
      deltaPunti: deltaPunti,
      squadraId: squadraId,
      quando: DateTime.now(),
    );

    // Regola d'ordine, ed è la parte che rende sicuro il replay: se c'è già
    // qualcosa in coda, questa azione **non scavalca**. Va in fondo, e la coda
    // si svuota dall'inizio quando si riconcilia. Mandare questa per prima
    // significherebbe consegnare al server una sequenza diversa da quella che
    // l'host ha compiuto, e con essa punteggi diversi.
    if (_offline || _inAttesa.isNotEmpty) {
      await _coda.accoda(azione);
      return null;
    }

    try {
      final evento = await _muta(() async {
        final e = await _repo.giocaCella(
          partitaId: arg,
          cellaId: cellaId,
          esito: esito,
          deltaPunti: deltaPunti,
          squadraId: squadraId,
        );
        // Una nuova azione rende stantia la conferma dell'annulla precedente.
        ref.read(ultimoAnnullatoProvider(arg).notifier).dimentica();
        return e;
      });
      return evento;
    } on ErroreApi catch (e) {
      // Solo la rete si accoda. Un 409 o un 400 sono rifiuti veri del server:
      // rigiocarli darebbe lo stesso rifiuto, e nasconderli sarebbe peggio.
      if (e.genere != GenereErrore.rete) rethrow;
      _offline = true;
      await _coda.accoda(azione);
      return null;
    }
  }

  /// Riporta al server le azioni in attesa, **nell'ordine in cui sono state
  /// compiute**, fermandosi al primo fallimento.
  ///
  /// Fermarsi è essenziale: saltare un'azione che non passa e mandare la
  /// successiva consegnerebbe una sequenza diversa da quella reale.
  Future<void> riconcilia() async {
    if (_inAttesa.isEmpty || _inCorso) return;
    _inCorso = true;
    _offline = false;
    try {
      for (final azione in [..._inAttesa]) {
        try {
          await _repo.giocaCella(
            partitaId: arg,
            cellaId: azione.cellaId,
            esito: azione.esito,
            deltaPunti: azione.deltaPunti,
            squadraId: azione.squadraId,
          );
          await _coda.confermata(azione.idLocale);
        } on ErroreApi catch (e) {
          if (e.genere == GenereErrore.rete) {
            _offline = true;
            return; // il resto della coda resta, in ordine
          }
          // Il server ha rifiutato nel merito: tenerla in coda per sempre
          // sarebbe un blocco permanente. Si scarta e si prosegue.
          await _coda.confermata(azione.idLocale);
        }
      }
      state = await AsyncValue.guard(() => _repo.byId(arg));
    } finally {
      _inCorso = false;
    }
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
  ///
  /// Se ci sono azioni in attesa, annulla **quelle**: sono giocate che il
  /// server non ha mai visto, quindi togliere l'ultima dalla coda le cancella
  /// senza che nessuno debba saperlo.
  ///
  /// Se invece la coda è vuota, l'annulla va al server — e **richiede la
  /// rete**. È un limite scelto, non una dimenticanza: `annulla` lato backend
  /// colpisce "l'evento più recente non annullato", e non esiste un endpoint
  /// per leggere il registro. Accodare un annulla alla cieca significherebbe
  /// rischiare di cancellare la mossa di un altro dispositivo — esattamente il
  /// guasto che questa app esiste per evitare. Meglio dire che non si può.
  Future<EventoPartita?> annulla() async {
    final locale = await _coda.togliUltima();
    if (locale != null) return null;
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
