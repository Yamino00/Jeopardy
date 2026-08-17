import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../models/tabellone.dart';

class TabelloneRepository {
  TabelloneRepository(this._api);

  final ApiClient _api;

  Future<Tabellone> crea({
    required String titolo,
    required List<String> argomenti,
    required int righe,
    required int puntiBase,
  }) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/api/tabelloni',
        data: {
          'titolo': titolo,
          'argomenti': argomenti,
          'righe': righe,
          'punti_base': puntiBase,
        },
      );
      return Tabellone.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.rethrowAsApiException(e);
    }
  }

  Future<Tabellone> byCodice(String codicePubblico) async {
    try {
      final response = await _api.dio
          .get<Map<String, dynamic>>('/api/tabelloni/$codicePubblico');
      return Tabellone.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.rethrowAsApiException(e);
    }
  }

  Future<List<TabelloneSintesi>> miei() async {
    try {
      final response = await _api.dio.get<List<dynamic>>('/api/tabelloni');
      return (response.data ?? [])
          .map((t) => TabelloneSintesi.fromJson(t as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiClient.rethrowAsApiException(e);
    }
  }
}
