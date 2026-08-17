import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../models/partita.dart';
import '../../models/tabellone.dart';
import '../tabellone/tabellone_page.dart';

/// The live game: board grid, fullscreen cell with two-step reveal,
/// and the always-visible team bar with undo.
class PartitaPage extends ConsumerWidget {
  const PartitaPage({super.key, required this.partitaId});

  final int partitaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partitaAsync = ref.watch(partitaProvider(partitaId));

    return partitaAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(
            leading: BackButton(onPressed: () => context.go('/'))),
        body: Center(child: Text('$e')),
      ),
      data: (partita) {
        final tabelloneAsync =
            ref.watch(tabelloneProvider(partita.codiceTabellone));
        return tabelloneAsync.when(
          loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
          data: (tabellone) => _PartitaBody(
            partita: partita,
            tabellone: tabellone,
          ),
        );
      },
    );
  }
}

class _PartitaBody extends ConsumerWidget {
  const _PartitaBody({required this.partita, required this.tabellone});

  final Partita partita;
  final Tabellone tabellone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tabellone.titolo),
        leading: BackButton(onPressed: () => context.go('/')),
        actions: [
          TextButton.icon(
            key: const Key('concludi-partita'),
            onPressed:
                partita.inCorso ? () => _concludi(context, ref) : null,
            icon: const Icon(Icons.flag),
            label: const Text('Concludi'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GrigliaTabellone(
              tabellone: tabellone,
              builderCella: (cella) => _CellaGioco(
                cella: cella,
                giocata: partita.cellaGiaGiocata(cella.id),
                abilitata: partita.inCorso,
                onTap: () => _apriCella(context, ref, cella),
              ),
            ),
          ),
          BarraSquadre(partita: partita),
        ],
      ),
    );
  }

  Future<void> _apriCella(
      BuildContext context, WidgetRef ref, Cella cella) async {
    final categoria = tabellone.categorie
        .firstWhere((c) => c.celle.any((x) => x.id == cella.id));
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CellaDialog(
        partitaId: partita.id,
        cella: cella,
        nomeCategoria: categoria.nomeDisplay,
        squadre: partita.squadreAttive,
      ),
    );
  }

  Future<void> _concludi(BuildContext context, WidgetRef ref) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Concludere la partita?'),
        content: const Text('I punteggi diventeranno definitivi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No')),
          FilledButton(
              key: const Key('conferma-concludi'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Concludi')),
        ],
      ),
    );
    if (conferma != true || !context.mounted) return;
    await ref.read(partitaProvider(partita.id).notifier).concludi();
    if (context.mounted) {
      context.go('/partita/${partita.id}/riepilogo');
    }
  }
}

class _CellaGioco extends StatelessWidget {
  const _CellaGioco({
    required this.cella,
    required this.giocata,
    required this.abilitata,
    required this.onTap,
  });

  final Cella cella;
  final bool giocata;
  final bool abilitata;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: giocata ? const Color(0xFF10173F) : jeopardyBlue,
      child: InkWell(
        key: Key('cella-${cella.id}'),
        onTap: giocata || !abilitata ? null : onTap,
        child: Center(
          child: giocata
              ? const Icon(Icons.check, color: Colors.white24)
              : Text(
                  '${cella.valore}',
                  style: const TextStyle(
                    color: jeopardyGold,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Fullscreen question: first tap shows the question, "Mostra risposta"
/// reveals the answer, then points can be assigned or the cell passed.
class CellaDialog extends ConsumerStatefulWidget {
  const CellaDialog({
    super.key,
    required this.partitaId,
    required this.cella,
    required this.nomeCategoria,
    required this.squadre,
  });

  final int partitaId;
  final Cella cella;
  final String nomeCategoria;
  final List<Squadra> squadre;

  @override
  ConsumerState<CellaDialog> createState() => _CellaDialogState();
}

class _CellaDialogState extends ConsumerState<CellaDialog> {
  bool _rispostaVisibile = false;
  bool _inviando = false;

  Future<void> _gioca(String esito, int delta, int? squadraId) async {
    if (_inviando) return;
    setState(() => _inviando = true);
    try {
      await ref.read(partitaProvider(widget.partitaId).notifier).giocaCella(
            cellaId: widget.cella.id,
            esito: esito,
            deltaPunti: delta,
            squadraId: squadraId,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _inviando = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final valore = widget.cella.valore;
    return Dialog.fullscreen(
      backgroundColor: jeopardyBlue,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    '${widget.nomeCategoria.toUpperCase()} - $valore',
                    style: const TextStyle(
                      color: jeopardyGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('chiudi-cella'),
                    onPressed: _inviando
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(
                          widget.cella.testo ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (_rispostaVisibile)
                          Text(
                            widget.cella.risposta ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: jeopardyGold,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!_rispostaVisibile)
                FilledButton.icon(
                  key: const Key('mostra-risposta'),
                  onPressed: () =>
                      setState(() => _rispostaVisibile = true),
                  icon: const Icon(Icons.visibility),
                  style: FilledButton.styleFrom(
                    backgroundColor: jeopardyGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 32),
                  ),
                  label: const Text('Mostra risposta'),
                )
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final squadra in widget.squadre)
                      _AssegnaPuntiChip(
                        squadra: squadra,
                        valore: valore,
                        inviando: _inviando,
                        onCorretta: () =>
                            _gioca('corretta', valore, squadra.id),
                        onErrata: () =>
                            _gioca('errata', -valore, squadra.id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  key: const Key('passa-cella'),
                  onPressed:
                      _inviando ? null : () => _gioca('passata', 0, null),
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Nessuno risponde: passa'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssegnaPuntiChip extends StatelessWidget {
  const _AssegnaPuntiChip({
    required this.squadra,
    required this.valore,
    required this.inviando,
    required this.onCorretta,
    required this.onErrata,
  });

  final Squadra squadra;
  final int valore;
  final bool inviando;
  final VoidCallback onCorretta;
  final VoidCallback onErrata;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF14226B),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
                radius: 7,
                backgroundColor: parseHexColor(squadra.colore)),
            const SizedBox(width: 8),
            Text(squadra.nome,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 8),
            IconButton(
              key: Key('corretta-${squadra.id}'),
              tooltip: '+$valore',
              onPressed: inviando ? null : onCorretta,
              icon: const Icon(Icons.check_circle, color: Colors.green),
            ),
            IconButton(
              key: Key('errata-${squadra.id}'),
              tooltip: '-$valore',
              onPressed: inviando ? null : onErrata,
              icon: const Icon(Icons.cancel, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Always-visible team bar: scores (long-press to edit), add team,
/// and the ever-reachable undo button.
class BarraSquadre extends ConsumerWidget {
  const BarraSquadre({super.key, required this.partita});

  final Partita partita;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(partitaProvider(partita.id).notifier);

    return Material(
      color: const Color(0xFF0A123F),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 88,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  children: [
                    for (final squadra in partita.squadreAttive)
                      _SquadraCard(
                        squadra: squadra,
                        inTurno: squadra.id == partita.turnoSquadraId,
                        onLongPress: () =>
                            _modificaSquadra(context, notifier, squadra),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('aggiungi-squadra-partita'),
                tooltip: 'Aggiungi squadra',
                onPressed: partita.inCorso
                    ? () => _aggiungiSquadra(context, notifier)
                    : null,
                icon: const Icon(Icons.group_add),
              ),
              IconButton(
                key: const Key('annulla-evento'),
                tooltip: 'Annulla ultima mossa',
                onPressed: partita.inCorso
                    ? () async {
                        try {
                          await notifier.annulla();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')));
                          }
                        }
                      }
                    : null,
                icon: const Icon(Icons.undo, color: jeopardyGold),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _aggiungiSquadra(
      BuildContext context, PartitaNotifier notifier) async {
    final controller = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuova squadra'),
        content: TextField(
          key: const Key('campo-nuova-squadra'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla')),
          FilledButton(
            key: const Key('conferma-nuova-squadra'),
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
    if (nome == null || nome.isEmpty) return;
    final colore = squadraPalette[
        partita.squadre.length % squadraPalette.length];
    await notifier.aggiungiSquadra(nome, colore: colorToHex(colore));
  }

  Future<void> _modificaSquadra(BuildContext context,
      PartitaNotifier notifier, Squadra squadra) async {
    final nomeController = TextEditingController(text: squadra.nome);
    final punteggioController =
        TextEditingController(text: '${squadra.punteggio}');
    final azione = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifica ${squadra.nome}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('campo-punteggio'),
              controller: punteggioController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Punteggio',
                helperText: 'Correzione manuale: finisce nel log eventi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('rimuovi'),
            child: const Text('Rimuovi squadra',
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla')),
          FilledButton(
            key: const Key('salva-squadra'),
            onPressed: () => Navigator.of(context).pop('salva'),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (azione == null) return;
    if (azione == 'rimuovi') {
      await notifier.rimuoviSquadra(squadra.id);
      return;
    }
    final punteggio = int.tryParse(punteggioController.text.trim());
    await notifier.aggiornaSquadra(
      squadra.id,
      nome: nomeController.text.trim().isEmpty
          ? null
          : nomeController.text.trim(),
      punteggio: punteggio,
    );
  }
}

class _SquadraCard extends StatelessWidget {
  const _SquadraCard({
    required this.squadra,
    required this.inTurno,
    required this.onLongPress,
  });

  final Squadra squadra;
  final bool inTurno;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('squadra-${squadra.id}'),
      onLongPress: onLongPress,
      child: Card(
        color: inTurno ? jeopardyBlueLight : jeopardyBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: inTurno
              ? const BorderSide(color: jeopardyGold, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          // scaleDown: la card non deve mai andare in overflow verticale,
          // qualunque sia la scala testo del dispositivo
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                      radius: 6,
                      backgroundColor: parseHexColor(squadra.colore)),
                  const SizedBox(width: 6),
                  Text(squadra.nome,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
                Text(
                  '${squadra.punteggio}',
                  key: Key('punteggio-${squadra.id}'),
                  style: const TextStyle(
                    color: jeopardyGold,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
