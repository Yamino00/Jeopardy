import 'partita.dart';

/// Una giocata fatta dall'host e **non ancora arrivata al server**.
///
/// È un *intento*, non un evento: l'evento lo crea il backend, che gli assegna
/// un id e ricalcola il punteggio dal proprio registro. Qui si conserva soltanto
/// cosa l'host ha voluto fare, in ordine, così da poterlo rigiocare tale e quale
/// quando la rete torna.
///
/// **Perché rigiocare in ordine basta.** Il backend calcola il punteggio come
/// somma dei delta degli eventi non annullati: è già un registro. Se le azioni
/// locali gli arrivano nella stessa sequenza in cui l'host le ha compiute, lo
/// stato converge da sé — non c'è nessuna regola di risoluzione dei conflitti da
/// inventare, ed è la ragione per cui questa classe è così piccola.
class AzioneLocale {
  const AzioneLocale({
    required this.idLocale,
    required this.cellaId,
    required this.esito,
    required this.deltaPunti,
    required this.quando,
    this.squadraId,
  });

  /// Identità stabile fra un tentativo e l'altro: serve a togliere dalla coda
  /// esattamente l'azione confermata, anche se nel frattempo ne sono arrivate
  /// altre.
  final String idLocale;

  final int cellaId;
  final String esito;
  final int deltaPunti;
  final int? squadraId;
  final DateTime quando;

  Map<String, dynamic> toJson() => {
        'id_locale': idLocale,
        'cella_id': cellaId,
        'esito': esito,
        'delta_punti': deltaPunti,
        'squadra_id': squadraId,
        'quando': quando.toIso8601String(),
      };

  factory AzioneLocale.fromJson(Map<String, dynamic> json) => AzioneLocale(
        idLocale: json['id_locale'] as String,
        cellaId: json['cella_id'] as int,
        esito: json['esito'] as String,
        deltaPunti: json['delta_punti'] as int,
        squadraId: json['squadra_id'] as int?,
        quando: DateTime.parse(json['quando'] as String),
      );
}

/// Applica le azioni in attesa a uno stato del server, per ottenere quello che
/// l'host deve vedere adesso.
///
/// È una **proiezione**, non una verità: la verità resta il backend. Serve
/// perché senza rete il tabellone deve comunque reagire al tocco — altrimenti
/// l'host tocca una cella e non succede niente, e in salotto quello sembra un
/// guasto dell'app, non della connessione.
///
/// Funzione pura, e per questo verificabile senza montare niente.
Partita proietta(Partita sincronizzata, List<AzioneLocale> inAttesa) {
  if (inAttesa.isEmpty) return sincronizzata;

  final celle = [...sincronizzata.celleGiocate];
  final punti = <int, int>{
    for (final s in sincronizzata.squadre) s.id: s.punteggio,
  };

  for (final azione in inAttesa) {
    if (!celle.any((c) => c.cellaId == azione.cellaId)) {
      celle.add(CellaGiocata(cellaId: azione.cellaId));
    }
    final squadra = azione.squadraId;
    if (squadra != null && punti.containsKey(squadra)) {
      punti[squadra] = punti[squadra]! + azione.deltaPunti;
    }
  }

  return Partita(
    id: sincronizzata.id,
    codiceTabellone: sincronizzata.codiceTabellone,
    stato: sincronizzata.stato,
    turnoSquadraId: sincronizzata.turnoSquadraId,
    squadre: [
      for (final s in sincronizzata.squadre)
        Squadra(
          id: s.id,
          nome: s.nome,
          punteggio: punti[s.id] ?? s.punteggio,
          posizione: s.posizione,
          attiva: s.attiva,
          colore: s.colore,
        ),
    ],
    celleGiocate: celle,
  );
}
