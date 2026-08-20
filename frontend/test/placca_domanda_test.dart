import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/design/design.dart';
import 'package:frontend/features/partita/cella_senza_domanda.dart';
import 'package:frontend/features/partita/placca_domanda.dart';

const telefonoVerticale = Size(360, 800);
const telefonoOrizzontale = Size(800, 360);
const tabletOrizzontale = Size(1280, 800);

/// Una domanda corta e una lunga: gli estremi del gate di fase.
const corta = 'Chi dipinse la Gioconda?';
const lunga =
    'Questa città dell\'Italia centrale fu fondata nel 753 a.C. secondo la '
    'tradizione riportata da Varrone, e diede il nome a un impero che al suo '
    'apice arrivò fino in Britannia, dove il confine settentrionale venne '
    'segnato da un vallo che ancora porta il nome di un imperatore.';

const squadre = <SquadraInPlacca>[
  (id: 1, nome: 'I Centurioni', colore: SmaltiSquadra.vermiglio),
  (id: 2, nome: 'Le Aquile', colore: SmaltiSquadra.guado),
  (id: 3, nome: 'I Gladiatori', colore: SmaltiSquadra.alloro),
];

Future<void> _montaPlacca(
  WidgetTester tester, {
  required Size schermo,
  double scala = 1.0,
  String domanda = corta,
  bool rispostaVisibile = false,
  void Function(int, bool)? onAssegna,
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
        child: PlaccaDomanda(
          nomeCategoria: 'Storia romana',
          valore: 300,
          domanda: domanda,
          risposta: 'Roma',
          rispostaVisibile: rispostaVisibile,
          squadre: squadre,
          inviando: false,
          onChiudi: () {},
          onMostraRisposta: () {},
          onAssegna: onAssegna ?? (_, __) {},
          onPassa: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _corpoDomanda(WidgetTester tester, String testo) => tester
    .widget<Text>(find.text(testo))
    .style!
    .fontSize!;

void main() {
  group('la domanda entra sempre', () {
    for (final (nomeSchermo, schermo) in [
      ('telefono verticale', telefonoVerticale),
      ('telefono orizzontale', telefonoOrizzontale),
      ('tablet orizzontale', tabletOrizzontale),
    ]) {
      for (final scala in [1.0, 2.0]) {
        for (final (nomeTesto, testo) in [
          ('20 caratteri', corta),
          ('400 caratteri', lunga),
        ]) {
          testWidgets('$nomeTesto, $nomeSchermo, scala $scala',
              (tester) async {
            await _montaPlacca(
              tester,
              schermo: schermo,
              scala: scala,
              domanda: testo,
            );
            expect(tester.takeException(), isNull,
                reason: 'overflow con $nomeTesto su $nomeSchermo a $scala');
            expect(find.text(testo), findsOneWidget);
          });
        }
      }
    }

    testWidgets('il corpo si adatta: la domanda lunga è più piccola',
        (tester) async {
      // Il difetto R9: prima era fontSize 30 fisso, quindi troppo piccolo su
      // tablet e troppo grande per una domanda lunga su telefono.
      await _montaPlacca(tester, schermo: tabletOrizzontale, domanda: corta);
      final dCorta = _corpoDomanda(tester, corta);
      await _montaPlacca(tester, schermo: tabletOrizzontale, domanda: lunga);
      final dLunga = _corpoDomanda(tester, lunga);

      expect(dLunga, lessThan(dCorta));
      expect(dCorta, lessThanOrEqualTo(Tipografia.domandaMassima));
      expect(dLunga, greaterThanOrEqualTo(Tipografia.domandaMinima));
    });

    testWidgets('il corpo base non dipende dalla scala', (tester) async {
      // La regola: la base si calcola a scala 1.0, il fattore utente si
      // applica sopra e non viene mai compensato.
      await _montaPlacca(tester, schermo: telefonoVerticale, scala: 1.0);
      final a1 = _corpoDomanda(tester, corta);
      await _montaPlacca(tester, schermo: telefonoVerticale, scala: 2.0);
      final a2 = _corpoDomanda(tester, corta);
      expect(a2, a1, reason: 'qualcuno compensa il textScaler');
    });

    testWidgets('la misura è tappata a 32 caratteri', (tester) async {
      await _montaPlacca(tester, schermo: tabletOrizzontale, domanda: lunga);
      final corpo = _corpoDomanda(tester, lunga);
      final larghezzaTesto = tester.getSize(find.text(lunga)).width;
      // Il contratto e': la larghezza del testo non supera mai la misura di 32
      // caratteri a quel corpo. Quando la colonna e' piu' stretta vince la
      // colonna, ed e' giusto — il tetto serve a impedire righe da 90
      // caratteri, non a lasciare spazio vuoto.
      expect(larghezzaTesto,
          lessThanOrEqualTo(Tipografia.larghezzaMisuraDomanda(corpo) + 1));
    });
  });

  group('la risposta non fa saltare il layout', () {
    testWidgets('il rilievo vuoto occupa lo stesso spazio della risposta',
        (tester) async {
      // Prima un AnimatedSwitcher con SizeTransition faceva saltare verso
      // l'alto tutto il testo della domanda proprio quando la sala guarda.
      final rilievo = find.byKey(const Key('rilievo-risposta'));

      await _montaPlacca(tester, schermo: telefonoVerticale);
      final primaDomanda = tester.getRect(find.text(corta));
      final primaRilievo = tester.getRect(rilievo);

      await _montaPlacca(
        tester,
        schermo: telefonoVerticale,
        rispostaVisibile: true,
      );
      final dopoDomanda = tester.getRect(find.text(corta));
      final dopoRilievo = tester.getRect(rilievo);

      expect(dopoRilievo.size, primaRilievo.size,
          reason: 'il rilievo e la risposta occupano lo stesso spazio');
      expect(dopoRilievo.top, primaRilievo.top,
          reason: 'il riquadro non si sposta');
      expect(dopoDomanda.top, closeTo(primaDomanda.top, 1),
          reason: 'la domanda non si deve spostare alla rivelazione');
      expect(find.text('ROMA'), findsOneWidget);
    });

    testWidgets('prima della rivelazione la risposta non è nell\'albero',
        (tester) async {
      await _montaPlacca(tester, schermo: telefonoVerticale);
      expect(find.text('ROMA'), findsNothing);
      expect(find.text('RISPOSTA COPERTA'), findsOneWidget);
    });
  });

  group('assegnare i punti', () {
    testWidgets('acceso e spento, non verde e rosso', (tester) async {
      await _montaPlacca(
        tester,
        schermo: telefonoVerticale,
        rispostaVisibile: true,
      );
      // Il chip che assegna è riempito, quello che toglie è solo un contorno:
      // la differenza è il riempimento e il segno, e regge il bianco e nero.
      expect(
        find.descendant(
          of: find.byKey(const Key('assegna-1')),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('togli-1')),
          matching: find.byType(OutlinedButton),
        ),
        findsOneWidget,
      );
    });

    testWidgets('la semantica dice cosa fa il comando, non di che colore è',
        (tester) async {
      await _montaPlacca(
        tester,
        schermo: telefonoVerticale,
        rispostaVisibile: true,
      );
      expect(
        find.bySemanticsLabel('Assegna 300 punti a I Centurioni'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Togli 300 punti a I Centurioni'),
        findsOneWidget,
      );
    });

    testWidgets('il tocco riporta squadra e direzione', (tester) async {
      final assegnazioni = <(int, bool)>[];
      await _montaPlacca(
        tester,
        schermo: telefonoVerticale,
        rispostaVisibile: true,
        onAssegna: (id, positivo) => assegnazioni.add((id, positivo)),
      );
      await tester.tap(find.byKey(const Key('assegna-2')));
      await tester.tap(find.byKey(const Key('togli-3')));
      expect(assegnazioni, [(2, true), (3, false)]);
    });

    testWidgets('su tablet orizzontale si legge a sinistra e si assegna a destra',
        (tester) async {
      await _montaPlacca(
        tester,
        schermo: tabletOrizzontale,
        rispostaVisibile: true,
      );
      final domanda = tester.getRect(find.text(corta));
      final chip = tester.getRect(find.byKey(const Key('assegna-1')));
      expect(chip.left, greaterThan(domanda.right),
          reason: 'in due colonne i comandi stanno a destra della domanda');
    });
  });

  group('la cella senza domanda', () {
    Future<void> monta(
      WidgetTester tester, {
      required bool puoRiparare,
      EsitoTentativo esito = EsitoTentativo.nessuno,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = telefonoVerticale;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.scuro,
          home: CellaSenzaDomanda(
            nomeCategoria: 'Storia romana',
            valore: 300,
            puoRiparare: puoRiparare,
            esito: esito,
            messaggioErrore: null,
            onChiudi: () {},
            onRigenera: () {},
            onCorreggi: () {},
            onPassa: () {},
          ),
        ),
      );
      // pump e non pumpAndSettle: nello stato "in corso" gira un
      // CircularProgressIndicator, che e' un'animazione senza fine e farebbe
      // scadere pumpAndSettle.
      await tester.pump();
    }

    testWidgets('il segnaposto non viene mostrato come contenuto',
        (tester) async {
      await monta(tester, puoRiparare: true);
      // E8: prima "Domanda da completare" finiva sullo schermo come se fosse
      // una domanda, e la rivelazione mostrava un riquadro vuoto.
      expect(find.text('Domanda da completare'), findsNothing);
      expect(find.text('Questa cella non ha una domanda'), findsOneWidget);
    });

    testWidgets('chi ha il codice di modifica vede le due riparazioni',
        (tester) async {
      await monta(tester, puoRiparare: true);
      expect(find.byKey(const Key('rigenera-cella')), findsOneWidget);
      expect(find.byKey(const Key('correggi-cella')), findsOneWidget);
    });

    testWidgets('il costo in quota è dichiarato, non nascosto', (tester) async {
      await monta(tester, puoRiparare: true);
      expect(
        find.textContaining('Consuma una delle generazioni giornaliere'),
        findsOneWidget,
      );
    });

    testWidgets('chi non lo ha vede solo il passa', (tester) async {
      await monta(tester, puoRiparare: false);
      expect(find.byKey(const Key('rigenera-cella')), findsNothing);
      expect(find.byKey(const Key('correggi-cella')), findsNothing);
      expect(find.byKey(const Key('passa-cella-rotta')), findsOneWidget);
    });

    testWidgets('col 409 la rigenerazione sparisce e resta la mano',
        (tester) async {
      // Il punto del gate: con la banca esaurita la cella deve restare
      // recuperabile. Insistere sulla rigenerazione consumerebbe solo quota.
      await monta(
        tester,
        puoRiparare: true,
        esito: EsitoTentativo.esaurita,
      );
      expect(find.byKey(const Key('rigenera-cella')), findsNothing,
          reason: 'non si ripropone un tentativo che costa e non puo riuscire');
      expect(find.byKey(const Key('correggi-cella')), findsOneWidget,
          reason: 'la correzione a mano e l uscita garantita');
      expect(find.textContaining('la banca è esaurita'), findsOneWidget);
    });

    testWidgets('durante la generazione non si può chiudere per sbaglio',
        (tester) async {
      await monta(tester, puoRiparare: true, esito: EsitoTentativo.inCorso);
      final chiudi = tester.widget<IconButton>(
        find.byKey(const Key('chiudi-cella-rotta')),
      );
      expect(chiudi.onPressed, isNull);
      expect(find.text('Generazione in corso…'), findsOneWidget);
    });
  });

  group('il dialog di correzione', () {
    testWidgets('salva solo con entrambi i campi pieni', (tester) async {
      ({String testo, String risposta})? risultato;
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.scuro,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    risultato = await showDialog<
                        ({String testo, String risposta})>(
                      context: context,
                      builder: (_) => const DialogCorrezioneCella(
                        nomeCategoria: 'Storia romana',
                        valore: 300,
                      ),
                    );
                  },
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();

      final salva = find.byKey(const Key('salva-correzione'));
      expect(tester.widget<FilledButton>(salva).onPressed, isNull,
          reason: 'coi campi vuoti non si salva');

      await tester.enterText(
          find.byKey(const Key('campo-testo-cella')), 'Chi fondò Roma?');
      await tester.pump();
      expect(tester.widget<FilledButton>(salva).onPressed, isNull,
          reason: 'serve anche la risposta');

      await tester.enterText(
          find.byKey(const Key('campo-risposta-cella')), 'Romolo');
      await tester.pump();
      expect(tester.widget<FilledButton>(salva).onPressed, isNotNull);

      await tester.tap(salva);
      await tester.pumpAndSettle();
      expect(risultato, (testo: 'Chi fondò Roma?', risposta: 'Romolo'));
    });
  });
}
