import 'package:dio/dio.dart';

import '../core/api/api_client.dart';

/// Perché una domanda è sbagliata. I valori sul filo sono quelli del vincolo
/// CHECK su `segnalazione.motivo`: cambiarli qui senza cambiarli là fa un 500.
enum MotivoSegnalazione {
  errata('errata', 'La risposta è sbagliata'),
  ambigua('ambigua', 'La domanda è ambigua o poco chiara'),
  duplicata('duplicata', 'È uguale a un\'altra domanda'),
  offensiva('offensiva', 'È offensiva o fuori luogo');

  const MotivoSegnalazione(this.valore, this.etichetta);

  /// Il valore accettato dal backend.
  final String valore;

  /// Come si legge nella lista dei motivi.
  final String etichetta;
}

/// Com'è andata una segnalazione.
///
/// La distinzione fra i tre casi è il motivo per cui questo non è un `void`:
/// «grazie», «l'avevi già segnalata» e «adesso è fuori dalla banca» sono tre
/// cose diverse da dire, e il client deve poterle dire senza leggere un
/// messaggio scritto dal server.
class EsitoSegnalazione {
  const EsitoSegnalazione({
    required this.segnalazioniTotali,
    required this.soglia,
    required this.disattivata,
    required this.giaSegnalata,
  });

  /// Quante segnalazioni pesano sulla domanda, questa compresa.
  final int segnalazioniTotali;

  /// Quante ne servono per disattivarla.
  final int soglia;

  /// Vero quando la domanda ha raggiunto la soglia: non verrà più pescata per
  /// i tabelloni nuovi. Resta però in quelli già creati, questo compreso.
  final bool disattivata;

  /// Vero quando questo dispositivo l'aveva già segnalata. **Non è un errore**:
  /// il server risponde 200 e non conta la segnalazione due volte.
  final bool giaSegnalata;

  /// Quante ne mancano alla disattivazione, mai negativo.
  int get mancanti =>
      disattivata ? 0 : (soglia - segnalazioniTotali).clamp(0, soglia);

  factory EsitoSegnalazione.fromJson(Map<String, dynamic> json) =>
      EsitoSegnalazione(
        segnalazioniTotali: json['segnalazioni_totali'] as int? ?? 0,
        soglia: json['soglia'] as int? ?? 0,
        disattivata: json['disattivata'] as bool? ?? false,
        giaSegnalata: json['gia_segnalata'] as bool? ?? false,
      );
}

/// Le segnalazioni sulla banca condivisa.
///
/// Sta fuori da `TabelloneRepository` di proposito: una segnalazione non
/// riguarda *questo* tabellone ma la domanda che sta dietro alla cella, ed è
/// visibile a chiunque la peschi altrove.
class SegnalazioneRepository {
  SegnalazioneRepository(this._api);

  final ApiClient _api;

  /// Segnala la domanda [domandaId].
  ///
  /// Il backend conta **una segnalazione per dispositivo**: risegnalare la
  /// stessa domanda risponde 200 con `giaSegnalata`, non un errore.
  Future<EsitoSegnalazione> segnala({
    required int domandaId,
    required MotivoSegnalazione motivo,
    String? nota,
  }) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/api/domande/$domandaId/segnalazioni',
        data: {
          'motivo': motivo.valore,
          if (nota != null && nota.trim().isNotEmpty) 'nota': nota.trim(),
        },
      );
      return EsitoSegnalazione.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      ApiClient.rilanciaComeErroreApi(e);
    }
  }
}
