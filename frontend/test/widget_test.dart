import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/providers.dart';
import 'package:frontend/features/home/home_page.dart';
import 'package:frontend/features/partita/partita_page.dart';
import 'package:frontend/models/partita.dart';
import 'package:frontend/models/tabellone.dart';

void main() {
  testWidgets('Home mostra le tre azioni principali', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mieiTabelloniProvider.overrideWith(
            (ref) async => const [
              TabelloneSintesi(
                codicePubblico: 'KDSYMS',
                titolo: 'Quiz storia',
                righe: 5,
                puntiBase: 100,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('crea-tabellone')), findsOneWidget);
    expect(find.byKey(const Key('campo-codice')), findsOneWidget);
    expect(find.text('Quiz storia'), findsOneWidget);
  });

  testWidgets('La griglia disabilita le celle gia giocate', (tester) async {
    const tabellone = Tabellone(
      codicePubblico: 'KDSYMS',
      titolo: 'Quiz',
      righe: 1,
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
    const partita = Partita(
      id: 1,
      codiceTabellone: 'KDSYMS',
      stato: 'in_corso',
      squadre: [
        Squadra(
            id: 1,
            nome: 'Rossi',
            punteggio: 100,
            posizione: 1,
            attiva: true),
      ],
      celleGiocate: [CellaGiocata(cellaId: 10)],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          partitaProvider.overrideWith(() => _FakePartitaNotifier(partita)),
          tabelloneProvider('KDSYMS')
              .overrideWith((ref) async => tabellone),
        ],
        child: const MaterialApp(home: PartitaPage(partitaId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    // La cella giocata mostra il check ed e disabilitata, l'altra il valore
    expect(find.text('200'), findsOneWidget);
    expect(find.text('100'), findsAtLeastNWidgets(1));
    final cellaGiocata =
        tester.widget<InkWell>(find.byKey(const Key('cella-10')));
    expect(cellaGiocata.onTap, isNull);

    // La barra squadre mostra il punteggio
    expect(find.byKey(const Key('punteggio-1')), findsOneWidget);
    expect(find.byKey(const Key('annulla-evento')), findsOneWidget);
  });
}

class _FakePartitaNotifier extends PartitaNotifier {
  _FakePartitaNotifier(this._partita);

  final Partita _partita;

  @override
  Future<Partita> build(int arg) async => _partita;
}
