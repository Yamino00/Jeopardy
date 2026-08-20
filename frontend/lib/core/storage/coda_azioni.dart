import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/azione_locale.dart';

/// Le giocate in attesa di raggiungere il server, per partita.
///
/// Sopravvive alla chiusura dell'app: una sessione dura 20-40 minuti e il
/// telefono può finire la batteria, ricevere una chiamata o essere chiuso per
/// sbaglio. Se la coda vivesse in memoria, quello significherebbe perdere i
/// punti assegnati mentre il wifi era giù.
///
/// **Perché non Drift**, che il piano prevedeva per questa fase: qui c'è una
/// lista ordinata di poche decine di intenti, letta e scritta per intero, senza
/// nessuna query. Il disegno che è venuto fuori — rigiocare gli intenti in
/// ordine invece di tenere uno stato locale autorevole — non ha bisogno di un
/// database relazionale. Se un giorno servisse un registro eventi locale
/// interrogabile, allora sì.
class CodaAzioni {
  static const _prefisso = 'coda_azioni_';

  String _chiave(int partitaId) => '$_prefisso$partitaId';

  Future<List<AzioneLocale>> leggi(int partitaId) async {
    final prefs = await SharedPreferences.getInstance();
    final grezzo = prefs.getString(_chiave(partitaId));
    if (grezzo == null || grezzo.isEmpty) return const [];
    try {
      final lista = jsonDecode(grezzo) as List<dynamic>;
      return lista
          .map((v) => AzioneLocale.fromJson(v as Map<String, dynamic>))
          .toList(growable: false);
    } on FormatException {
      // Una coda illeggibile è peggio di una coda assente: si butta, perché
      // rigiocare intenti corrotti falserebbe i punteggi.
      await prefs.remove(_chiave(partitaId));
      return const [];
    }
  }

  Future<void> scrivi(int partitaId, List<AzioneLocale> azioni) async {
    final prefs = await SharedPreferences.getInstance();
    if (azioni.isEmpty) {
      await prefs.remove(_chiave(partitaId));
      return;
    }
    await prefs.setString(
      _chiave(partitaId),
      jsonEncode([for (final a in azioni) a.toJson()]),
    );
  }

  Future<void> svuota(int partitaId) => scrivi(partitaId, const []);
}
