import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/client_id_storage.dart';
import 'errore_api.dart';

/// Indirizzo del backend; sovrascrivibile in fase di build con
/// --dart-define=API_BASE_URL=https://...
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

class ApiClient {
  ApiClient({required ClientIdStorage clientIdStorage})
      : _dio = Dio(
          BaseOptions(
            baseUrl: apiBaseUrl,
            // E4: senza timeout, se il server si impianta il client resta
            // appeso per sempre. La creazione di un tabellone e' sincrona lato
            // backend (N chiamate al modello in serie, piu' le attese fra i
            // tentativi), quindi la ricezione ha un tetto largo; la connessione
            // no, perche' un wifi caduto si riconosce subito.
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(minutes: 3),
            sendTimeout: const Duration(seconds: 30),
          ),
        )..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) async {
                options.headers['X-Client-Id'] =
                    await clientIdStorage.getOrCreateClientId();
                handler.next(options);
              },
            ),
          );

  final Dio _dio;

  Dio get dio => _dio;

  /// Sveglia il backend senza aspettarlo.
  ///
  /// In produzione il servizio scende a zero istanze quando nessuno gioca, e
  /// paga l'avvio della JVM alla prima richiesta: misurato, sono una ventina
  /// di secondi. Se la prima richiesta è quella con cui l'host crea davvero un
  /// tabellone, quei secondi se li aspetta lui guardando uno schermo fermo.
  ///
  /// Chiamando questo all'apertura dell'app, il container si scalda mentre
  /// l'host è ancora sulla home a scegliere gli argomenti, e quando preme il
  /// pulsante il server è già in piedi.
  ///
  /// Non attende e non solleva: se la rete non c'è, non è successo niente —
  /// se ne accorgerà la prima richiesta vera, che sa già come raccontarlo.
  void risveglia() {
    unawaited(
      _dio
          .get<void>(
            '/api/salute/vivo',
            options: Options(receiveTimeout: const Duration(seconds: 45)),
          )
          .then((_) {}, onError: (_) {}),
    );
  }

  /// Trasforma un errore di Dio in un [ErroreApi], che la UI sa raccontare.
  static Never rilanciaComeErroreApi(DioException e) => throw ErroreApi.da(e);
}
