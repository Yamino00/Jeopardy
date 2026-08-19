import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/animazioni.dart';
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
      body: DecoratedBox(
        decoration: sfondoApp,
        child: Column(
          children: [
            AppBar(
              title: Text(tabellone.titolo),
              leading: BackButton(onPressed: () => context.go('/')),
              actions: [
                TextButton.icon(
                  key: const Key('concludi-partita'),
                  onPressed:
                      partita.inCorso ? () => _concludi(context, ref) : null,
                  icon: const Icon(Icons.flag_rounded, size: 18),
                  label: const Text('Concludi'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            Expanded(
              child: GrigliaTabellone(
                tabellone: tabellone,
                builderCella: (cella, indice) => ComparsaAnimata(
                  indice: indice,
                  child: _CellaGioco(
                    cella: cella,
                    giocata: partita.cellaGiaGiocata(cella.id),
                    abilitata: partita.inCorso,
                    onTap: () => _apriCella(context, ref, cella),
                  ),
                ),
              ),
            ),
            BarraSquadre(partita: partita),
          ],
        ),
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
        backgroundColor: sfondoElevato,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    final attiva = !giocata && abilitata;
    return PremibileAnimato(
      onTap: attiva ? onTap : null,
      child: AnimatedContainer(
        key: Key('cella-${cella.id}'),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: giocata ? null : gradienteCella,
          color: giocata ? Colors.white.withValues(alpha: 0.03) : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: giocata
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: giocata
              ? const Icon(Icons.check_rounded, color: Colors.white24, size: 26)
              : Text(
                  '${cella.valore}',
                  style: const TextStyle(
                    color: jeopardyGold,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Fullscreen question: the answer is hidden until "Mostra risposta",
/// then points can be assigned or the cell passed.
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
      backgroundColor: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2A7B), Color(0xFF0C1236)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: jeopardyGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.nomeCategoria.toUpperCase()} · $valore',
                        style: const TextStyle(
                          color: jeopardyGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const Key('chiudi-cella'),
                      onPressed:
                          _inviando ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
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
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 28),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SizeTransition(
                                  sizeFactor: anim, child: child),
                            ),
                            child: _rispostaVisibile
                                ? Container(
                                    key: const ValueKey('risposta'),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 16),
                                    decoration: BoxDecoration(
                                      color:
                                          jeopardyGold.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: jeopardyGold.withValues(
                                              alpha: 0.5)),
                                    ),
                                    child: Text(
                                      widget.cella.risposta ?? '',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: jeopardyGold,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_rispostaVisibile)
                  PremibileAnimato(
                    onTap: () => setState(() => _rispostaVisibile = true),
                    child: Container(
                      key: const Key('mostra-risposta'),
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 34),
                      decoration: BoxDecoration(
                        color: jeopardyGold,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: bagliore(jeopardyGold, intensita: 0.35),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_rounded, color: Colors.black87),
                          SizedBox(width: 10),
                          Text('Mostra risposta',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < widget.squadre.length; i++)
                        ComparsaAnimata(
                          indice: i,
                          child: _AssegnaPuntiChip(
                            squadra: widget.squadre[i],
                            valore: valore,
                            inviando: _inviando,
                            onCorretta: () => _gioca(
                                'corretta', valore, widget.squadre[i].id),
                            onErrata: () => _gioca(
                                'errata', -valore, widget.squadre[i].id),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    key: const Key('passa-cella'),
                    onPressed:
                        _inviando ? null : () => _gioca('passata', 0, null),
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Nessuno risponde: passa'),
                  ),
                ],
              ],
            ),
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
    final colore = parseHexColor(squadra.colore);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: sfondoTenue(colore),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colore.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: colore, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(squadra.nome,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          IconButton(
            key: Key('corretta-${squadra.id}'),
            tooltip: '+$valore',
            onPressed: inviando ? null : onCorretta,
            icon: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4ADE80)),
          ),
          IconButton(
            key: Key('errata-${squadra.id}'),
            tooltip: '-$valore',
            onPressed: inviando ? null : onErrata,
            icon: const Icon(Icons.cancel_rounded, color: Color(0xFFFF6B6B)),
          ),
        ],
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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E2E),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 92,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                icon: const Icon(Icons.group_add_rounded),
              ),
              PremibileAnimato(
                onTap: partita.inCorso
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
                child: Container(
                  key: const Key('annulla-evento'),
                  margin: const EdgeInsets.only(right: 10, left: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: partita.inCorso
                        ? jeopardyGold.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.undo_rounded,
                      color: partita.inCorso ? jeopardyGold : Colors.white24),
                ),
              ),
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
        backgroundColor: sfondoElevato,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        backgroundColor: sfondoElevato,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Modifica ${squadra.nome}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('campo-punteggio'),
              controller: punteggioController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Punteggio',
                helperText: 'La correzione finisce nel log eventi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('rimuovi'),
            child: const Text('Rimuovi',
                style: TextStyle(color: Color(0xFFFF6B6B))),
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
    final colore = parseHexColor(squadra.colore);
    return PremibileAnimato(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        key: Key('squadra-${squadra.id}'),
        duration: const Duration(milliseconds: 260),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          // Fondo sempre scuro, derivato dal colore squadra: il testo bianco
          // resta leggibile anche con colori chiari come il giallo
          color: sfondoTenue(colore),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inTurno ? colore : colore.withValues(alpha: 0.35),
            width: inTurno ? 2 : 1,
          ),
          boxShadow: inTurno ? bagliore(colore, intensita: 0.4) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: colore, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    squadra.nome,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            PunteggioAnimato(
              key: Key('punteggio-${squadra.id}'),
              valore: squadra.punteggio,
              stile: const TextStyle(
                color: jeopardyGold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
