/// Read models for the board API. The backend serializes snake_case.
class Tabellone {
  const Tabellone({
    required this.codicePubblico,
    required this.titolo,
    required this.righe,
    required this.puntiBase,
    required this.categorie,
    this.codiceModifica,
  });

  final String codicePubblico;

  /// Present only in the creation response; never expose it in the UI
  /// beyond the "save this code" hint.
  final String? codiceModifica;
  final String titolo;
  final int righe;
  final int puntiBase;
  final List<Categoria> categorie;

  factory Tabellone.fromJson(Map<String, dynamic> json) => Tabellone(
        codicePubblico: json['codice_pubblico'] as String,
        codiceModifica: json['codice_modifica'] as String?,
        titolo: json['titolo'] as String,
        righe: json['righe'] as int,
        puntiBase: json['punti_base'] as int,
        categorie: (json['categorie'] as List<dynamic>? ?? [])
            .map((c) => Categoria.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  Cella? cellaById(int id) {
    for (final categoria in categorie) {
      for (final cella in categoria.celle) {
        if (cella.id == id) return cella;
      }
    }
    return null;
  }
}

class Categoria {
  const Categoria({
    required this.id,
    required this.nomeDisplay,
    required this.posizione,
    required this.celle,
  });

  final int id;
  final String nomeDisplay;
  final int posizione;
  final List<Cella> celle;

  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
        id: json['id'] as int,
        nomeDisplay: json['nome_display'] as String,
        posizione: json['posizione'] as int,
        celle: (json['celle'] as List<dynamic>? ?? [])
            .map((c) => Cella.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class Cella {
  const Cella({
    required this.id,
    required this.riga,
    required this.valore,
    required this.dailyDouble,
    this.testo,
    this.risposta,
  });

  final int id;
  final int riga;
  final int valore;
  final bool dailyDouble;
  final String? testo;
  final String? risposta;

  factory Cella.fromJson(Map<String, dynamic> json) => Cella(
        id: json['id'] as int,
        riga: json['riga'] as int,
        valore: json['valore'] as int,
        dailyDouble: json['daily_double'] as bool? ?? false,
        testo: json['testo'] as String?,
        risposta: json['risposta'] as String?,
      );
}

class TabelloneSintesi {
  const TabelloneSintesi({
    required this.codicePubblico,
    required this.titolo,
    required this.righe,
    required this.puntiBase,
  });

  final String codicePubblico;
  final String titolo;
  final int righe;
  final int puntiBase;

  factory TabelloneSintesi.fromJson(Map<String, dynamic> json) =>
      TabelloneSintesi(
        codicePubblico: json['codice_pubblico'] as String,
        titolo: json['titolo'] as String,
        righe: json['righe'] as int,
        puntiBase: json['punti_base'] as int,
      );
}
