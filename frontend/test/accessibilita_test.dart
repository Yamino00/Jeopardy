import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/design/design.dart';
import 'package:frontend/core/widgets/animazioni.dart';
import 'package:frontend/core/widgets/schermo_sveglio.dart';
import 'package:frontend/data/providers.dart';
import 'package:frontend/features/home/home_page.dart';
import 'package:frontend/features/partita/partita_page.dart';
import 'package:frontend/models/partita.dart';
import 'package:frontend/models/tabellone.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tabellone = Tabellone(
  codicePubblico: 'KDSYMS',
  titolo: 'Storia romana',
  righe: 2,
  puntiBase: 100,
  categorie: [
    Categoria(
      id: 1,
      nomeDisplay: 'Storia',
      posizione: 1,
      celle: [
        Cella(id: 10, riga: 1, valore: 100, dailyDouble: false),
        Cella(id: 11, riga: 2, valore: 200, dailyDouble: false),
      ],
    ),
  ],
);

const _partita = Partita(
  id: 1,
  codiceTabellone: 'KDSYMS',
  stato: 'in_corso',
  turnoSquadraId: 1,
  squadre: [
    Squadra(id: 1, nome: 'Rossi', punteggio: 300, posizione: 1, attiva: true),
  ],
  celleGiocate: [],
);

class _FintaPartita extends PartitaNotifier {
  @override
  Future<Partita> build(int arg) async => _partita;
}

Future<void> _montaPartita(WidgetTester tester, {Size? schermo}) async {
  if (schermo != null) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = schermo;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        partitaProvider.overrideWith(_FintaPartita.new),
        tabelloneProvider('KDSYMS').overrideWith((ref) async => _tabellone),
      ],
      child: MaterialApp(
        theme: Tema.scuro,
        home: const PartitaPage(partitaId: 1),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ogni comando ha un ruolo e un nome', () {
    testWidgets('l\'annulla esiste per chi non vede lo schermo',
        (tester) async {
      await _montaPartita(tester);
      // C1: era un Container dentro un GestureDetector nudo. Per TalkBack
      // l'annulla — il comando piu' importante dell'app — non esisteva.
      final annulla = tester.getSemantics(
        find.bySemanticsLabel('Annulla l\'ultima azione'),
      );
      expect(annulla.flagsCollection.isButton, isTrue);
    });

    testWidgets('l\'annulla è raggiungibile col pollice', (tester) async {
      await _montaPartita(tester);
      // CLAUDE.md: "sempre raggiungibile con un pollice, mai sepolto in un
      // menu". Piu' grande del minimo, perche' si cerca senza guardare.
      final area = tester.getSize(find.byKey(const Key('annulla-evento')));
      expect(area.width, greaterThanOrEqualTo(Misure.areaAnnulla));
      expect(area.height, greaterThanOrEqualTo(Misure.areaAnnulla));
    });

    testWidgets('la scheda squadra dice punteggio e turno', (tester) async {
      await _montaPartita(tester);
      expect(
        find.bySemanticsLabel('Rossi, 300 punti, di turno'),
        findsOneWidget,
      );
    });

    testWidgets('le tessere sono pulsanti con un nome sensato',
        (tester) async {
      await _montaPartita(tester);
      final tessera =
          tester.getSemantics(find.bySemanticsLabel('Storia, 100 punti'));
      expect(tessera.flagsCollection.isButton, isTrue);
      expect(tessera.value, 'da giocare');
    });
  });

  group('le aree tattili rispettano il minimo', () {
    testWidgets('PremibileAnimato garantisce 48dp anche su un figlio minuscolo',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.scuro,
          home: Scaffold(
            body: Center(
              child: PremibileAnimato(
                onTap: () {},
                etichetta: 'minuscolo',
                child: const SizedBox(width: 8, height: 8),
              ),
            ),
          ),
        ),
      );
      final area = tester.getSize(find.byType(PremibileAnimato));
      expect(area.width, greaterThanOrEqualTo(Misure.areaTattileMinima));
      expect(area.height, greaterThanOrEqualTo(Misure.areaTattileMinima));
    });

    testWidgets('senza etichetta non impone una semantica sbagliata',
        (tester) async {
      // Chi ha gia' un Semantics proprio piu' in alto — la tessera, l'annulla —
      // non deve ritrovarsi due nodi annidati che dicono cose diverse.
      await tester.pumpWidget(
        MaterialApp(
          theme: Tema.scuro,
          home: Scaffold(
            body: PremibileAnimato(
              onTap: () {},
              child: const Text('nudo'),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('nudo'), findsOneWidget);
    });
  });

  group('lo schermo resta acceso solo in partita', () {
    testWidgets('la partita in corso monta il blocco', (tester) async {
      await _montaPartita(tester);
      final sveglio =
          tester.widget<SchermoSveglio>(find.byType(SchermoSveglio));
      expect(sveglio.attivo, isTrue);
    });

    testWidgets('il widget non fa cadere niente senza il plugin nativo',
        (tester) async {
      // Nei test il canale nativo non e' registrato: tenere acceso lo schermo
      // e' un di piu', e non deve poter far cadere una partita.
      await tester.pumpWidget(
        const MaterialApp(
          home: SchermoSveglio(attivo: true, child: Text('gioco')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('gioco'), findsOneWidget);
    });
  });

  group('la home resta navigabile a voce', () {
    testWidgets('i comandi principali hanno un nome', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mieiTabelloniProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await tester.pumpAndSettle();
      // I pulsanti Material portano gia' il ruolo e l'etichetta: quello che
      // serve verificare e' che siano raggiungibili per nome.
      expect(find.bySemanticsLabel('Crea nuovo tabellone'), findsOneWidget);
      expect(find.bySemanticsLabel('Entra'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Crea nuovo tabellone'))
            .flagsCollection
            .isButton,
        isTrue,
      );
    });
  });
}
