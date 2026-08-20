import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/design/design.dart';
import 'package:frontend/data/providers.dart';
import 'package:frontend/features/home/home_page.dart';
import 'package:frontend/models/tabellone.dart';

const telefonoVerticale = Size(360, 800);
const tabletOrizzontale = Size(1280, 800);

const _tabelloni = [
  TabelloneSintesi(
    codicePubblico: 'KDSYMS',
    titolo: 'Storia romana e dintorni',
    righe: 5,
    puntiBase: 100,
  ),
  TabelloneSintesi(
    codicePubblico: 'PLQZRT',
    titolo: 'Cinema',
    righe: 3,
    puntiBase: 200,
  ),
];

Future<void> _monta(
  WidgetTester tester, {
  Size schermo = telefonoVerticale,
  double scala = 1.0,
  List<TabelloneSintesi>? dati,
  Object? errore,
  bool inAttesa = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = schermo;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mieiTabelloniProvider.overrideWith((ref) {
          if (inAttesa) return Completer<List<TabelloneSintesi>>().future;
          if (errore != null) throw errore;
          return Future.value(dati ?? _tabelloni);
        }),
      ],
      child: MaterialApp(
        theme: Tema.scuro,
        home: MediaQuery(
          data: MediaQueryData(
            size: schermo,
            textScaler: TextScaler.linear(scala),
          ),
          child: const HomePage(),
        ),
      ),
    ),
  );
  // pump e non pumpAndSettle: nello stato d'attesa non si arriva mai a quiete.
  await tester.pump();
  if (!inAttesa) await tester.pump();
}

void main() {
  group('lo scaffale, nei suoi quattro stati', () {
    testWidgets('con dei tabelloni mostra una tessera per ciascuno',
        (tester) async {
      await _monta(tester);
      expect(find.text('Storia romana e dintorni'), findsOneWidget);
      expect(find.text('Cinema'), findsOneWidget);
      expect(find.text('KDSYMS · 5 righe'), findsOneWidget);
    });

    testWidgets('in attesa mostra delle tessere spente, non una rotellina',
        (tester) async {
      await _monta(tester, inAttesa: true);
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'una rotellina non dice cosa sta arrivando');
      expect(find.bySemanticsLabel('Sto caricando i tuoi tabelloni'),
          findsOneWidget);
    });

    testWidgets('vuoto, dice cosa fare invece di constatare il vuoto',
        (tester) async {
      await _monta(tester, dati: const []);
      expect(find.text('Lo scaffale è vuoto'), findsOneWidget);
      expect(find.textContaining('Crea il tuo primo tabellone'), findsOneWidget);
    });

    testWidgets('in errore offre di riprovare', (tester) async {
      await _monta(tester, errore: 'rete assente');
      // Prima era un Text('$e') e basta: un vicolo cieco.
      expect(find.byKey(const Key('riprova-tabelloni')), findsOneWidget);
      expect(find.textContaining('Non riesco a leggere i tuoi tabelloni'),
          findsOneWidget);
    });
  });

  group('si adatta allo schermo', () {
    testWidgets('su telefono il nome sta sopra il pulsante', (tester) async {
      await _monta(tester);
      final nome = tester.getRect(find.text('QUIZ GRID'));
      final crea = tester.getRect(find.byKey(const Key('crea-tabellone')));
      expect(crea.top, greaterThan(nome.bottom));
    });

    testWidgets('su tablet il nome e il pulsante stanno sulla stessa riga',
        (tester) async {
      await _monta(tester, schermo: tabletOrizzontale);
      final nome = tester.getRect(find.text('QUIZ GRID'));
      final crea = tester.getRect(find.byKey(const Key('crea-tabellone')));
      expect(crea.left, greaterThan(nome.right),
          reason: 'su schermo largo l azione sta accanto, non sotto');
    });

    testWidgets('su tablet lo scaffale sta su più colonne', (tester) async {
      await _monta(tester, schermo: tabletOrizzontale);
      final primo = tester.getRect(find.text('Storia romana e dintorni'));
      final secondo = tester.getRect(find.text('Cinema'));
      expect(secondo.left, greaterThan(primo.left),
          reason: 'la seconda tessera deve stare a fianco, non sotto');
      expect((secondo.top - primo.top).abs(), lessThan(2));
    });

    testWidgets('su tablet il contenuto non resta una striscia al centro',
        (tester) async {
      await _monta(tester, schermo: tabletOrizzontale);
      // Prima tutto viveva in una ConstrainedBox da 520 al centro di 1280.
      // Lo si verifica sulla testata, che occupa sempre tutta la riga: le
      // tessere no, perche' con due soli tabelloni riempiono due colonne su
      // quattro, ed e' il comportamento giusto di una griglia.
      final crea = tester.getRect(find.byKey(const Key('crea-tabellone')));
      expect(crea.right, greaterThan(tabletOrizzontale.width - 100),
          reason: 'la testata deve arrivare al bordo destro');
      final campo = tester.getRect(find.byKey(const Key('campo-codice')));
      expect(campo.width, greaterThan(tabletOrizzontale.width * 0.6));
    });
  });

  group('nessun overflow', () {
    for (final (nome, schermo) in [
      ('telefono', telefonoVerticale),
      ('tablet', tabletOrizzontale),
    ]) {
      for (final scala in [1.0, 1.5, 2.0]) {
        testWidgets('$nome a scala $scala', (tester) async {
          await _monta(tester, schermo: schermo, scala: scala);
          expect(tester.takeException(), isNull);
          expect(find.text('QUIZ GRID'), findsOneWidget);

          // Le tessere non si cercano dove sono adesso: a scala alta la
          // griglia non costruisce quello che sta fuori schermo, ed e' giusto
          // cosi'. Si scorre fino a una, che verifica insieme che il
          // contenuto sia raggiungibile e che scorrendo non sfondi niente.
          await tester.scrollUntilVisible(
            find.byKey(const Key('tabellone-KDSYMS')),
            200,
            // Va indicato quale: oltre alla lista c'e' lo scrollable interno
            // del campo di testo, e senza questo il test non sa chi muovere.
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(find.byKey(const Key('tabellone-KDSYMS')), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('il codice di qualcun altro', () {
    testWidgets('si scrive in maiuscolo mentre si digita', (tester) async {
      await _monta(tester);
      await tester.enterText(find.byKey(const Key('campo-codice')), 'kdsyms');
      await tester.pump();
      // Si guarda il controller e non il testo a schermo: il segnaposto del
      // campo e' anch'esso 'KDSYMS', quindi cercarlo troverebbe due cose.
      final campo =
          tester.widget<TextField>(find.byKey(const Key('campo-codice')));
      expect(campo.controller!.text, 'KDSYMS',
          reason: 'l utente deve vedere quello che verra inviato');
    });

    testWidgets('sta in fondo, non in cima', (tester) async {
      await _monta(tester);
      final campo = tester.getRect(find.byKey(const Key('campo-codice')));
      final crea = tester.getRect(find.byKey(const Key('crea-tabellone')));
      expect(campo.top, greaterThan(crea.top),
          reason: 'e l utilita, non l azione principale');
    });
  });

  testWidgets('ogni tabellone e un pulsante con una etichetta sensata',
      (tester) async {
    await _monta(tester);
    expect(
      find.bySemanticsLabel(
        'Storia romana e dintorni, 5 righe, codice KDSYMS',
      ),
      findsOneWidget,
    );
  });
}
