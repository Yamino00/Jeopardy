/// Read models for the game API. The backend serializes snake_case.
class Partita {
  const Partita({
    required this.id,
    required this.codiceTabellone,
    required this.stato,
    required this.squadre,
    required this.celleGiocate,
    this.turnoSquadraId,
  });

  final int id;
  final String codiceTabellone;
  final String stato;
  final int? turnoSquadraId;
  final List<Squadra> squadre;
  final List<CellaGiocata> celleGiocate;

  bool get inCorso => stato == 'in_corso';

  List<Squadra> get squadreAttive =>
      squadre.where((s) => s.attiva).toList(growable: false);

  bool cellaGiaGiocata(int cellaId) =>
      celleGiocate.any((c) => c.cellaId == cellaId);

  /// Una chiave confrontabile per valore delle celle giocate.
  ///
  /// Serve a `select` (S1): due `List` con lo stesso contenuto non sono uguali
  /// fra loro, quindi selezionare la lista farebbe ricostruire la griglia a
  /// ogni azione — compreso un cambio di punteggio, che alla griglia non
  /// interessa. Una stringa invece si confronta per valore.
  String get chiaveCelleGiocate {
    final id = celleGiocate.map((c) => c.cellaId).toList()..sort();
    return id.join(',');
  }

  /// Idem per il podio: nome, punteggio, colore e turno di ogni squadra attiva.
  String get chiaveSquadre {
    final parti = [
      for (final s in squadreAttive)
        '${s.id}:${s.nome}:${s.punteggio}:${s.colore}',
      'turno=$turnoSquadraId',
      'stato=$stato',
    ];
    return parti.join('|');
  }

  factory Partita.fromJson(Map<String, dynamic> json) => Partita(
        id: json['id'] as int,
        codiceTabellone: json['codice_tabellone'] as String,
        stato: json['stato'] as String,
        turnoSquadraId: json['turno_squadra_id'] as int?,
        squadre: (json['squadre'] as List<dynamic>? ?? [])
            .map((s) => Squadra.fromJson(s as Map<String, dynamic>))
            .toList(),
        celleGiocate: (json['celle_giocate'] as List<dynamic>? ?? [])
            .map((c) => CellaGiocata.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class Squadra {
  const Squadra({
    required this.id,
    required this.nome,
    required this.punteggio,
    required this.posizione,
    required this.attiva,
    this.colore,
  });

  final int id;
  final String nome;
  final String? colore;
  final int punteggio;
  final int posizione;
  final bool attiva;

  factory Squadra.fromJson(Map<String, dynamic> json) => Squadra(
        id: json['id'] as int,
        nome: json['nome'] as String,
        colore: json['colore'] as String?,
        punteggio: json['punteggio'] as int,
        posizione: json['posizione'] as int,
        attiva: json['attiva'] as bool? ?? true,
      );
}

class CellaGiocata {
  const CellaGiocata({
    required this.cellaId,
    this.squadraId,
    this.esito,
  });

  final int cellaId;
  final int? squadraId;
  final String? esito;

  factory CellaGiocata.fromJson(Map<String, dynamic> json) => CellaGiocata(
        cellaId: json['cella_id'] as int,
        squadraId: json['squadra_id'] as int?,
        esito: json['esito'] as String?,
      );
}
