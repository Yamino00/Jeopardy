import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/partita.dart';
import 'package:frontend/models/tabellone.dart';

void main() {
  group('Tabellone.fromJson', () {
    test('parsa la risposta snake_case del backend', () {
      final tabellone = Tabellone.fromJson({
        'codice_pubblico': 'KDSYMS',
        'codice_modifica': 'ABCDEF234567',
        'titolo': 'Quiz storia',
        'righe': 5,
        'punti_base': 100,
        'categorie': [
          {
            'id': 1,
            'nome_display': 'Storia romana',
            'posizione': 1,
            'celle': [
              {
                'id': 10,
                'riga': 1,
                'valore': 100,
                'daily_double': false,
                'testo': 'Chi fu il primo imperatore romano?',
                'risposta': 'Augusto',
              },
            ],
          },
        ],
      });

      expect(tabellone.codicePubblico, 'KDSYMS');
      expect(tabellone.codiceModifica, 'ABCDEF234567');
      expect(tabellone.categorie, hasLength(1));
      expect(tabellone.categorie.first.celle.first.valore, 100);
      expect(tabellone.cellaById(10)?.risposta, 'Augusto');
      expect(tabellone.cellaById(99), isNull);
    });

    test('il GET pubblico non ha codice_modifica', () {
      final tabellone = Tabellone.fromJson({
        'codice_pubblico': 'KDSYMS',
        'titolo': 'Quiz',
        'righe': 3,
        'punti_base': 200,
        'categorie': [],
      });
      expect(tabellone.codiceModifica, isNull);
    });
  });

  group('Partita.fromJson', () {
    test('parsa stato completo con squadre e celle giocate', () {
      final partita = Partita.fromJson({
        'id': 7,
        'codice_tabellone': 'KDSYMS',
        'stato': 'in_corso',
        'turno_squadra_id': 2,
        'squadre': [
          {
            'id': 1,
            'nome': 'Rossi',
            'colore': '#e53935',
            'punteggio': 100,
            'posizione': 1,
            'attiva': true,
          },
          {
            'id': 2,
            'nome': 'Blu',
            'colore': null,
            'punteggio': 0,
            'posizione': 2,
            'attiva': false,
          },
        ],
        'celle_giocate': [
          {'cella_id': 10, 'squadra_id': 1, 'esito': 'corretta'},
          {'cella_id': 11, 'squadra_id': null, 'esito': 'passata'},
        ],
      });

      expect(partita.inCorso, isTrue);
      expect(partita.turnoSquadraId, 2);
      expect(partita.squadreAttive.map((s) => s.id), [1]);
      expect(partita.cellaGiaGiocata(10), isTrue);
      expect(partita.cellaGiaGiocata(12), isFalse);
      expect(partita.celleGiocate[1].squadraId, isNull);
    });

    test('partita conclusa non e in corso', () {
      final partita = Partita.fromJson({
        'id': 7,
        'codice_tabellone': 'KDSYMS',
        'stato': 'conclusa',
        'squadre': [],
        'celle_giocate': [],
      });
      expect(partita.inCorso, isFalse);
    });
  });
}
