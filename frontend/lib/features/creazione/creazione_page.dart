import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/widgets/stato_errore.dart';
import '../../data/generazione_notifier.dart';

/// Creazione di un tabellone: titolo, argomenti, righe, punti.
///
/// L'attesa è la parte difficile di questa schermata — decine di secondi — e
/// CLAUDE.md chiede che sia **progettata, non nascosta dietro uno spinner**.
/// Lo stato però non vive qui: sta in [generazioneProvider], così uscendo dalla
/// schermata la generazione non diventa inosservabile (S2).
class CreazionePage extends ConsumerStatefulWidget {
  const CreazionePage({super.key});

  @override
  ConsumerState<CreazionePage> createState() => _CreazionePageState();
}

class _CreazionePageState extends ConsumerState<CreazionePage> {
  final _titoloController = TextEditingController();
  final _argomentoController = TextEditingController();
  final List<String> _argomenti = [];
  int _righe = 5;
  int _puntiBase = 100;
  String? _erroreModulo;

  static const int _maxArgomenti = 6;

  @override
  void dispose() {
    _titoloController.dispose();
    _argomentoController.dispose();
    super.dispose();
  }

  void _aggiungiArgomento() {
    final valore = _argomentoController.text.trim();
    if (valore.isEmpty || _argomenti.length >= _maxArgomenti) return;
    if (_argomenti.any((a) => a.toLowerCase() == valore.toLowerCase())) return;
    setState(() {
      _argomenti.add(valore);
      _argomentoController.clear();
    });
  }

  Future<void> _crea() async {
    final titolo = _titoloController.text.trim();
    if (titolo.isEmpty || _argomenti.isEmpty) {
      setState(() => _erroreModulo =
          'Servono un titolo e almeno un argomento per iniziare');
      return;
    }
    setState(() => _erroreModulo = null);
    await ref.read(generazioneProvider.notifier).crea(
          titolo: titolo,
          argomenti: _argomenti,
          righe: _righe,
          puntiBase: _puntiBase,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Riuscita: si entra nel tabellone appena creato.
    ref.listen(generazioneProvider, (_, stato) {
      if (stato is! GenerazioneRiuscita) return;
      ref.read(generazioneProvider.notifier).reimposta();
      context.go('/tabellone/${stato.tabellone.codicePubblico}');
    });

    final stato = ref.watch(generazioneProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuovo tabellone'),
        leading: BackButton(
          onPressed: stato is GenerazioneInCorso
              ? null
              : () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: Misure.larghezzaLettura),
            child: switch (stato) {
              GenerazioneInCorso() => _Attesa(stato: stato),
              GenerazioneFallita(:final errore) => StatoErrore(
                  errore: errore,
                  onRiprova: _crea,
                  onIndietro: () =>
                      ref.read(generazioneProvider.notifier).reimposta(),
                ),
              _ => _modulo(),
            },
          ),
        ),
      ),
    );
  }

  Widget _modulo() {
    return ListView(
      padding: const EdgeInsets.all(Misure.s5),
      children: [
        TextField(
          key: const Key('campo-titolo'),
          controller: _titoloController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Titolo del quiz'),
        ),
        const SizedBox(height: Misure.s5),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('campo-argomento'),
                controller: _argomentoController,
                decoration: InputDecoration(
                  labelText: 'Aggiungi argomento',
                  hintText: 'es. Storia romana',
                  helperText: '${_argomenti.length}/$_maxArgomenti categorie',
                ),
                onSubmitted: (_) => _aggiungiArgomento(),
              ),
            ),
            const SizedBox(width: Misure.s2),
            IconButton.filledTonal(
              key: const Key('aggiungi-argomento'),
              tooltip: 'Aggiungi questo argomento',
              onPressed:
                  _argomenti.length >= _maxArgomenti ? null : _aggiungiArgomento,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: Misure.s3),
        Wrap(
          spacing: Misure.s2,
          runSpacing: Misure.s1,
          children: [
            for (final argomento in _argomenti)
              Chip(
                label: Text(argomento),
                onDeleted: () => setState(() => _argomenti.remove(argomento)),
              ),
          ],
        ),
        const SizedBox(height: Misure.s5),
        const Text('Righe per categoria', style: Tipografia.ferramenta),
        const SizedBox(height: Misure.s2),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 3, label: Text('3')),
            ButtonSegment(value: 4, label: Text('4')),
            ButtonSegment(value: 5, label: Text('5')),
          ],
          selected: {_righe},
          onSelectionChanged: (s) => setState(() => _righe = s.first),
        ),
        const SizedBox(height: Misure.s5),
        const Text('Punti base (valore della prima riga)',
            style: Tipografia.ferramenta),
        const SizedBox(height: Misure.s2),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 100, label: Text('100')),
            ButtonSegment(value: 200, label: Text('200')),
            ButtonSegment(value: 500, label: Text('500')),
          ],
          selected: {_puntiBase},
          onSelectionChanged: (s) => setState(() => _puntiBase = s.first),
        ),
        const SizedBox(height: Misure.s6),
        if (_erroreModulo != null) ...[
          Text(_erroreModulo!,
              style: Tipografia.corpo.copyWith(color: Colori.segnale)),
          const SizedBox(height: Misure.s3),
        ],
        FilledButton.icon(
          key: const Key('genera-tabellone'),
          onPressed: _crea,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Genera il tabellone'),
        ),
        if (_argomenti.isNotEmpty) ...[
          const SizedBox(height: Misure.s3),
          // D11: la creazione è transazionale. Se la quota si esaurisce a metà,
          // si perde tutto — quindi il costo si dice prima, non dopo.
          Text(
            'Userà ${GenerazioneNotifier.costoStimato(_argomenti.length)} '
            'generazioni: una per categoria. Se finiscono a metà, il tabellone '
            'non viene creato affatto.',
            style: Tipografia.ferramenta,
          ),
        ],
      ],
    );
  }
}

/// L'attesa.
///
/// **Non finge un avanzamento.** Il codice precedente aveva un `Timer.periodic`
/// che spuntava le categorie una dopo l'altra a intervalli fissi: una barra che
/// non misurava niente, tarata per giunta su un backend che nel frattempo era
/// cambiato (D10). Quando la generazione andava lunga, la finta barra restava
/// ferma sull'ultima categoria e l'utente non sapeva più se stesse succedendo
/// qualcosa.
///
/// Qui si dice quello che si sa davvero: cosa si sta preparando, da quanto, e
/// quanto ci vuole di solito.
class _Attesa extends StatefulWidget {
  const _Attesa({required this.stato});

  final GenerazioneInCorso stato;

  @override
  State<_Attesa> createState() => _AttesaState();
}

class _AttesaState extends State<_Attesa> {
  Timer? _tic;
  Duration _trascorso = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tic = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() =>
          _trascorso = DateTime.now().difference(widget.stato.iniziataIl));
    });
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stima = widget.stato.stima;
    final oltre = _trascorso > stima;

    return Padding(
      padding: const EdgeInsets.all(Misure.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sto scrivendo le domande',
              style: Tipografia.domanda(Tipografia.domandaMinima)),
          const SizedBox(height: Misure.s4),
          Text(
            oltre
                ? 'Ci sta mettendo più del solito. Non è bloccato: le domande '
                    'vengono scritte una categoria alla volta, e a volte il '
                    'modello va lento.'
                : 'Una categoria alla volta. Di solito ci vogliono circa '
                    '${stima.inSeconds} secondi in tutto.',
            style: Tipografia.corpo,
          ),
          const SizedBox(height: Misure.s5),
          const LinearProgressIndicator(),
          const SizedBox(height: Misure.s3),
          Semantics(
            liveRegion: true,
            label: 'Generazione in corso da ${_trascorso.inSeconds} secondi',
            child: Text(
              '${_trascorso.inSeconds} s · circa ${stima.inSeconds} s attesi',
              style: Tipografia.ferramenta,
            ),
          ),
          const SizedBox(height: Misure.s6),
          const Text('CATEGORIE IN LAVORAZIONE', style: Tipografia.ferramenta),
          const SizedBox(height: Misure.s3),
          Wrap(
            spacing: Misure.s2,
            runSpacing: Misure.s2,
            children: [
              for (final argomento in widget.stato.argomenti)
                Chip(label: Text(argomento)),
            ],
          ),
          const SizedBox(height: Misure.s5),
          const Text(
            'Puoi lasciare aperta questa schermata: se esci, la generazione '
            'continua comunque.',
            style: Tipografia.ferramenta,
          ),
        ],
      ),
    );
  }
}
