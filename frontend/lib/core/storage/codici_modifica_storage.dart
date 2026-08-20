import 'package:shared_preferences/shared_preferences.dart';

/// I codici di modifica dei tabelloni creati su questo dispositivo.
///
/// Il backend restituisce `codice_modifica` **una sola volta**, nella risposta
/// alla creazione. Prima veniva mostrato in un banner con la scritta "Conserva
/// il codice di modifica" e poi buttato: non esisteva nessuna schermata in cui
/// usarlo, quindi si consegnava all'utente un segreto che nell'app non apriva
/// niente.
///
/// Qui il dispositivo di chi ha creato il tabellone se lo ricorda, ed è ciò che
/// rende raggiungibili le due azioni che richiedono l'header
/// `X-Codice-Modifica`: rigenerare una cella senza domanda e correggerla a mano.
/// Chi apre lo stesso tabellone da un altro telefono non ne ha uno e vede solo
/// il gioco — che è esattamente la distinzione che il backend intende.
///
/// Non è un sistema di autenticazione: è un promemoria locale. L'identità resta
/// un UUID anonimo, e nessun account entra nell'app.
class CodiciModificaStorage {
  static const _prefisso = 'codice_modifica_';

  Future<void> ricorda(String codicePubblico, String? codiceModifica) async {
    if (codiceModifica == null || codiceModifica.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefisso$codicePubblico', codiceModifica);
  }

  Future<String?> perTabellone(String codicePubblico) async {
    final prefs = await SharedPreferences.getInstance();
    final salvato = prefs.getString('$_prefisso$codicePubblico');
    return (salvato == null || salvato.isEmpty) ? null : salvato;
  }

  Future<void> dimentica(String codicePubblico) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefisso$codicePubblico');
  }
}
