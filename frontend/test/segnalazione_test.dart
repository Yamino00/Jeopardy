import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/design/design.dart';
import 'package:frontend/data/segnalazione_repository.dart';
import 'package:frontend/features/partita/dialog_segnalazione.dart';
import 'package:frontend/features/partita/placca_domanda.dart';
import 'package:frontend/models/tabellone.dart';

const _squadre = <SquadraInPlacca>[
  (id: 1, nome: 'I Centurioni', colore: SmaltiSquadra.vermiglio),
];

Future<void> _montaPlacca(
  WidgetTester tester, {
  VoidCallback? onSegnala,
  bool giaSegnalata = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: Tema.scuro,
      home: Scaffold(
        body: PlaccaDomanda(
          nomeCategoria: 'Storia romana',
          valore: 300,
          domanda: 'Chi fu il primo imperatore romano?',
          risposta: 'Augusto',
          rispostaVisibile: false,
          squadre: _squadre,
          inviando: false,
          onChiudi: () {},
          onMostraRisposta: () {},
          onAssegna: (_, __) {},
          onPassa: () {},
          onSegnala: onSegnala,
          giaSegnalata: giaSegnalata,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _apriDialog(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: Tema.scuro,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<Object?>(
              context: context,
              builder: (_) => const DialogSegnalazione(
                nomeCategoria: 'Storia romana',
                valore: 300,
              ),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
}

void main() {
  group('la cella sa se e segnalabile', () {
    Cella cella({int? domandaId, String? testo, String? risposta}) =>
        Cella.fromJson({
          'id': 10,
          'domanda_id': domandaId,
          'riga': 1,
          'valore': 100,
          'daily_double': false,
          'testo': testo,
          'risposta': risposta,
        });

    test('legge domanda_id dal JSON del backend', () {
      expect(
        cella(domandaId: 42, testo: 'Chi?', risposta: 'Augusto').domandaId,
        42,
      );
    });

    test('una domanda vera e segnalabile', () {
      expect(
        cella(domandaId: 42, testo: 'Chi?', risposta: 'Augusto').segnalabile,
        isTrue,
      );
    });

    test('un segnaposto no: non c e niente da segnalare', () {
      // Il backend scrive un testo segnaposto e risposta vuota quando la
      // deduplicazione non lascia abbastanza domande, e non manda un id.
      expect(
        cella(testo: 'Domanda da completare', risposta: '').segnalabile,
        isFalse,
      );
    });

    test('una cella riscritta a mano no', () {
      // Il backend tace il domanda_id quando c e un override: chi gioca legge
      // il testo dell host, non quello della banca.
      expect(cella(testo: 'Testo mio?', risposta: 'Roma').segnalabile, isFalse);
    });

    test('un tabellone in cache salvato prima del campo non esplode', () {
      final vecchio = Cella.fromJson({
        'id': 10,
        'riga': 1,
        'valore': 100,
        'daily_double': false,
        'testo': 'Chi?',
        'risposta': 'Augusto',
      });
      expect(vecchio.domandaId, isNull);
      expect(vecchio.segnalabile, isFalse);
    });
  });

  group('il pulsante nella placca', () {
    testWidgets('c e, ed e raggiungibile mentre si legge la domanda',
        (tester) async {
      var segnalata = false;
      await _montaPlacca(tester, onSegnala: () => segnalata = true);

      final pulsante = find.byKey(const Key('segnala-domanda'));
      expect(pulsante, findsOneWidget);

      // Prima della rivelazione: il momento in cui l host legge la domanda ad
      // alta voce e si accorge che e sbagliata.
      expect(find.byKey(const Key('mostra-risposta')), findsOneWidget);

      await tester.tap(pulsante);
      await tester.pumpAndSettle();
      expect(segnalata, isTrue);
    });

    testWidgets('non c e quando non c e una domanda condivisa dietro',
        (tester) async {
      await _montaPlacca(tester);
      expect(find.byKey(const Key('segnala-domanda')), findsNothing);
    });

    testWidgets('e spento, non sparito, dopo che l hai premuto', (tester) async {
      var tocchi = 0;
      await _montaPlacca(
        tester,
        onSegnala: () => tocchi++,
        giaSegnalata: true,
      );

      final pulsante = find.byKey(const Key('segnala-domanda'));
      expect(pulsante, findsOneWidget);
      await tester.tap(pulsante);
      await tester.pumpAndSettle();
      expect(tocchi, 0);
    });

    testWidgets('ha una etichetta semantica sensata', (tester) async {
      final handle = tester.ensureSemantics();
      await _montaPlacca(tester, onSegnala: () {});
      expect(
        find.bySemanticsLabel('Segnala un errore in questa domanda'),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('il dialog', () {
    testWidgets('non si invia senza un motivo', (tester) async {
      await _apriDialog(tester);

      final invia = tester.widget<FilledButton>(
        find.byKey(const Key('invia-segnalazione')),
      );
      expect(invia.onPressed, isNull);
    });

    testWidgets('scelto il motivo, si puo inviare', (tester) async {
      await _apriDialog(tester);

      await tester.tap(find.byKey(const Key('motivo-errata')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('nota-segnalazione')),
        'Augusto, non Cesare',
      );
      await tester.pumpAndSettle();

      final invia = tester.widget<FilledButton>(
        find.byKey(const Key('invia-segnalazione')),
      );
      expect(invia.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('invia-segnalazione')));
      await tester.pumpAndSettle();

      // Il dialog si e chiuso avendo raccolto entrambi i dati.
      expect(find.byKey(const Key('invia-segnalazione')), findsNothing);
    });

    testWidgets('offre tutti e quattro i motivi del backend', (tester) async {
      await _apriDialog(tester);
      for (final motivo in MotivoSegnalazione.values) {
        expect(find.byKey(Key('motivo-${motivo.valore}')), findsOneWidget);
      }
    });

    testWidgets('regge textScaler 2.0 senza overflow', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: DialogSegnalazione(
              nomeCategoria: 'Storia romana',
              valore: 300,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('l esito racconta tre cose diverse', () {
    test('quante ne mancano alla disattivazione', () {
      const esito = EsitoSegnalazione(
        segnalazioniTotali: 1,
        soglia: 3,
        disattivata: false,
        giaSegnalata: false,
      );
      expect(esito.mancanti, 2);
    });

    test('disattivata: non ne mancano', () {
      const esito = EsitoSegnalazione(
        segnalazioniTotali: 3,
        soglia: 3,
        disattivata: true,
        giaSegnalata: false,
      );
      expect(esito.mancanti, 0);
    });

    test('mai un numero negativo, qualunque cosa dica il server', () {
      const esito = EsitoSegnalazione(
        segnalazioniTotali: 9,
        soglia: 3,
        disattivata: false,
        giaSegnalata: false,
      );
      expect(esito.mancanti, 0);
    });

    test('parsa la risposta snake_case del backend', () {
      final esito = EsitoSegnalazione.fromJson(const {
        'id': 7,
        'domanda_id': 42,
        'motivo': 'errata',
        'segnalazioni_totali': 3,
        'soglia': 3,
        'disattivata': true,
        'gia_segnalata': false,
        'stato_domanda': 'segnalata',
      });
      expect(esito.segnalazioniTotali, 3);
      expect(esito.disattivata, isTrue);
      expect(esito.giaSegnalata, isFalse);
    });
  });
}
