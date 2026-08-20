import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/widgets/animazioni.dart';
import '../../core/widgets/raccolta_tessere.dart';
import '../../core/widgets/tessera.dart';
import '../../data/providers.dart';
import '../../models/tabellone.dart';
import '../../core/widgets/stato_errore.dart';

/// Board preview: share code, grid overview, team setup and game start.
class TabellonePage extends ConsumerWidget {
  const TabellonePage({
    super.key,
    required this.codice,
  });

  final String codice;

  /// Only set right after creation, to show it once.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabellone = ref.watch(tabelloneProvider(codice));

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Colori.notte),
        child: Column(
          children: [
            AppBar(
              title: Row(
                children: [
                  const Text('Codice '),
                  Text(codice,
                      style: const TextStyle(
                          color: Colori.ottone, letterSpacing: 3)),
                ],
              ),
              leading: BackButton(onPressed: () => context.go('/')),
              actions: [
                IconButton(
                  tooltip: 'Copia il codice per condividerlo',
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: codice));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Codice copiato!')),
                      );
                    }
                  },
                ),
              ],
            ),
            Expanded(
              child: tabellone.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => StatoErrore(
                  errore: e,
                  onRiprova: () => ref.invalidate(tabelloneProvider(codice)),
                  onIndietro: () => context.go('/'),
                ),
                data: (t) => _TabelloneBody(
                  tabellone: t,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabelloneBody extends ConsumerWidget {
  const _TabelloneBody({required this.tabellone});

  final Tabellone tabellone;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Text(
            tabellone.titolo,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Misure.s3),
            child: RaccoltaTessere(
              categorie: [
                for (final categoria in tabellone.categorie)
                  CategoriaTessere(
                    nome: categoria.nomeDisplay,
                    tessere: [
                      for (final cella in categoria.celle)
                        DatiTessera(
                          id: cella.id,
                          valore: cella.valore,
                          stato: StatoTessera.faccia,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: PremibileAnimato(
              onTap: () => _configuraSquadre(context, ref),
              etichetta: 'Avvia partita',
              suggerimento: 'scegli le squadre e comincia',
              child: Container(
                key: const Key('avvia-partita'),
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colori.ottone,
                  borderRadius: Misure.bordoCartellino,
                  boxShadow: Luce.aloneTenue(),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Colori.notte),
                    SizedBox(width: 8),
                    Text('Avvia partita', style: Tipografia.sullaLuce),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _configuraSquadre(BuildContext context, WidgetRef ref) async {
    final squadre = await showDialog<List<({String nome, String? colore})>>(
      context: context,
      builder: (_) => const _SquadreDialog(),
    );
    if (squadre == null || squadre.isEmpty || !context.mounted) return;

    try {
      final partita = await ref
          .read(partitaRepositoryProvider)
          .avvia(tabellone.codicePubblico, squadre);
      if (context.mounted) {
        context.go('/partita/${partita.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(barraErrore(e));
      }
    }
  }
}

class _SquadreDialog extends StatefulWidget {
  const _SquadreDialog();

  @override
  State<_SquadreDialog> createState() => _SquadreDialogState();
}

class _SquadreDialogState extends State<_SquadreDialog> {
  final _nomeController = TextEditingController();
  final List<({String nome, String? colore})> _squadre = [];

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  void _aggiungi() {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) return;
    final colore = SmaltiSquadra.tutti[_squadre.length % SmaltiSquadra.tutti.length];
    setState(() {
      _squadre.add((nome: nome, colore: hexDaColore(colore)));
      _nomeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colori.quadro,
      shape: const RoundedRectangleBorder(borderRadius: Misure.bordoCartellino),
      title: const Text('Chi gioca?'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('campo-nome-squadra'),
                    controller: _nomeController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nome squadra',
                      prefixIcon: Icon(Icons.group_rounded, size: 20),
                    ),
                    onSubmitted: (_) => _aggiungi(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('aggiungi-squadra'),
                  onPressed: _aggiungi,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < _squadre.length; i++)
              ComparsaAnimata(
                indice: i,
                child: _RigaSquadraDialog(
                  nome: _squadre[i].nome,
                  colore: coloreDaHex(_squadre[i].colore),
                  onRimuovi: () =>
                      setState(() => _squadre.removeAt(i)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('conferma-squadre'),
          onPressed: _squadre.isEmpty
              ? null
              : () => Navigator.of(context).pop(_squadre),
          child: const Text('Inizia'),
        ),
      ],
    );
  }
}

class _RigaSquadraDialog extends StatelessWidget {
  const _RigaSquadraDialog({
    required this.nome,
    required this.colore,
    required this.onRimuovi,
  });

  final String nome;
  final Color colore;
  final VoidCallback onRimuovi;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colori.quadro,
        borderRadius: Misure.bordoTessera,
      ),
      child: Row(
        children: [
          // Il colore squadra e' un intarsio, non un bordo sbiadito: la stessa
          // banda che identifica la squadra in partita e nel riepilogo.
          IntarsioInRiga(colore: colore),
          Expanded(
            child: Text(nome,
                style: const TextStyle(
                    color: Colori.ghiaccio, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: Colori.acciaio,
            onPressed: onRimuovi,
          ),
        ],
      ),
    );
  }
}
