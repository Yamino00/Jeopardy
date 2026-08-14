import 'package:dio/dio.dart';

import '../storage/client_id_storage.dart';

class ApiClient {
  ApiClient({required ClientIdStorage clientIdStorage})
      : _dio = Dio()
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
}
