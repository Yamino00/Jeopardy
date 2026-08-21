import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Cosa è successo all'ultimo tentativo di rigenerazione.
enum EsitoTentativo {
  /// Non si è ancora provato.
  nessuno,

  /// In corso: la generazione IA richiede decine di secondi.
  inCorso,

  /// La banca non ha altre domande per questo argomento. **Non è un errore** —
  /// il backend lo dice con un 200 e `rigenerata: false`, ed è un esito atteso
  /// su un argomento stretto: l'unica via che resta è scriverla a mano.
  esaurita,

  /// Errore vero (rete, permessi, 5xx).
  errore,
}

/// La cella che il backend non è riuscito a riempire.
///
/// **I tabelloni nuovi non ne hanno più.** `TabelloneService` prima scriveva un
/// segnaposto quando la deduplicazione non lasciava abbastanza domande; adesso
/// ripiega sulla banca e, se davvero non c'è niente, rifiuta di creare un
/// tabellone bucato. Questo schermo resta per i tabelloni creati prima, che
/// quel segnaposto ce l'hanno ancora dentro, e perché la correzione a mano è
/// comunque l'uscita per una domanda semplicemente sbagliata.
///
/// È uno **stato riconosciuto**, e degrada in tre passi, nell'ordine in cui
/// possono fallire:
///
/// 1. rigenerare — che costa una generazione del tetto giornaliero solo se il
///    modello risponde davvero;
/// 2. l'esaurimento come esito atteso, non come snackbar rossa col testo del
///    server;
/// 3. la correzione a mano, che è l'unica uscita che funziona sempre.
///
/// Le prime due richiedono il codice di modifica, quindi esistono solo sul
/// dispositivo che ha creato il tabellone. Chi gioca su un tabellone altrui
/// vede lo stato e può solo passare la cella — che è la verità, non una
/// limitazione da nascondere.
class CellaSenzaDomanda extends StatelessWidget {
  const CellaSenzaDomanda({
    super.key,
    required this.nomeCategoria,
    required this.valore,
    required this.puoRiparare,
    required this.esito,
    required this.messaggioErrore,
    required this.onChiudi,
    required this.onRigenera,
    required this.onCorreggi,
    required this.onPassa,
  });

  final String nomeCategoria;
  final int valore;

  /// Vero solo se questo dispositivo ha il codice di modifica del tabellone.
  final bool puoRiparare;

  final EsitoTentativo esito;
  final String? messaggioErrore;

  final VoidCallback onChiudi;
  final VoidCallback onRigenera;
  final VoidCallback onCorreggi;
  final VoidCallback onPassa;

  bool get _inCorso => esito == EsitoTentativo.inCorso;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colori.quadro,
        // Bordo Segnale e non Ottone: qui non c'è niente in gioco, c'è la
        // macchina che si fa sentire. Il caldo è il gioco, e questo non lo è.
        border: Border.all(color: Colori.segnale, width: Misure.bordoLuce),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Misure.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${nomeCategoria.toUpperCase()} · $valore',
                      style: Tipografia.ferramenta,
                    ),
                  ),
                  IconButton(
                    key: const Key('chiudi-cella-rotta'),
                    onPressed: _inCorso ? null : onChiudi,
                    tooltip: 'Chiudi',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: Misure.larghezzaLettura,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Questa cella non ha una domanda',
                            style: Tipografia.domanda(
                                Tipografia.domandaMinima),
                          ),
                          const SizedBox(height: Misure.s4),
                          Text(_spiegazione(), style: Tipografia.corpo),
                          if (esito == EsitoTentativo.errore &&
                              messaggioErrore != null) ...[
                            const SizedBox(height: Misure.s4),
                            _Avviso(testo: messaggioErrore!),
                          ],
                          const SizedBox(height: Misure.s5),
                          ..._azioni(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _spiegazione() => switch (esito) {
        EsitoTentativo.inCorso =>
          'Sto cercando una domanda nuova. La generazione richiede qualche '
              'decina di secondi: puoi lasciare aperta questa schermata.',
        EsitoTentativo.esaurita =>
          'Non ci sono altre domande per questo argomento: la banca è esaurita '
              'e insistere darebbe sempre lo stesso esito, consumando quota. '
              'Scrivila a mano — è l\'unica via che funziona sempre.',
        EsitoTentativo.errore =>
          'Il tentativo di rigenerazione non è andato a buon fine.',
        EsitoTentativo.nessuno => puoRiparare
            ? 'La generazione non ha trovato abbastanza domande per riempirla. '
                'Puoi provare a rigenerarla o scriverla a mano.'
            : 'La generazione non ha trovato abbastanza domande per riempirla. '
                'Può ripararla solo il dispositivo che ha creato il tabellone; '
                'da qui puoi passare la cella e continuare la partita.',
      };

  List<Widget> _azioni(BuildContext context) {
    if (_inCorso) {
      return [
        const Row(
          children: [
            SizedBox(
              width: Misure.s5,
              height: Misure.s5,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: Misure.s4),
            Expanded(child: Text('Generazione in corso…')),
          ],
        ),
      ];
    }

    return [
      if (puoRiparare) ...[
        // La rigenerazione non si presenta come un retry gratuito.
        if (esito != EsitoTentativo.esaurita) ...[
          FilledButton.icon(
            key: const Key('rigenera-cella'),
            onPressed: onRigenera,
            icon: const Icon(Icons.autorenew_rounded),
            label: const Text('Rigenera la domanda'),
          ),
          const SizedBox(height: Misure.s2),
          const Text(
            'Consuma una delle generazioni giornaliere solo se l\'IA '
            'risponde.',
            style: Tipografia.ferramenta,
          ),
          const SizedBox(height: Misure.s4),
        ],
        OutlinedButton.icon(
          key: const Key('correggi-cella'),
          onPressed: onCorreggi,
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Scrivila a mano'),
        ),
        const SizedBox(height: Misure.s4),
      ],
      TextButton(
        key: const Key('passa-cella-rotta'),
        onPressed: onPassa,
        child: const Text('Passa questa cella'),
      ),
    ];
  }
}

class _Avviso extends StatelessWidget {
  const _Avviso({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Misure.s3),
      decoration: BoxDecoration(
        borderRadius: Misure.bordoCartellino,
        border: Border.all(color: Colori.segnale),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colori.segnale),
          const SizedBox(width: Misure.s3),
          Expanded(
            child: Text(
              testo,
              style: Tipografia.corpo.copyWith(color: Colori.segnale),
            ),
          ),
        ],
      ),
    );
  }
}

/// Il dialog di correzione manuale: due campi, non una sesta schermata.
///
/// Restituisce `(testo, risposta)` oppure `null` se annullato.
class DialogCorrezioneCella extends StatefulWidget {
  const DialogCorrezioneCella({
    super.key,
    required this.nomeCategoria,
    required this.valore,
    this.testoIniziale = '',
    this.rispostaIniziale = '',
  });

  final String nomeCategoria;
  final int valore;
  final String testoIniziale;
  final String rispostaIniziale;

  @override
  State<DialogCorrezioneCella> createState() => _DialogCorrezioneCellaState();
}

class _DialogCorrezioneCellaState extends State<DialogCorrezioneCella> {
  late final TextEditingController _testo;
  late final TextEditingController _risposta;

  @override
  void initState() {
    super.initState();
    _testo = TextEditingController(text: widget.testoIniziale);
    _risposta = TextEditingController(text: widget.rispostaIniziale);
    // I controller vengono disposti: nel codice precedente tre dialog ne
    // creavano uno per ogni apertura e non li disponevano mai (E6).
    _testo.addListener(_aggiorna);
    _risposta.addListener(_aggiorna);
  }

  void _aggiorna() => setState(() {});

  @override
  void dispose() {
    _testo.dispose();
    _risposta.dispose();
    super.dispose();
  }

  bool get _valido =>
      _testo.text.trim().isNotEmpty && _risposta.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scrivi la domanda'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Misure.larghezzaLettura),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.nomeCategoria.toUpperCase()} · ${widget.valore}',
                style: Tipografia.ferramenta,
              ),
              const SizedBox(height: Misure.s4),
              TextField(
                key: const Key('campo-testo-cella'),
                controller: _testo,
                autofocus: true,
                maxLines: 4,
                minLines: 2,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Domanda',
                  hintText: 'Questa città fu fondata nel 753 a.C.',
                ),
              ),
              const SizedBox(height: Misure.s4),
              TextField(
                key: const Key('campo-risposta-cella'),
                controller: _risposta,
                decoration: const InputDecoration(
                  labelText: 'Risposta',
                  hintText: 'Roma',
                ),
              ),
              const SizedBox(height: Misure.s3),
              const Text(
                'La correzione vale solo per questo tabellone: non modifica la '
                'domanda condivisa con gli altri.',
                style: Tipografia.ferramenta,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('salva-correzione'),
          onPressed: _valido
              ? () => Navigator.of(context).pop(
                    (testo: _testo.text.trim(), risposta: _risposta.text.trim()),
                  )
              : null,
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
