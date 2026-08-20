/// Che tipo di evento è stato registrato.
enum TipoEvento {
  cellaGiocata('cella_giocata'),
  correzione('correzione');

  const TipoEvento(this.valore);
  final String valore;

  static TipoEvento da(String? v) => TipoEvento.values.firstWhere(
        (t) => t.valore == v,
        orElse: () => TipoEvento.cellaGiocata,
      );
}

/// Un evento del registro della partita.
///
/// **Il backend lo restituisce da sempre**, sia da `giocaCella` sia da
/// `annulla`, e il frontend lo scartava per rifare una GET completa (D4). La
/// conseguenza diretta: l'annulla non poteva dire *cosa* aveva annullato,
/// benché il server glielo avesse appena detto. Con un host che sbaglia ad
/// assegnare i punti — il caso d'uso dichiarato nel brief — era l'informazione
/// più preziosa dell'app, buttata.
class EventoPartita {
  const EventoPartita({
    required this.id,
    required this.tipo,
    required this.annullato,
    this.squadraId,
    this.deltaPunti,
  });

  final int id;
  final TipoEvento tipo;
  final bool annullato;
  final int? squadraId;
  final int? deltaPunti;

  factory EventoPartita.fromJson(Map<String, dynamic> json) => EventoPartita(
        id: json['id'] as int,
        tipo: TipoEvento.da(json['tipo'] as String?),
        annullato: json['annullato'] as bool? ?? false,
        squadraId: json['squadra_id'] as int?,
        deltaPunti: json['delta_punti'] as int?,
      );

  /// Come si racconta l'evento a chi guarda, dato il nome della squadra.
  ///
  /// Il nome arriva da fuori perché l'evento porta solo l'id: il DTO non
  /// contiene né la squadra per esteso né la cella, quindi si dice quello che
  /// si sa davvero — squadra e punti — e non si inventa la categoria.
  String descrizione(String? nomeSquadra) {
    final delta = deltaPunti ?? 0;
    if (nomeSquadra == null || delta == 0) return 'ultima azione';
    final segno = delta > 0 ? '+' : '−';
    return '$nomeSquadra $segno${delta.abs()}';
  }
}
