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
    this.domandaId,
    this.testo,
    this.risposta,
  });

  final int id;

  /// L'id della domanda nella banca condivisa, quando la cella ne ha una.
  ///
  /// È la chiave che rende raggiungibile `POST /api/domande/{id}/segnalazioni`:
  /// finché `CellaDto` non lo esponeva, l'endpoint di segnalazione esisteva
  /// lato server ma nessun client poteva chiamarlo.
  ///
  /// Nullo per le celle segnaposto — quelle che la deduplicazione ha lasciato
  /// vuote — e nei tabelloni serviti da una cache salvata prima di questo
  /// campo. In entrambi i casi non c'è niente da segnalare.
  final int? domandaId;

  final int riga;
  final int valore;
  final bool dailyDouble;
  final String? testo;
  final String? risposta;

  /// Vero quando questa cella può essere segnalata: c'è una domanda condivisa
  /// dietro, ed è una domanda vera e non un segnaposto.
  bool get segnalabile => domandaId != null && !senzaDomanda;

  /// Vero quando la cella non ha una domanda utilizzabile.
  ///
  /// **I tabelloni creati da oggi non ne hanno.** Il backend prima scriveva un
  /// segnaposto (`testoOverride = "Domanda da completare"`,
  /// `rispostaOverride = ""`) quando la deduplicazione non lasciava abbastanza
  /// domande; adesso ripiega sulla banca e, se davvero non c'è niente, si
  /// rifiuta di creare un tabellone bucato. Questo resta perché i tabelloni
  /// creati prima quel segnaposto ce l'hanno ancora dentro, e perché una cache
  /// locale può servirne uno.
  ///
  /// Il segnale è la **risposta vuota**, non il testo: il testo del vecchio
  /// segnaposto era configurabile lato backend, mentre una domanda vera ha
  /// sempre una risposta. Confrontare la stringa sarebbe stato un
  /// accoppiamento a una configurazione che non controlliamo.
  bool get senzaDomanda =>
      risposta == null || risposta!.trim().isEmpty ||
      testo == null || testo!.trim().isEmpty;

  factory Cella.fromJson(Map<String, dynamic> json) => Cella(
        id: json['id'] as int,
        domandaId: json['domanda_id'] as int?,
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
