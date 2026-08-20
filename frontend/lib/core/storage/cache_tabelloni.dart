import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// I tabelloni già visti, tenuti sul dispositivo.
///
/// Copre il guasto realistico del contesto d'uso: wifi ballerino in salotto,
/// cadute brevi. Senza questa cache una disconnessione porta via il tabellone
/// dallo schermo a metà partita — cioè l'oggetto centrale del gioco sparisce
/// per un problema di rete.
///
/// **Perché non Drift**, che pure è nello stack di CLAUDE.md: qui si conserva
/// *un documento immutabile per codice*. Il tabellone non cambia durante la
/// partita — lo dice già il commento del provider — e non c'è nessuna query da
/// fare, nessuna relazione da percorrere, nessuna migrazione da gestire.
/// Metterci sopra un ORM relazionale con generazione di codice significa
/// aggiungere `drift`, `drift_dev`, `build_runner` e uno schema per fare quello
/// che fa una mappa chiave-valore.
///
/// Drift se lo merita in **Fase 7**, dove serve un registro eventi locale con
/// ordinamento e query per riconciliare le azioni offline: lì è lo strumento
/// giusto, e la decisione di architettura è già in agenda.
class CacheTabelloni {
  static const _prefisso = 'tabellone_';
  static const _prefissoData = 'tabellone_data_';

  Future<void> salva(String codicePubblico, Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefisso$codicePubblico', jsonEncode(json));
    await prefs.setString(
      '$_prefissoData$codicePubblico',
      DateTime.now().toIso8601String(),
    );
  }

  Future<Map<String, dynamic>?> leggi(String codicePubblico) async {
    final prefs = await SharedPreferences.getInstance();
    final grezzo = prefs.getString('$_prefisso$codicePubblico');
    if (grezzo == null || grezzo.isEmpty) return null;
    try {
      final decodificato = jsonDecode(grezzo);
      return decodificato is Map<String, dynamic> ? decodificato : null;
    } on FormatException {
      // Un dato illeggibile e' come un dato assente: si butta e si va in rete.
      await prefs.remove('$_prefisso$codicePubblico');
      return null;
    }
  }

  /// Quando il tabellone in cache è stato scaricato. Serve alla UI per dire
  /// *da quando* sta mostrando dati non aggiornati, invece di far finta che
  /// siano freschi.
  Future<DateTime?> salvatoIl(String codicePubblico) async {
    final prefs = await SharedPreferences.getInstance();
    final grezzo = prefs.getString('$_prefissoData$codicePubblico');
    return grezzo == null ? null : DateTime.tryParse(grezzo);
  }
}
