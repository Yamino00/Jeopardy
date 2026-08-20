import 'package:flutter/material.dart';

import '../api/errore_api.dart';
import '../design/design.dart';

/// Come si racconta un errore, in tutta l'app.
///
/// Sostituisce **cinque `Text('$e')`** in cinque schermate, che davano lo
/// stesso trattamento a un wifi caduto, a un codice sbagliato e alla quota
/// esaurita — e che in un caso (`partita_page`) non avevano nemmeno una barra
/// in alto o un modo per tornare indietro: un errore sul tabellone era un
/// vicolo cieco da cui si usciva solo col tasto di sistema.
///
/// Tre regole:
///
/// 1. **Il titolo dice cosa è successo**, e non è il messaggio del server: un
///    Problem Detail è scritto per chi sviluppa.
/// 2. **C'è sempre un rimedio scritto**, perché dire cosa è andato storto senza
///    dire come uscirne lascia l'utente dove l'ha trovato.
/// 3. **Riprova compare solo se ha senso.** Su un 404 riprovare darebbe lo
///    stesso esito, e un pulsante che non può funzionare è peggio della sua
///    assenza.
class StatoErrore extends StatelessWidget {
  const StatoErrore({
    super.key,
    required this.errore,
    this.onRiprova,
    this.onIndietro,
    this.compatto = false,
  });

  /// Qualunque cosa sia arrivata: se non è un [ErroreApi] viene comunque
  /// mostrata con dignità invece di finire in un `toString()` grezzo.
  final Object errore;

  final VoidCallback? onRiprova;

  /// L'uscita. Su una schermata a tutto schermo è obbligatoria, altrimenti
  /// l'errore diventa un vicolo cieco.
  final VoidCallback? onIndietro;

  /// Dentro una lista invece che a tutto schermo.
  final bool compatto;

  ErroreApi get _errore => errore is ErroreApi
      ? errore as ErroreApi
      : ErroreApi(
          genere: GenereErrore.server,
          messaggio: errore.toString(),
        );

  @override
  Widget build(BuildContext context) {
    final e = _errore;
    final mostraRiprova = onRiprova != null && e.vaLaPenaRiprovare;

    final contenuto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icona(e.genere), color: Colori.segnale),
            const SizedBox(width: Misure.s3),
            Expanded(
              child: Text(
                e.titolo,
                style: Tipografia.corpoRilievo.copyWith(color: Colori.segnale),
              ),
            ),
          ],
        ),
        const SizedBox(height: Misure.s3),
        Text(e.rimedio, style: Tipografia.corpo),
        if (mostraRiprova || onIndietro != null) ...[
          const SizedBox(height: Misure.s4),
          Wrap(
            spacing: Misure.s3,
            runSpacing: Misure.s2,
            children: [
              if (mostraRiprova)
                FilledButton.icon(
                  key: const Key('riprova'),
                  onPressed: onRiprova,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Riprova'),
                ),
              if (onIndietro != null)
                OutlinedButton(
                  key: const Key('errore-indietro'),
                  onPressed: onIndietro,
                  child: const Text('Torna indietro'),
                ),
            ],
          ),
        ],
      ],
    );

    final riquadro = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Misure.s4),
      decoration: BoxDecoration(
        // Bordo pieno, nessun riempimento traslucido: un colore al 8% di
        // opacità su fondo scuro è esattamente il tipo di contrasto che
        // l'audit contestava.
        border: Border.all(color: Colori.segnale),
        borderRadius: Misure.bordoCartellino,
      ),
      child: contenuto,
    );

    // `liveRegion`: chi usa uno screen reader deve sapere che è comparso un
    // errore senza doverlo cercare.
    final semantico = Semantics(
      liveRegion: true,
      label: '${e.titolo}. ${e.rimedio}',
      child: riquadro,
    );

    if (compatto) return semantico;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Misure.s5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Misure.larghezzaLettura),
          child: semantico,
        ),
      ),
    );
  }

  IconData _icona(GenereErrore genere) => switch (genere) {
        GenereErrore.rete => Icons.wifi_off_rounded,
        GenereErrore.nonTrovato => Icons.search_off_rounded,
        GenereErrore.conflitto => Icons.block_rounded,
        GenereErrore.quota => Icons.hourglass_disabled_rounded,
        GenereErrore.richiesta => Icons.error_outline_rounded,
        GenereErrore.server => Icons.cloud_off_rounded,
      };
}

/// Il messaggio breve per un'azione fallita a partita in corso.
///
/// Non è un errore di schermata: la partita continua, e va detto in una riga
/// senza portare via il tabellone. Le condizioni **attese** — annullare quando
/// non c'è niente da annullare — passano di qui come informazione neutra, non
/// come guasto.
SnackBar barraErrore(Object errore) {
  final e = errore is ErroreApi
      ? errore
      : ErroreApi(genere: GenereErrore.server, messaggio: errore.toString());
  return SnackBar(
    content: Text(e.atteso ? e.messaggio : '${e.titolo} · ${e.rimedio}'),
    behavior: SnackBarBehavior.floating,
  );
}
