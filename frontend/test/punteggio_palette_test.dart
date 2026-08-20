import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/design/design.dart';
import 'package:frontend/core/widgets/punteggio_palette.dart';

Future<void> _monta(
  WidgetTester tester,
  int valore, {
  bool animazioniRidotte = false,
  double scala = 1.0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: Tema.scuro,
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: animazioniRidotte,
          textScaler: TextScaler.linear(scala),
        ),
        child: Scaffold(
          body: Center(
            child: PunteggioPalette(valore: valore, dimensione: 22),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('il piano del giro', () {
    test('salire gira in avanti, scendere gira al contrario', () {
      expect(PianoPalette.fra(400, 700).indietro, isFalse);
      expect(PianoPalette.fra(700, 400).indietro, isTrue,
          reason: 'l\'annulla, e ogni discesa, gira al contrario');
    });

    test('i passi sono la distanza ciclica nel verso del cambiamento', () {
      // 4 -> 7 in avanti sono tre scatti; 7 -> 4 indietro sono gli stessi tre,
      // percorsi nell'altro verso. Una paletta non taglia per la strada corta.
      expect(PianoPalette.fra(4, 7).passi, [3]);
      expect(PianoPalette.fra(7, 4).passi, [3]);
    });

    test('il riporto passa per lo zero, non salta', () {
      // 9 -> 10: la posizione delle unità fa 9->0, cioè un solo scatto.
      final p = PianoPalette.fra(9, 10);
      expect(p.passi.length, 2, reason: 'due posizioni, allineate a destra');
      expect(p.passi.last, 1, reason: 'le unità fanno 9->0 in uno scatto');
      expect(p.indietro, isFalse);
    });

    test('quando cresce di una cifra le posizioni si allineano a destra', () {
      final p = PianoPalette.fra(400, 1500);
      expect(p.passi.length, 4);
      expect(p.indietro, isFalse);
    });

    test('il segno non è una paletta: conta il valore, non il modulo', () {
      // Da 100 a -200 il punteggio scende, quindi si gira al contrario, e le
      // cifre lavorano sui moduli (100 -> 200).
      final p = PianoPalette.fra(100, -200);
      expect(p.indietro, isTrue);
      expect(p.passi.length, 3);
    });

    test('nessun cambiamento, nessun giro', () {
      final p = PianoPalette.fra(300, 300);
      expect(p.passi.every((x) => x == 0), isTrue);
      expect(p.durata, Duration.zero);
    });

    test('più scatti non allungano il giro indefinitamente', () {
      // Un 0 -> 9 farebbe nove scatti: il tempo per scatto si accorcia, così il
      // giro resta guardabile invece di diventare fastidioso.
      final corto = PianoPalette.fra(4, 5);
      final lungo = PianoPalette.fra(0, 9);
      expect(lungo.durata, greaterThan(corto.durata));
      expect(lungo.durata.inMilliseconds, lessThan(1000),
          reason: 'nove scatti devono restare sotto il secondo');
      expect(lungo.msPerPasso, lessThan(corto.msPerPasso));
    });

    test('lo sfasamento fa partire le posizioni una dopo l\'altra', () {
      final p = PianoPalette.fra(1111, 2222);
      // A un istante iniziale la prima posizione è già in moto e l'ultima no.
      const t = 0.01;
      expect(p.localePer(0, t), greaterThan(0));
      expect(p.localePer(3, t), 0,
          reason: 'l\'ultima paletta non è ancora partita');
    });
  });

  group('il widget', () {
    testWidgets('annuncia solo il valore finale', (tester) async {
      await _monta(tester, 400);
      final semantica = tester.getSemantics(find.byType(PunteggioPalette));
      expect(semantica.value, '400');

      await _monta(tester, 700);
      // A metà giro il valore annunciato è già quello finale: uno screen reader
      // non deve leggere i passaggi intermedi, che non sono informazione.
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        tester.getSemantics(find.byType(PunteggioPalette)).value,
        '700',
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(PunteggioPalette)).value,
        '700',
      );
    });

    testWidgets('al primo frame non gira', (tester) async {
      // Riaprire una partita a metà non deve far girare tutti i podi da zero.
      await _monta(tester, 400);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('un cambio di valore mette in moto le palette',
        (tester) async {
      await _monta(tester, 400);
      await _monta(tester, 700);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('con le animazioni ridotte il valore cambia di colpo',
        (tester) async {
      await _monta(tester, 400, animazioniRidotte: true);
      await _monta(tester, 700, animazioniRidotte: true);
      expect(tester.hasRunningAnimations, isFalse,
          reason: 'chi ha ridotto le animazioni non deve vedere nessun giro');
      expect(
        tester.getSemantics(find.byType(PunteggioPalette)).value,
        '700',
      );
    });

    testWidgets('il segno negativo compare accanto alle palette',
        (tester) async {
      await _monta(tester, -200);
      expect(find.text('−'), findsOneWidget);
      await _monta(tester, 200);
      await tester.pumpAndSettle();
      expect(find.text('−'), findsNothing);
    });

    testWidgets('cresce con il textScaler, e non lo compensa', (tester) async {
      await _monta(tester, 400, scala: 1.0);
      final normale = tester.getSize(find.byType(PunteggioPalette));
      await _monta(tester, 400, scala: 2.0);
      final grande = tester.getSize(find.byType(PunteggioPalette));
      expect(grande.height, greaterThan(normale.height));
      expect(grande.width, greaterThan(normale.width));
    });

    testWidgets('quattro podi insieme non lanciano niente', (tester) async {
      // Il gate dei 60fps si misura su dispositivo; qui si verifica almeno che
      // quattro palette che girano insieme reggano il layout.
      Future<void> montaQuattro(List<int> valori) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: Tema.scuro,
            home: Scaffold(
              body: Row(
                children: [
                  for (var i = 0; i < valori.length; i++)
                    Expanded(
                      child: PunteggioPalette(
                        key: ValueKey(i),
                        valore: valori[i],
                        dimensione: 22,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await montaQuattro([400, 200, -100, 1500]);
      await montaQuattro([700, 0, 300, 900]);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
