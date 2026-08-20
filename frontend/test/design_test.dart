import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/design/design.dart';

/// Luminanza relativa secondo WCAG 2.1.
double _luminanza(Color c) {
  double canale(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * canale(c.r) + 0.7152 * canale(c.g) + 0.0722 * canale(c.b);
}

/// Rapporto di contrasto fra due colori opachi.
double _contrasto(Color a, Color b) {
  final la = _luminanza(a);
  final lb = _luminanza(b);
  final alto = math.max(la, lb);
  final basso = math.min(la, lb);
  return (alto + 0.05) / (basso + 0.05);
}

void main() {
  // Il requisito "contrasto AA su ogni testo" di CLAUDE.md, reso eseguibile.
  // Se qualcuno ritocca un token, questo gruppo cade prima della UI.
  group('contrasto dei token', () {
    const testoNormale = 4.5;
    const grandeONonTesto = 3.0;

    void verifica(String cosa, Color primo, Color piano, double minimo) {
      test(cosa, () {
        final r = _contrasto(primo, piano);
        expect(r, greaterThanOrEqualTo(minimo),
            reason: '$cosa dà ${r.toStringAsFixed(2)}:1, '
                'sotto il minimo di $minimo:1');
      });
    }

    verifica('Ghiaccio su Notte', Colori.ghiaccio, Colori.notte, testoNormale);
    verifica('Ghiaccio su Quadro — la domanda e i numerali',
        Colori.ghiaccio, Colori.quadro, testoNormale);
    verifica('Acciaio su Notte', Colori.acciaio, Colori.notte, testoNormale);
    verifica('Acciaio su Quadro', Colori.acciaio, Colori.quadro, testoNormale);
    verifica('Segnale su Notte', Colori.segnale, Colori.notte, testoNormale);
    verifica('Segnale su Quadro', Colori.segnale, Colori.quadro, testoNormale);
    verifica('Notte sull\'Ottone — il chip acceso',
        Colori.notte, Colori.ottone, testoNormale);
    verifica('Ottone su Notte — la luce sul fondo',
        Colori.ottone, Colori.notte, grandeONonTesto);
    verifica('Ottone su Quadro — il bordo della tessera in gioco',
        Colori.ottone, Colori.quadro, grandeONonTesto);

    test('gli smalti squadra si staccano dal fondo', () {
      for (final smalto in SmaltiSquadra.tutti) {
        expect(_contrasto(smalto, Colori.notte),
            greaterThanOrEqualTo(grandeONonTesto),
            reason: 'lo smalto $smalto non si distingue dal fondo');
      }
    });

    test('la fuga è necessaria: i due blu non si separano da soli', () {
      // Non è un difetto da correggere, è il vincolo che rende la fuga un
      // elemento portante. Se un giorno questo test cambiasse, la fuga
      // potrebbe smettere di essere obbligatoria — e andrebbe deciso.
      expect(_contrasto(Colori.quadro, Colori.notte), lessThan(3.0));
      expect(Misure.fuga, greaterThanOrEqualTo(3.0));
    });
  });

  group('la regola textScaler', () {
    test('la dimensione base resta dentro la scala dichiarata', () {
      for (final testo in [
        'Chi?',
        'Questa città fu fondata nel 753 a.C. secondo la tradizione.',
        'Questa città fu fondata nel 753 a.C. secondo la tradizione, e diede '
            'il nome a un impero che arrivò fino in Britannia, dove i suoi '
            'confini furono segnati da un vallo che porta il nome di un '
            'imperatore.',
      ]) {
        final d = Tipografia.dimensioneDomanda(
          testo: testo,
          spazio: const Size(360, 300),
        );
        expect(d, greaterThanOrEqualTo(Tipografia.domandaMinima));
        expect(d, lessThanOrEqualTo(Tipografia.domandaMassima));
      }
    });

    test('più testo non dà mai un corpo più grande', () {
      const spazio = Size(360, 200);
      final corta = Tipografia.dimensioneDomanda(
          testo: 'Chi scrisse la Divina Commedia?', spazio: spazio);
      final lunga = Tipografia.dimensioneDomanda(
          testo: 'Chi scrisse la Divina Commedia, e in quale anno la '
              'cominciò secondo la datazione più accettata dagli studiosi '
              'contemporanei, considerando anche le fonti indirette?',
          spazio: spazio);
      expect(lunga, lessThanOrEqualTo(corta));
    });

    test('meno spazio non dà mai un corpo più grande', () {
      const testo =
          'Questa città fu fondata nel 753 a.C. secondo la tradizione.';
      final largo = Tipografia.dimensioneDomanda(
          testo: testo, spazio: const Size(700, 400));
      final stretto = Tipografia.dimensioneDomanda(
          testo: testo, spazio: const Size(300, 120));
      expect(stretto, lessThanOrEqualTo(largo));
    });

    test('non scende sotto il minimo: quando non ci sta, scorre il layout', () {
      // Spazio deliberatamente insufficiente. La funzione non ha il permesso
      // di rimpicciolire oltre il minimo — chi chiama mette lo scrollable.
      final d = Tipografia.dimensioneDomanda(
        testo: 'Una domanda molto lunga ' * 40,
        spazio: const Size(200, 60),
      );
      expect(d, Tipografia.domandaMinima);
    });
  });

  group('le durate rispettano la preferenza di sistema', () {
    testWidgets('a animazioni ridotte ogni durata è zero', (tester) async {
      late BuildContext ridotto;
      late BuildContext normale;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(builder: (c) {
            ridotto = c;
            return MediaQuery(
              data: const MediaQueryData(disableAnimations: false),
              child: Builder(builder: (c2) {
                normale = c2;
                return const SizedBox();
              }),
            );
          }),
        ),
      );

      expect(ridotto.durata(Movimento.giro), Duration.zero);
      expect(ridotto.durata(Movimento.normale), Duration.zero);
      expect(ridotto.durata(Movimento.accende), Duration.zero);
      expect(ridotto.animazioniRidotte, isTrue);

      expect(normale.durata(Movimento.giro), Movimento.giro);
      expect(normale.animazioniRidotte, isFalse);
    });
  });

  group('i font variabili sono dichiarati come serve', () {
    test('ogni stile display porta gli assi espliciti', () {
      // I default di Archivo sono wght 600 / wdth 100: senza fontVariations
      // il display renderizzerebbe semibold e di larghezza normale.
      final displayStyles = <String, TextStyle>{
        'marchio': Tipografia.marchio,
        'titolo': Tipografia.titolo,
        'sullaLuce': Tipografia.sullaLuce,
        'numeraleTessera': Tipografia.numeraleTessera(26),
        'punteggio': Tipografia.punteggio(22),
        'risposta': Tipografia.risposta(40),
        'headerCategoria': Tipografia.headerCategoria(14),
      };
      for (final voce in displayStyles.entries) {
        final v = voce.value.fontVariations;
        expect(v, isNotNull, reason: '${voce.key} non dichiara gli assi');
        expect(v!.map((f) => f.axis), contains('wdth'),
            reason: '${voce.key} non fissa la larghezza');
        expect(v.map((f) => f.axis), contains('wght'),
            reason: '${voce.key} non fissa il peso');
        final wdth = v.firstWhere((f) => f.axis == 'wdth').value;
        expect(wdth, 125,
            reason: '${voce.key} deve essere espanso, non condensato');
      }
    });

    test('i numeri che si incolonnano usano cifre tabulari', () {
      for (final stile in [
        Tipografia.numeraleTessera(26),
        Tipografia.punteggio(22),
      ]) {
        expect(stile.fontFeatures, contains(const FontFeature.tabularFigures()));
      }
    });
  });
}
