import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/errore_api.dart';
import '../core/storage/cache_tabelloni.dart';
import '../models/tabellone.dart';

/// L'esito di una rigenerazione.
///
/// "Non ci sono altre domande per questa cella" non è un errore: su un
/// argomento stretto è un **esito atteso**. Il backend lo dice con un 200 e
/// `rigenerata: false`, non più con un 409, proprio perché la UI possa
/// trattarlo come tale senza doverlo pescare fra gli errori veri.
sealed class EsitoRigenerazione {
  const EsitoRigenerazione();
}

class RigenerazioneRiuscita extends EsitoRigenerazione {
  const RigenerazioneRiuscita(this.cella);
  final Cella cella;
}

/// La banca non ha altre domande per questo argomento.
///
/// Non porta con sé un messaggio: il `motivo` che arriva dal server è un
/// codice per il codice, e come raccontarlo a chi gioca lo decide la UI.
class NessunaAlternativa extends EsitoRigenerazione {
  const NessunaAlternativa();
}

class TabelloneRepository {
  TabelloneRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheTabelloni _cache;

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
      ApiClient.rilanciaComeErroreApi(e);
    }
  }

  /// Il tabellone, dalla rete quando c'è e dalla cache quando non c'è.
  ///
  /// La rete resta la prima scelta: il tabellone può essere stato corretto o
  /// rigenerato da un altro dispositivo. Ma se la rete manca e ne abbiamo una
  /// copia, si mostra quella — perché perdere il tabellone a metà partita per
  /// un wifi che salta è il guasto peggiore che questa app possa avere.
  Future<Tabellone> byCodice(String codicePubblico) async {
    try {
      final response = await _api.dio
          .get<Map<String, dynamic>>('/api/tabelloni/$codicePubblico');
      final json = response.data!;
      await _cache.salva(codicePubblico, json);
      return Tabellone.fromJson(json);
    } on DioException catch (e) {
      final errore = ErroreApi.da(e);
      // Solo per la rete. Un 404 significa che il tabellone non esiste, e
      // servire una copia vecchia sarebbe peggio che dire la verità.
      if (errore.genere == GenereErrore.rete) {
        final salvato = await _cache.leggi(codicePubblico);
        if (salvato != null) return Tabellone.fromJson(salvato);
      }
      throw errore;
    }
  }

  /// Da quando è ferma la copia locale, se ce n'è una.
  Future<DateTime?> cacheSalvataIl(String codicePubblico) =>
      _cache.salvatoIl(codicePubblico);

  /// Rigenera la domanda di una cella. Richiede il codice di modifica, quindi
  /// è disponibile solo a chi ha creato il tabellone.
  ///
  /// Costa una generazione del tetto giornaliero **solo se il modello
  /// risponde**: un tentativo andato a vuoto non se ne porta via una.
  Future<EsitoRigenerazione> rigeneraCella({
    required String codicePubblico,
    required String codiceModifica,
    required int cellaId,
  }) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/api/tabelloni/$codicePubblico/celle/$cellaId/rigenera',
        options: Options(headers: {'X-Codice-Modifica': codiceModifica}),
      );
      final corpo = response.data!;
      if (corpo['rigenerata'] as bool? ?? false) {
        return RigenerazioneRiuscita(
          Cella.fromJson(corpo['cella'] as Map<String, dynamic>),
        );
      }
      return const NessunaAlternativa();
    } on DioException catch (e) {
      throw ErroreApi.da(e);
    }
  }

  /// Corregge a mano testo e risposta di una singola cella.
  ///
  /// È l'unica uscita che funziona **sempre**: quando la banca è esaurita la
  /// rigenerazione restituisce 409 per quante volte si insista, e senza questa
  /// un tabellone con una cella rotta resterebbe rotto per sempre.
  ///
  /// Il backend scrive override sulla cella e non tocca la domanda condivisa,
  /// quindi la correzione non si propaga ad altri tabelloni.
  Future<Tabellone> correggiCella({
    required String codicePubblico,
    required String codiceModifica,
    required int cellaId,
    required String testo,
    required String risposta,
  }) async {
    try {
      final response = await _api.dio.put<Map<String, dynamic>>(
        '/api/tabelloni/$codicePubblico',
        options: Options(headers: {'X-Codice-Modifica': codiceModifica}),
        data: {
          'celle': [
            {'id': cellaId, 'testo': testo, 'risposta': risposta},
          ],
        },
      );
      final json = response.data!;
      await _cache.salva(codicePubblico, json);
      return Tabellone.fromJson(json);
    } on DioException catch (e) {
      ApiClient.rilanciaComeErroreApi(e);
    }
  }

  Future<List<TabelloneSintesi>> miei() async {
    try {
      final response = await _api.dio.get<List<dynamic>>('/api/tabelloni');
      return (response.data ?? [])
          .map((t) => TabelloneSintesi.fromJson(t as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      ApiClient.rilanciaComeErroreApi(e);
    }
  }
}
