import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/providers.dart';
import 'package:frontend/core/widgets/raccolta_tessere.dart';
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

    // La tessera giocata si e' girata: mostra il dorso, quindi il suo numerale
    // non e' piu' nell'albero. Prima era un segno di spunta a 2,1:1 sopra la
    // tessera; ora lo stato si legge dalla direzione della tessera.
    //
    // La ricerca e' ristretta alla griglia: '100' e anche il punteggio della
    // squadra nel podio, e cercarlo in tutta la pagina trova quello.
    final griglia = find.byType(RaccoltaTessere);
    expect(find.descendant(of: griglia, matching: find.text('200')),
        findsOneWidget, reason: 'la 200 e giocabile e mostra il numerale');
    expect(find.descendant(of: griglia, matching: find.text('100')),
        findsNothing, reason: 'la 100 e girata: nessun numerale');

    // E lo stato arriva anche a chi usa uno screen reader.
    final girata = tester.getSemantics(
      find.bySemanticsLabel('Storia, 100 punti'),
    );
    expect(girata.value, 'già giocata');
    expect(girata.flagsCollection.isButton, isFalse,
        reason: 'una tessera girata non e piu un pulsante');

    final giocabile = tester.getSemantics(
      find.bySemanticsLabel('Storia, 200 punti'),
    );
    expect(giocabile.value, 'da giocare');
    expect(giocabile.flagsCollection.isButton, isTrue);

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
