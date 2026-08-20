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

  /// Trasforma un errore di Dio in un [ErroreApi], che la UI sa raccontare.
  static Never rilanciaComeErroreApi(DioException e) => throw ErroreApi.da(e);
}
