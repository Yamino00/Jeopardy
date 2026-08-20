import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/errore_api.dart';
import 'package:frontend/core/design/design.dart';
import 'package:frontend/core/storage/cache_tabelloni.dart';
import 'package:frontend/core/storage/client_id_storage.dart';
import 'package:frontend/core/widgets/stato_errore.dart';
import 'package:frontend/data/tabellone_repository.dart';
import 'package:frontend/models/evento.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un adattatore che risponde quello che gli si dice, senza rete.
class _AdattatoreFinto implements HttpClientAdapter {
  _AdattatoreFinto(this.rispondi);

  final Future<ResponseBody> Function(RequestOptions options) rispondi;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      rispondi(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> corpo, {int stato = 200}) =>
    ResponseBody.fromString(
      jsonEncode(corpo),
      stato,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

const _tabelloneJson = {
  'codice_pubblico': 'KDSYMS',
  'titolo': 'Storia romana',
  'righe': 2,
  'punti_base': 100,
  'categorie': [
    {
      'id': 1,
      'nome_display': 'Storia',
      'posizione': 1,
      'celle': [
        {
          'id': 10,
          'riga': 1,
          'valore': 100,
          'daily_double': false,
          'testo': 'Chi fondò Roma?',
          'risposta': 'Romolo',
        },
      ],
    },
  ],
};

DioException _errore({int? stato, DioExceptionType? tipo, String? dettaglio}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: tipo ?? DioExceptionType.badResponse,
    response: stato == null
        ? null
        : Response(
            requestOptions: options,
            statusCode: stato,
            data: dettaglio == null ? null : {'detail': dettaglio},
          ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('gli errori si distinguono', () {
    test('la rete assente non è un 500', () {
      for (final tipo in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(ErroreApi.da(_errore(tipo: tipo)).genere, GenereErrore.rete);
      }
    });

    test('404, 409, 429 e 5xx hanno generi diversi', () {
      expect(ErroreApi.da(_errore(stato: 404)).genere, GenereErrore.nonTrovato);
      expect(ErroreApi.da(_errore(stato: 409)).genere, GenereErrore.conflitto);
      expect(ErroreApi.da(_errore(stato: 429)).genere, GenereErrore.quota);
      expect(ErroreApi.da(_errore(stato: 503)).genere, GenereErrore.server);
      expect(ErroreApi.da(_errore(stato: 400)).genere, GenereErrore.richiesta);
    });

    test('ognuno ha un titolo e un rimedio, e nessuno è il testo del server',
        () {
      for (final genere in GenereErrore.values) {
        final e = ErroreApi(genere: genere, messaggio: 'dettaglio tecnico');
        expect(e.titolo, isNotEmpty);
        expect(e.rimedio, isNotEmpty);
      }
      // Su rete e quota il rimedio e' scritto per l'utente, non ripetuto dal
      // server: era il difetto dei cinque Text('$e').
      expect(
        const ErroreApi(genere: GenereErrore.rete, messaggio: 'x').rimedio,
        isNot('x'),
      );
    });

    test('riprovare si offre solo dove ha senso', () {
      bool riprova(GenereErrore g) =>
          ErroreApi(genere: g, messaggio: '').vaLaPenaRiprovare;
      expect(riprova(GenereErrore.rete), isTrue);
      expect(riprova(GenereErrore.server), isTrue);
      expect(riprova(GenereErrore.nonTrovato), isFalse,
          reason: 'riprovare un 404 darebbe lo stesso esito');
      expect(riprova(GenereErrore.quota), isFalse);
    });
  });

  group('il 409 dell\'annulla non è un errore', () {
    test('annullare a inizio partita è una condizione attesa', () {
      // D9: e' la normalita' di inizio partita, e arrivava all'utente come
      // uno snackbar d'errore col testo del server.
      final e = ErroreApi.da(
        _errore(stato: 409, dettaglio: 'Nessun evento da annullare'),
      );
      expect(e.genere, GenereErrore.conflitto);
      expect(e.atteso, isTrue);
    });

    test('un altro 409 resta un conflitto vero', () {
      final e = ErroreApi.da(
        _errore(
          stato: 409,
          dettaglio: 'Nessuna domanda alternativa disponibile',
        ),
      );
      expect(e.atteso, isFalse);
    });

    testWidgets('la condizione attesa si racconta senza allarmare',
        (tester) async {
      final barra = barraErrore(ErroreApi.da(
        _errore(stato: 409, dettaglio: 'Nessun evento da annullare'),
      ));
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Builder(builder: (_) => barra.content))),
      );
      // Niente "Non si può fare adesso · ...": solo il fatto.
      expect(find.text('Nessun evento da annullare'), findsOneWidget);
    });
  });

  group('l\'annulla dice cosa ha annullato', () {
    test('con la squadra nota, racconta squadra e punti', () {
      const evento = EventoPartita(
        id: 7,
        tipo: TipoEvento.cellaGiocata,
        annullato: true,
        squadraId: 3,
        deltaPunti: 300,
      );
      expect(evento.descrizione('Rossi'), 'Rossi +300');
    });

    test('una sottrazione porta il segno giusto', () {
      const evento = EventoPartita(
        id: 8,
        tipo: TipoEvento.cellaGiocata,
        annullato: true,
        squadraId: 3,
        deltaPunti: -200,
      );
      expect(evento.descrizione('Blu'), 'Blu −200');
    });

    test('senza squadra non si inventa niente', () {
      const evento = EventoPartita(
        id: 9,
        tipo: TipoEvento.cellaGiocata,
        annullato: true,
        deltaPunti: 0,
      );
      expect(evento.descrizione(null), 'ultima azione');
    });

    test('si legge dal JSON che il backend manda da sempre', () {
      final evento = EventoPartita.fromJson(const {
        'id': 12,
        'tipo': 'cella_giocata',
        'squadra_id': 2,
        'delta_punti': 100,
        'annullato': true,
      });
      expect(evento.id, 12);
      expect(evento.tipo, TipoEvento.cellaGiocata);
      expect(evento.squadraId, 2);
      expect(evento.deltaPunti, 100);
      expect(evento.annullato, isTrue);
    });
  });

  group('con la rete staccata il tabellone resta visibile', () {
    late CacheTabelloni cache;

    TabelloneRepository conAdattatore(
      Future<ResponseBody> Function(RequestOptions) rispondi,
    ) {
      final api = ApiClient(clientIdStorage: ClientIdStorage());
      api.dio.httpClientAdapter = _AdattatoreFinto(rispondi);
      return TabelloneRepository(api, cache);
    }

    setUp(() => cache = CacheTabelloni());

    test('la prima lettura riempie la cache', () async {
      final repo = conAdattatore((_) async => _json(_tabelloneJson));
      final t = await repo.byCodice('KDSYMS');
      expect(t.titolo, 'Storia romana');
      expect(await cache.leggi('KDSYMS'), isNotNull);
      expect(await repo.cacheSalvataIl('KDSYMS'), isNotNull);
    });

    test('caduta la rete, si serve la copia locale', () async {
      await conAdattatore((_) async => _json(_tabelloneJson))
          .byCodice('KDSYMS');

      final offline = conAdattatore((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      final t = await offline.byCodice('KDSYMS');
      expect(t.titolo, 'Storia romana',
          reason: 'perdere il tabellone a meta partita e il guasto peggiore');
      expect(t.categorie.first.celle.first.testo, 'Chi fondò Roma?');
    });

    test('senza copia locale, la rete assente resta un errore', () async {
      final offline = conAdattatore((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      await expectLater(
        offline.byCodice('MAIVISTO'),
        throwsA(isA<ErroreApi>()
            .having((e) => e.genere, 'genere', GenereErrore.rete)),
      );
    });

    test('un 404 non serve la copia vecchia', () async {
      await conAdattatore((_) async => _json(_tabelloneJson))
          .byCodice('KDSYMS');

      final sparito = conAdattatore(
        (_) async => _json({'detail': 'Tabellone non trovato'}, stato: 404),
      );
      // Se il tabellone non esiste piu', mostrarne una copia vecchia sarebbe
      // peggio che dire la verita'.
      await expectLater(
        sparito.byCodice('KDSYMS'),
        throwsA(isA<ErroreApi>()
            .having((e) => e.genere, 'genere', GenereErrore.nonTrovato)),
      );
    });

    test('un dato illeggibile si comporta come un dato assente', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.tabellone_KDSYMS': 'non e json',
      });
      expect(await CacheTabelloni().leggi('KDSYMS'), isNull);
    });
  });

  group('come si mostra un errore', () {
    Future<void> monta(WidgetTester tester, ErroreApi e,
        {VoidCallback? onRiprova}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.scuro,
          home: Scaffold(
            body: StatoErrore(
              errore: e,
              onRiprova: onRiprova ?? () {},
              onIndietro: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('mostra titolo e rimedio, non il messaggio del server',
        (tester) async {
      await monta(
        tester,
        const ErroreApi(
          genere: GenereErrore.rete,
          messaggio: 'SocketException: Connection refused',
        ),
      );
      expect(find.text('Nessuna connessione'), findsOneWidget);
      expect(find.textContaining('Controlla il wifi'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
    });

    testWidgets('riprova compare sulla rete', (tester) async {
      await monta(tester,
          const ErroreApi(genere: GenereErrore.rete, messaggio: ''));
      expect(find.byKey(const Key('riprova')), findsOneWidget);
    });

    testWidgets('riprova non compare su un 404', (tester) async {
      await monta(tester,
          const ErroreApi(genere: GenereErrore.nonTrovato, messaggio: ''));
      expect(find.byKey(const Key('riprova')), findsNothing);
      // Ma una via d'uscita c'e' sempre: prima un errore sul tabellone era un
      // vicolo cieco da cui si usciva solo col tasto di sistema.
      expect(find.byKey(const Key('errore-indietro')), findsOneWidget);
    });

    testWidgets('anche un errore non tipizzato viene mostrato con dignità',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.scuro,
          home: const Scaffold(
            body: StatoErrore(errore: 'qualcosa è esploso'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Il server ha un problema'), findsOneWidget);
    });
  });
}
