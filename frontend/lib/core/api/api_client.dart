import 'package:dio/dio.dart';

import '../storage/client_id_storage.dart';

/// Base URL of the backend; overridable at build time with
/// --dart-define=API_BASE_URL=https://...
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

/// Error the UI can show as-is: carries the Problem Detail message
/// returned by the backend when available.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int? statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required ClientIdStorage clientIdStorage})
      : _dio = Dio(BaseOptions(baseUrl: apiBaseUrl))
          ..interceptors.add(
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

  /// Unwraps Dio errors into [ApiException] with the backend's
  /// Problem Detail message when present.
  static Never rethrowAsApiException(DioException e) {
    final data = e.response?.data;
    String message = 'Errore di rete: il server non risponde';
    if (data is Map && data['detail'] is String) {
      message = data['detail'] as String;
    } else if (e.response != null) {
      message = 'Errore ${e.response!.statusCode}';
    }
    throw ApiException(e.response?.statusCode, message);
  }
}
