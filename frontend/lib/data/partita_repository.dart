import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../models/partita.dart';

class PartitaRepository {
  PartitaRepository(this._api);

  final ApiClient _api;

  Future<Partita> avvia(String codiceTabellone,
      List<({String nome, String? colore})> squadre) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/api/tabelloni/$codiceTabellone/partite',
        data: {
          'squadre': [
            for (final s in squadre) {'nome': s.nome, 'colore': s.colore},
          ],
        },
      );
      return Partita.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.rethrowAsApiException(e);
    }
  }

  Future<Partita> byId(int id) async {
    try {
      final response =
          await _api.dio.get<Map<String, dynamic>>('/api/partite/$id');
      return Partita.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.rethrowAsApiException(e);
    }
  }

  Future<void> giocaCella({
    required int partitaId,
    required int cellaId,
    required String esito,
    required int deltaPunti,
    int? squadraId,
  }) async {
    try {
      await _api.dio.post<void>(
        '/api/partite/$partitaId/celle/$cellaId',
        data: {
          'squadra_id': squadraId,
          'esito': esito,
          'delta_punti': deltaPunti,
        },
      );
    } on DioException catch (e) {
      ApiClient.rethrowAsApiException(e);
    }
  }

  Future<Squadra> aggiungiSquadra(int partitaId, String nome,
      {String? colore}) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/api/partite/$partitaId/squadre',
        data: {'nome': nome, 'colore': colore},
      );
      return Squadra.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.rethrowAsApiException(e);
    }
  }

  Future<Squadra> aggiornaSquadra(
    int partitaId,
    int squadraId, {
    String? nome,
    String? colore,
    int? punteggio,
  }) async {
    try {
      final response = await _api.dio.patch<Map<String, dynamic>>(
        '/api/partite/$partitaId/squadre/$squadraId',
        data: {
          if (nome != null) 'nome': nome,
          if (colore != null) 'colore': colore,
          if (punteggio != null) 'punteggio': punteggio,
        },
      );
      return Squadra.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.rethrowAsApiException(e);
    }
  }

  Future<void> rimuoviSquadra(int partitaId, int squadraId) async {
    try {
      await _api.dio.delete<void>('/api/partite/$partitaId/squadre/$squadraId');
    } on DioException catch (e) {
      ApiClient.rethrowAsApiException(e);
    }
  }

  Future<void> annulla(int partitaId) async {
    try {
      await _api.dio.post<void>('/api/partite/$partitaId/annulla');
    } on DioException catch (e) {
      ApiClient.rethrowAsApiException(e);
    }
  }

  Future<Partita> concludi(int partitaId) async {
    try {
      final response = await _api.dio
          .post<Map<String, dynamic>>('/api/partite/$partitaId/concludi');
      return Partita.fromJson(response.data!);
    } on DioException catch (e) {
      ApiClient.rethrowAsApiException(e);
    }
  }
}
