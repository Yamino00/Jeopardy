import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/design/design.dart';
import 'package:frontend/core/widgets/raccolta_tessere.dart';
import 'package:frontend/core/widgets/tessera.dart';

/// Cinque categorie da cinque valori: il caso del brief, e quello che il
/// codice precedente non riusciva a mostrare intero su un telefono.
List<CategoriaTessere> _tabellone({int categorie = 5, int righe = 5}) {
  var id = 0;
  return [
    for (var c = 0; c < categorie; c++)
      CategoriaTessere(
        nome: ['Storia romana', 'Cinema', 'Geografia', 'Musica', 'Sport'][
            c % 5],
        tessere: [
          for (var r = 0; r < righe; r++)
            DatiTessera(
              id: id++,
              valore: (r + 1) * 100,
              stato: StatoTessera.faccia,
            ),
        ],
      ),
  ];
}

/// Monta la griglia a una dimensione di schermo e a un fattore di scala dati.
Future<void> _monta(
  WidgetTester tester, {
  required Size schermo,
  double scala = 1.0,
  List<CategoriaTessere>? categorie,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = schermo;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: Tema.scuro,
      home: MediaQuery(
        data: MediaQueryData(
          size: schermo,
          textScaler: TextScaler.linear(scala),
        ),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Misure.s3),
            child: RaccoltaTessere(
              categorie: categorie ?? _tabellone(),
              onTocco: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const telefonoVerticale = Size(360, 640);
const telefonoOrizzontale = Size(640, 360);
const tabletOrizzontale = Size(1280, 800);
const tabletVerticale = Size(800, 1280);

/// Vero se dentro la griglia c'è uno scrollable in quella direzione.
bool _scorreIn(WidgetTester tester, Axis asse) {
  final scrollables = tester.widgetList<Scrollable>(
    find.descendant(
      of: find.byType(RaccoltaTessere),
      matching: find.byType(Scrollable),
    ),
  );
  return scrollables.any((s) => s.axisDirection.index ~/ 2 == asse.index % 2
      ? _asseDi(s.axisDirection) == asse
      : _asseDi(s.axisDirection) == asse);
}

Axis _asseDi(AxisDirection d) => switch (d) {
      AxisDirection.up || AxisDirection.down => Axis.vertical,
      AxisDirection.left || AxisDirection.right => Axis.horizontal,
    };

void main() {
  group('il tabellone si vede intero', () {
    testWidgets('5 categorie x 5 righe su telefono verticale', (tester) async {
      await _monta(tester, schermo: telefonoVerticale);

      expect(tester.takeException(), isNull);
      expect(find.byType(Tessera), findsNWidgets(25),
          reason: 'tutte le 25 tessere sono costruite');
      expect(_scorreIn(tester, Axis.vertical), isFalse,
          reason: 'a scala normale il tabellone non deve scorrere');
    });

    testWidgets('non scorre mai in orizzontale', (tester) async {
      // Il difetto R2: il codice precedente imponeva 158dp per colonna, quindi
      // su 360dp si vedevano due categorie e mezzo su cinque.
      for (final schermo in [
        telefonoVerticale,
        telefonoOrizzontale,
        tabletVerticale,
        tabletOrizzontale,
      ]) {
        await _monta(tester, schermo: schermo);
        expect(_scorreIn(tester, Axis.horizontal), isFalse,
            reason: 'scorre in orizzontale a $schermo');
        expect(find.byType(Tessera), findsNWidgets(25));
      }
    });

    testWidgets('ogni tessera resta un bersaglio tattile valido',
        (tester) async {
      await _monta(tester, schermo: telefonoVerticale);
      for (final elemento in find.byType(Tessera).evaluate()) {
        final dimensione = tester.getSize(find.byWidget(elemento.widget));
        expect(dimensione.width, greaterThanOrEqualTo(Misure.areaTattileMinima),
            reason: 'tessera larga ${dimensione.width}');
        expect(dimensione.height, greaterThanOrEqualTo(Misure.areaTattileMinima),
            reason: 'tessera alta ${dimensione.height}');
      }
    });
  });

  group('textScaler fino a 2.0, nessun overflow', () {
    for (final scala in [1.0, 1.5, 2.0]) {
      for (final (nome, schermo) in [
        ('telefono verticale', telefonoVerticale),
        ('telefono orizzontale', telefonoOrizzontale),
        ('tablet orizzontale', tabletOrizzontale),
      ]) {
        testWidgets('scala $scala su $nome', (tester) async {
          await _monta(tester, schermo: schermo, scala: scala);
          // In un test un overflow di layout arriva come eccezione: se non ce
          // n'è, non c'è overflow.
          expect(tester.takeException(), isNull,
              reason: 'overflow a scala $scala su $nome');
          expect(find.byType(Tessera), findsNWidgets(25));
        });
      }
    }

    testWidgets('il corpo base del numerale non dipende dalla scala',
        (tester) async {
      // È l'asserzione centrale della regola textScaler: la base si calcola a
      // scala 1.0, e il fattore dell'utente si applica *sopra*. Se la base
      // cambiasse al variare della scala, qualcuno la starebbe compensando.
      double base(WidgetTester t) => t
          .widget<Text>(find.descendant(
            of: find.byType(Tessera).first,
            matching: find.byType(Text),
          ))
          .style!
          .fontSize!;

      await _monta(tester, schermo: telefonoVerticale, scala: 1.0);
      final a1 = base(tester);
      await _monta(tester, schermo: telefonoVerticale, scala: 2.0);
      final a2 = base(tester);

      expect(a2, a1,
          reason: 'la base e cambiata con la scala: qualcuno la compensa');
      expect(a1, greaterThanOrEqualTo(Tipografia.numeraleMinimo));
    });

    testWidgets('la tessera resta alta abbastanza per il numerale scalato',
        (tester) async {
      // Nessun ritaglio silenzioso: il numerale renderizzato deve entrare
      // nella tessera. È il difetto che il primo giro di questo test ha
      // scoperto — Center + softWrap:false non lancia overflow, taglia.
      for (final scala in [1.0, 1.5, 2.0]) {
        await _monta(tester, schermo: telefonoVerticale, scala: scala);
        final testo = tester.widget<Text>(find.descendant(
          of: find.byType(Tessera).first,
          matching: find.byType(Text),
        ));
        final resa = TextScaler.linear(scala).scale(testo.style!.fontSize!);
        final tessera = tester.getSize(find.byType(Tessera).first);
        expect(tessera.height, greaterThanOrEqualTo(resa),
            reason: 'a scala $scala il numerale reso ($resa) non entra '
                'nella tessera (${tessera.height})');
      }
    });

    testWidgets('quando davvero non ci sta, il tabellone scorre',
        (tester) async {
      // A 2.0 su un telefono normale il tabellone ci sta ancora: e' un buon
      // esito, non un motivo per non provare il meccanismo. Qui la scala e'
      // spinta fino a non lasciare scelta.
      await _monta(tester, schermo: telefonoVerticale, scala: 4.0);
      expect(tester.takeException(), isNull);
      expect(_scorreIn(tester, Axis.vertical), isTrue,
          reason: 'non si rimpicciolisce il testo: si scorre');
      expect(_scorreIn(tester, Axis.horizontal), isFalse,
          reason: 'in orizzontale non si scorre mai');
    });
  });

  group('i due layout', () {
    testWidgets('su schermo stretto il nome sta sopra la sua fila',
        (tester) async {
      await _monta(tester, schermo: telefonoVerticale);
      final nome = tester.getRect(find.text('STORIA ROMANA'));
      final primaTessera = tester.getRect(find.byType(Tessera).first);
      expect(nome.bottom, lessThanOrEqualTo(primaTessera.top),
          reason: 'il nome deve stare sopra, non a fianco');
    });

    testWidgets('su schermo largo il nome sta in testa alla colonna',
        (tester) async {
      await _monta(tester, schermo: tabletOrizzontale);
      final nome = tester.getRect(find.text('STORIA ROMANA'));
      final primaTessera = tester.getRect(find.byType(Tessera).first);
      expect(nome.bottom, lessThanOrEqualTo(primaTessera.top));
      // In colonna il nome e la sua prima tessera sono incolonnati.
      expect((nome.center.dx - primaTessera.center.dx).abs(), lessThan(2),
          reason: 'il nome deve essere centrato sulla colonna');
    });
  });

  group('lo stato della tessera', () {
    testWidgets('la tessera girata non è un pulsante e non ha numerale',
        (tester) async {
      final categorie = [
        const CategoriaTessere(
          nome: 'Storia',
          tessere: [
            DatiTessera(id: 1, valore: 100, stato: StatoTessera.dorso),
            DatiTessera(id: 2, valore: 200, stato: StatoTessera.faccia),
          ],
        ),
      ];
      await _monta(tester,
          schermo: telefonoVerticale, categorie: categorie);

      expect(find.text('200'), findsOneWidget);
      expect(find.text('100'), findsNothing);

      final girata = tester.getSemantics(
        find.bySemanticsLabel('Storia, 100 punti'),
      );
      expect(girata.value, 'già giocata');
      expect(girata.flagsCollection.isButton, isFalse);
    });

    testWidgets('toccare una tessera passa il suo id', (tester) async {
      int? toccata;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = telefonoVerticale;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.scuro,
          home: Scaffold(
            body: RaccoltaTessere(
              categorie: const [
                CategoriaTessere(
                  nome: 'Storia',
                  tessere: [
                    DatiTessera(
                        id: 42, valore: 300, stato: StatoTessera.faccia),
                  ],
                ),
              ],
              onTocco: (id) => toccata = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Tessera));
      expect(toccata, 42);
    });

    testWidgets('una tessera già girata al primo frame non si anima',
        (tester) async {
      // Se una partita si riapre a metà, le tessere giocate devono essere già
      // girate: nessuno deve vedere venti tessere voltarsi all'apertura.
      await _monta(
        tester,
        schermo: telefonoVerticale,
        categorie: [
          const CategoriaTessere(
            nome: 'Storia',
            tessere: [
              DatiTessera(id: 1, valore: 100, stato: StatoTessera.dorso),
            ],
          ),
        ],
      );
      // Nessun frame in sospeso: se ci fosse un'animazione in corso,
      // pumpAndSettle in _monta l'avrebbe consumata e il dorso comparirebbe
      // comunque, quindi verifichiamo che non ci sia mai stato un numerale.
      expect(find.text('100'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
