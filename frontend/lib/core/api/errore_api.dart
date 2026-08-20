import 'package:dio/dio.dart';

/// Di che natura è un errore, dal punto di vista di chi sta giocando.
///
/// Il codice precedente aveva **cinque `Text('$e')`** in cinque schermate: lo
/// stesso trattamento per la rete assente, per un codice sbagliato, per la
/// quota esaurita e per una condizione del tutto normale come "non c'è niente
/// da annullare". Sono situazioni diverse, con rimedi diversi, e vanno
/// distinte prima nel tipo e poi nella UI.
enum GenereErrore {
  /// Il server non è stato raggiunto: timeout, DNS, wifi caduto. È l'errore
  /// più probabile in salotto, ed è l'unico che ha davvero senso riprovare.
  rete,

  /// 404: il codice del tabellone non esiste, o la partita è sparita.
  nonTrovato,

  /// 409. **Non sempre è un errore**: "Nessun evento da annullare" è la
  /// condizione normale di inizio partita. Vedi [ErroreApi.atteso].
  conflitto,

  /// 429: la quota giornaliera di generazioni è esaurita.
  quota,

  /// 4xx dovuti alla richiesta: dati non validi, permessi mancanti.
  richiesta,

  /// 5xx: il server ha un problema suo.
  server,
}

/// Un errore che l'app sa raccontare.
class ErroreApi implements Exception {
  const ErroreApi({
    required this.genere,
    required this.messaggio,
    this.codiceStato,
  });

  final GenereErrore genere;

  /// Il testo del backend, quando c'è. Serve come dettaglio, **non** come
  /// messaggio principale: un Problem Detail è scritto per chi sviluppa.
  final String messaggio;

  final int? codiceStato;

  /// Vero per le condizioni che sono normali e non guasti.
  ///
  /// Oggi ce n'è una sola e vale la pena nominarla: annullare quando non c'è
  /// ancora niente da annullare. Il backend risponde 409 e il codice
  /// precedente lo mostrava come uno snackbar d'errore col testo del server, a
  /// un host che aveva semplicemente premuto un pulsante di troppo.
  bool get atteso =>
      genere == GenereErrore.conflitto &&
      messaggio.toLowerCase().contains('nessun evento da annullare');

  /// Se abbia senso offrire "riprova". Su un 404 o su un conflitto riprovare
  /// darebbe lo stesso esito, quindi il pulsante non si mostra.
  bool get vaLaPenaRiprovare =>
      genere == GenereErrore.rete || genere == GenereErrore.server;

  /// Il titolo che legge l'utente. Non è il messaggio del server.
  String get titolo => switch (genere) {
        GenereErrore.rete => 'Nessuna connessione',
        GenereErrore.nonTrovato => 'Non trovato',
        GenereErrore.conflitto => 'Non si può fare adesso',
        GenereErrore.quota => 'Generazioni finite per oggi',
        GenereErrore.richiesta => 'Qualcosa non torna',
        GenereErrore.server => 'Il server ha un problema',
      };

  /// Cosa può fare l'utente. È la parte che nel codice precedente mancava del
  /// tutto: si diceva cosa era andato storto e mai come uscirne.
  String get rimedio => switch (genere) {
        GenereErrore.rete =>
          'Controlla il wifi e riprova. I tabelloni già aperti restano '
              'visibili.',
        GenereErrore.nonTrovato =>
          'Controlla il codice: sono sei caratteri, e le lettere O e 0 si '
              'confondono facilmente.',
        GenereErrore.conflitto => messaggio,
        GenereErrore.quota =>
          'Il limite si azzera domani. Nel frattempo puoi giocare i tabelloni '
              'che hai già e scrivere le domande a mano.',
        GenereErrore.richiesta => messaggio,
        GenereErrore.server =>
          'Non dipende da te. Riprova fra poco: se la partita è in corso, i '
              'punteggi sono già salvati.',
      };

  @override
  String toString() => '$titolo: $messaggio';

  /// Traduce un errore di Dio in qualcosa che la UI sa raccontare.
  factory ErroreApi.da(DioException e) {
    final stato = e.response?.statusCode;
    final dati = e.response?.data;
    final dettaglio = dati is Map && dati['detail'] is String
        ? dati['detail'] as String
        : null;

    final genere = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        GenereErrore.rete,
      _ => switch (stato) {
          404 => GenereErrore.nonTrovato,
          409 => GenereErrore.conflitto,
          429 => GenereErrore.quota,
          final s when s != null && s >= 500 => GenereErrore.server,
          final s when s != null && s >= 400 => GenereErrore.richiesta,
          _ => GenereErrore.rete,
        },
    };

    return ErroreApi(
      genere: genere,
      messaggio: dettaglio ??
          (genere == GenereErrore.rete
              ? 'Il server non risponde'
              : 'Errore ${stato ?? ''}'.trim()),
      codiceStato: stato,
    );
  }
}
