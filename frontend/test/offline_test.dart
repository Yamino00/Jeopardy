import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/errore_api.dart';
import 'package:frontend/core/storage/coda_azioni.dart';
import 'package:frontend/data/partita_repository.dart';
import 'package:frontend/data/providers.dart';
import 'package:frontend/core/widgets/punteggio_palette.dart';
import 'package:frontend/features/partita/azioni_in_attesa.dart';
import 'package:frontend/features/partita/partita_page.dart';
import 'package:frontend/models/evento.dart';
import 'package:frontend/models/tabellone.dart';
import 'package:frontend/models/azione_locale.dart';
import 'package:frontend/models/partita.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _partita = Partita(
  id: 1,
  codiceTabellone: 'KDSYMS',
  stato: 'in_corso',
  squadre: [
    Squadra(id: 1, nome: 'Rossi', punteggio: 300, posizione: 1, attiva: true),
    Squadra(id: 2, nome: 'Blu', punteggio: 100, posizione: 2, attiva: true),
  ],
  celleGiocate: [CellaGiocata(cellaId: 10)],
);

AzioneLocale _azione({
  required String id,
  required int cella,
  required int delta,
  int? squadra = 1,
}) =>
    AzioneLocale(
      idLocale: id,
      cellaId: cella,
      esito: delta >= 0 ? 'corretta' : 'errata',
      deltaPunti: delta,
      squadraId: squadra,
      quando: DateTime(2026, 8, 20),
    );

int _punti(Partita p, int squadraId) =>
    p.squadre.firstWhere((s) => s.id == squadraId).punteggio;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('la proiezione mostra quello che l\'host ha appena fatto', () {
    test('senza azioni in attesa lo stato è quello del server', () {
      expect(proietta(_partita, const []), same(_partita));
    });

    test('una giocata accodata segna la cella e sposta il punteggio', () {
      // Senza questo, offline l'host tocca una cella e non succede niente: in
      // salotto sembra rotta l'app, non la rete.
      final p = proietta(_partita, [_azione(id: 'a', cella: 11, delta: 200)]);
      expect(p.cellaGiaGiocata(11), isTrue);
      expect(_punti(p, 1), 500);
      expect(_punti(p, 2), 100, reason: 'le altre squadre non si toccano');
    });

    test('più azioni si sommano nell\'ordine in cui sono state fatte', () {
      final p = proietta(_partita, [
        _azione(id: 'a', cella: 11, delta: 200),
        _azione(id: 'b', cella: 12, delta: -100),
        _azione(id: 'c', cella: 13, delta: 300, squadra: 2),
      ]);
      expect(_punti(p, 1), 400);
      expect(_punti(p, 2), 400);
      expect(p.celleGiocate.length, 4);
    });

    test('una cella passata non assegna punti a nessuno', () {
      final p = proietta(_partita, [
        AzioneLocale(
          idLocale: 'p',
          cellaId: 14,
          esito: 'passata',
          deltaPunti: 0,
          quando: DateTime(2026, 8, 20),
        ),
      ]);
      expect(p.cellaGiaGiocata(14), isTrue);
      expect(_punti(p, 1), 300);
    });

    test('non duplica una cella che il server ha già registrato', () {
      // Puo' succedere se l'invio e' andato a buon fine ma la risposta si e'
      // persa: l'azione resta in coda e verra' rigiocata.
      final p = proietta(_partita, [_azione(id: 'a', cella: 10, delta: 100)]);
      expect(p.celleGiocate.where((c) => c.cellaId == 10).length, 1);
    });

    test('non inventa squadre che non esistono più', () {
      final p =
          proietta(_partita, [_azione(id: 'a', cella: 11, delta: 100, squadra: 99)]);
      expect(p.squadre.length, 2);
      expect(_punti(p, 1), 300);
    });

    test('non modifica lo stato del server che riceve', () {
      proietta(_partita, [_azione(id: 'a', cella: 11, delta: 200)]);
      expect(_punti(_partita, 1), 300, reason: 'la proiezione non muta la base');
      expect(_partita.celleGiocate.length, 1);
    });
  });

  group('la coda sopravvive alla chiusura dell\'app', () {
    test('quello che si scrive si rilegge', () async {
      final coda = CodaAzioni();
      await coda.scrivi(1, [
        _azione(id: 'a', cella: 11, delta: 200),
        _azione(id: 'b', cella: 12, delta: -100),
      ]);

      // Una nuova istanza: è la stessa cosa che succede riaprendo l'app.
      final riletta = await CodaAzioni().leggi(1);
      expect(riletta.length, 2);
      expect(riletta.first.idLocale, 'a');
      expect(riletta.first.cellaId, 11);
      expect(riletta.last.deltaPunti, -100);
    });

    test('l\'ordine è quello in cui le azioni sono state compiute', () async {
      final coda = CodaAzioni();
      final ordine = ['a', 'b', 'c', 'd'];
      await coda.scrivi(1, [
        for (var i = 0; i < ordine.length; i++)
          _azione(id: ordine[i], cella: 20 + i, delta: 100),
      ]);
      final riletta = await coda.leggi(1);
      expect(riletta.map((a) => a.idLocale).toList(), ordine,
          reason: 'rigiocare fuori ordine darebbe punteggi diversi');
    });

    test('partite diverse hanno code diverse', () async {
      final coda = CodaAzioni();
      await coda.scrivi(1, [_azione(id: 'a', cella: 11, delta: 100)]);
      await coda.scrivi(2, [
        _azione(id: 'x', cella: 21, delta: 200),
        _azione(id: 'y', cella: 22, delta: 300),
      ]);
      expect((await coda.leggi(1)).length, 1);
      expect((await coda.leggi(2)).length, 2);
    });

    test('svuotare cancella davvero', () async {
      final coda = CodaAzioni();
      await coda.scrivi(1, [_azione(id: 'a', cella: 11, delta: 100)]);
      await coda.svuota(1);
      expect(await coda.leggi(1), isEmpty);
    });

    test('una coda corrotta si butta invece di falsare i punteggi', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.coda_azioni_1': 'non e json',
      });
      expect(await CodaAzioni().leggi(1), isEmpty);
      // E si e' anche ripulita, cosi' non riprova a ogni avvio.
      expect(await CodaAzioni().leggi(1), isEmpty);
    });

    test('il giro completo JSON non perde niente', () {
      final originale = _azione(id: 'a', cella: 11, delta: -250, squadra: 7);
      final copia = AzioneLocale.fromJson(originale.toJson());
      expect(copia.idLocale, originale.idLocale);
      expect(copia.cellaId, originale.cellaId);
      expect(copia.esito, originale.esito);
      expect(copia.deltaPunti, originale.deltaPunti);
      expect(copia.squadraId, originale.squadraId);
      expect(copia.quando, originale.quando);
    });
  });

  group('la riconciliazione converge', () {
    test('rigiocare in ordine dà lo stesso stato della proiezione', () {
      // È l'invariante su cui poggia tutto il disegno: il backend calcola il
      // punteggio come somma dei delta degli eventi non annullati, quindi se le
      // azioni gli arrivano nella sequenza in cui l'host le ha compiute, lo
      // stato converge senza nessuna regola di conflitto.
      final azioni = [
        _azione(id: 'a', cella: 11, delta: 200),
        _azione(id: 'b', cella: 12, delta: -100),
        _azione(id: 'c', cella: 13, delta: 300, squadra: 2),
      ];

      final proiettato = proietta(_partita, azioni);

      // Il server applica una azione alla volta: si simula lo stesso.
      var dalServer = _partita;
      for (final azione in azioni) {
        dalServer = proietta(dalServer, [azione]);
      }

      expect(_punti(dalServer, 1), _punti(proiettato, 1));
      expect(_punti(dalServer, 2), _punti(proiettato, 2));
      expect(dalServer.celleGiocate.length, proiettato.celleGiocate.length);
    });

    test('togliere l\'ultima azione riporta allo stato di prima', () {
      // È l'annulla offline: la giocata non è mai arrivata al server, quindi
      // toglierla dalla coda la cancella e basta.
      final azioni = [
        _azione(id: 'a', cella: 11, delta: 200),
        _azione(id: 'b', cella: 12, delta: 500),
      ];
      final conEntrambe = proietta(_partita, azioni);
      expect(_punti(conEntrambe, 1), 1000);
      expect(conEntrambe.cellaGiaGiocata(12), isTrue);

      // Si toglie l'ultima, come fa `togliUltima`.
      final dopoAnnulla =
          proietta(_partita, azioni.sublist(0, azioni.length - 1));

      expect(_punti(dopoAnnulla, 1), 500,
          reason: 'i 500 della seconda giocata devono sparire');
      expect(dopoAnnulla.cellaGiaGiocata(12), isFalse,
          reason: 'la cella torna giocabile');
      expect(dopoAnnulla.cellaGiaGiocata(11), isTrue,
          reason: 'la prima giocata resta');
    });
  });

  group('con la rete staccata le azioni si accodano', () {
    late ProviderContainer contenitore;
    late _RepoFinto repo;

    Future<EventoPartita?> gioca(int cella, int delta) =>
        contenitore.read(partitaProvider(1).notifier).giocaCella(
              cellaId: cella,
              esito: delta >= 0 ? 'corretta' : 'errata',
              deltaPunti: delta,
              squadraId: 1,
            );

    Partita mostrata() =>
        contenitore.read(partitaVisualizzataProvider(1)).requireValue;
    List<AzioneLocale> coda() => contenitore.read(azioniInAttesaProvider(1));

    setUp(() async {
      repo = _RepoFinto(_partita);
      contenitore = ProviderContainer(
        overrides: [partitaRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(contenitore.dispose);
      await contenitore.read(partitaProvider(1).future);
    });

    test('il tabellone reagisce anche senza rete', () async {
      repo.rete = false;
      final evento = await gioca(11, 200);

      expect(evento, isNull, reason: 'accodata, non confermata dal server');
      expect(coda().length, 1);
      expect(repo.ricevute, isEmpty, reason: 'il server non ha visto niente');

      // E soprattutto: quello che l'host vede e' aggiornato.
      expect(mostrata().cellaGiaGiocata(11), isTrue);
      expect(_punti(mostrata(), 1), 500);
    });

    test('tornata la rete, le giocate arrivano in ordine', () async {
      repo.rete = false;
      await gioca(11, 200);
      await gioca(12, -100);
      await gioca(13, 300);
      expect(coda().length, 3);
      expect(repo.ricevute, isEmpty);

      repo.rete = true;
      await contenitore.read(partitaProvider(1).notifier).riconcilia();

      expect(repo.ricevute, [11, 12, 13],
          reason: 'fuori ordine i punteggi sarebbero diversi');
      expect(coda(), isEmpty);
      expect(_punti(mostrata(), 1), 700);
    });

    test('una giocata nuova non scavalca quelle in attesa', () async {
      repo.rete = false;
      await gioca(11, 100);
      repo.rete = true;
      // La rete e' tornata, ma c'e' gia' qualcosa in coda: questa deve andare
      // in fondo, non partire per prima.
      await gioca(12, 100);
      await contenitore.read(partitaProvider(1).notifier).riconcilia();
      expect(repo.ricevute, [11, 12]);
    });

    test('offline, annullare toglie la giocata dalla coda', () async {
      repo.rete = false;
      await gioca(11, 200);
      await gioca(12, 500);
      expect(_punti(mostrata(), 1), 1000);

      final esito =
          await contenitore.read(partitaProvider(1).notifier).annulla();

      expect(esito, isA<AnnullataAzioneInAttesa>(),
          reason: 'non c e nessun evento del server: era solo in coda');
      expect(coda().length, 1);
      expect(_punti(mostrata(), 1), 500);
      expect(mostrata().cellaGiaGiocata(12), isFalse);
      expect(repo.ricevute, isEmpty,
          reason: 'la giocata annullata non deve mai partire');
    });

    test('un rifiuto nel merito non si accoda', () async {
      // Un 409 rigiocato darebbe lo stesso 409: accodarlo bloccherebbe la coda
      // per sempre. Solo la rete si accoda.
      repo.rifiuta = true;
      await expectLater(gioca(11, 100), throwsA(isA<ErroreApi>()));
      expect(coda(), isEmpty);
    });
  });

  group('quello che l host vede offline', () {
    late _RepoFinto repo;

    const tabellone = Tabellone(
      codicePubblico: 'KDSYMS',
      titolo: 'Prova',
      righe: 2,
      puntiBase: 100,
      categorie: [
        Categoria(
          id: 1,
          nomeDisplay: 'Storia',
          posizione: 1,
          celle: [
            Cella(id: 11, riga: 1, valore: 200, dailyDouble: false),
            Cella(id: 12, riga: 2, valore: 500, dailyDouble: false),
          ],
        ),
      ],
    );

    Future<void> monta(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);
      repo = _RepoFinto(_partita);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            partitaRepositoryProvider.overrideWithValue(repo),
            tabelloneProvider('KDSYMS').overrideWith((ref) async => tabellone),
          ],
          child: const MaterialApp(home: PartitaPage(partitaId: 1)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('il podio mostra i punti anche se il server non li ha visti',
        (tester) async {
      // La regressione da cui nasce questo test: il podio leggeva lo stato
      // grezzo del server invece della proiezione, quindi offline la griglia si
      // aggiornava e i punteggi no — e il podio contraddiceva il tabellone.
      // Il punteggio del podio e' disegnato da un CustomPainter: le cifre
      // sono pixel, non widget Text. Si guarda il valore che il widget riceve.
      int punteggioSulPodio() => tester
          .widget<PunteggioPalette>(find.byKey(const Key('punteggio-1')))
          .valore;

      await monta(tester);
      expect(punteggioSulPodio(), 300, reason: 'punteggio iniziale');

      repo.rete = false;
      final contenitore = ProviderScope.containerOf(
        tester.element(find.byType(PartitaPage)),
      );
      await contenitore.read(partitaProvider(1).notifier).giocaCella(
            cellaId: 11,
            esito: 'corretta',
            deltaPunti: 200,
            squadraId: 1,
          );
      await tester.pumpAndSettle();

      final mostrata =
          contenitore.read(partitaVisualizzataProvider(1)).requireValue;
      expect(_punti(mostrata, 1), 500, reason: 'la proiezione e giusta');
      // E il podio deve dire la stessa cosa della proiezione: era proprio qui
      // che divergeva.
      expect(punteggioSulPodio(), 500,
          reason: 'il podio mostra ancora il punteggio del server');
    });

    testWidgets('la striscia di avviso non si mangia il tabellone',
        (tester) async {
      // Un avviso che impedisce di giocare e peggio del problema che segnala:
      // la prima versione occupava un quarto dello schermo e tagliava
      // l ultima fila di tessere.
      await monta(tester);
      final contenitore = ProviderScope.containerOf(
        tester.element(find.byType(PartitaPage)),
      );
      repo.rete = false;
      await contenitore.read(partitaProvider(1).notifier).giocaCella(
            cellaId: 11,
            esito: 'corretta',
            deltaPunti: 200,
            squadraId: 1,
          );
      await tester.pumpAndSettle();

      final striscia = find.byType(StrisciaAzioniInAttesa);
      expect(striscia, findsOneWidget);
      final altezza = tester.getSize(striscia).height;
      expect(altezza, lessThan(90),
          reason: 'la striscia occupa $altezza dp: torna a rubare spazio '
              'al tabellone');
      expect(find.byKey(const Key('riprova-invio')), findsOneWidget);
    });
  });
}

/// Il ciclo completo con la rete che va e viene, dal notifier.
///
/// È il gate della fase: con la rete staccata il tabellone resta usabile e le
/// azioni si accodano; quando torna, arrivano al server **nell'ordine giusto**.
class _RepoFinto implements PartitaRepository {
  _RepoFinto(this._partita);

  Partita _partita;
  bool rete = true;
  bool rifiuta = false;

  /// Le celle arrivate al server, in ordine: è quello che si verifica.
  final List<int> ricevute = [];

  void _controllaRete() {
    if (rifiuta) {
      throw const ErroreApi(
        genere: GenereErrore.conflitto,
        messaggio: 'Cella gia giocata',
      );
    }
    if (rete) return;
    throw const ErroreApi(
      genere: GenereErrore.rete,
      messaggio: 'Il server non risponde',
    );
  }

  @override
  Future<Partita> byId(int id) async {
    _controllaRete();
    return _partita;
  }

  @override
  Future<EventoPartita> giocaCella({
    required int partitaId,
    required int cellaId,
    required String esito,
    required int deltaPunti,
    int? squadraId,
  }) async {
    _controllaRete();
    ricevute.add(cellaId);
    _partita = proietta(_partita, [
      AzioneLocale(
        idLocale: 'srv',
        cellaId: cellaId,
        esito: esito,
        deltaPunti: deltaPunti,
        squadraId: squadraId,
        quando: DateTime(2026),
      ),
    ]);
    return EventoPartita(
      id: ricevute.length,
      tipo: TipoEvento.cellaGiocata,
      annullato: false,
      squadraId: squadraId,
      deltaPunti: deltaPunti,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
