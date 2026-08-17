import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../models/tabellone.dart';

/// Board preview: share code, grid overview, team setup and game start.
class TabellonePage extends ConsumerWidget {
  const TabellonePage({
    super.key,
    required this.codice,
    this.codiceModifica,
  });

  final String codice;

  /// Only set right after creation, to show it once.
  final String? codiceModifica;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabellone = ref.watch(tabelloneProvider(codice));

    return Scaffold(
      appBar: AppBar(
        title: Text('Tabellone $codice'),
        leading: BackButton(onPressed: () => context.go('/')),
        actions: [
          IconButton(
            tooltip: 'Copia il codice per condividerlo',
            icon: const Icon(Icons.share),
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
      body: tabellone.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (t) => _TabelloneBody(
          tabellone: t,
          codiceModifica: codiceModifica,
        ),
      ),
    );
  }
}

class _TabelloneBody extends ConsumerWidget {
  const _TabelloneBody({required this.tabellone, this.codiceModifica});

  final Tabellone tabellone;
  final String? codiceModifica;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        if (codiceModifica != null && codiceModifica!.isNotEmpty)
          MaterialBanner(
            content: Text(
              'Tabellone creato! Conserva il codice di modifica: '
              '$codiceModifica',
            ),
            leading: const Icon(Icons.key, color: jeopardyGold),
            actions: [
              TextButton(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: codiceModifica!)),
                child: const Text('Copia'),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            tabellone.titolo,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: GrigliaTabellone(
            tabellone: tabellone,
            builderCella: (cella) => Card(
              child: Center(
                child: Text(
                  '${cella.valore}',
                  style: const TextStyle(
                    color: jeopardyGold,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              key: const Key('avvia-partita'),
              onPressed: () => _configuraSquadre(context, ref),
              icon: const Icon(Icons.play_arrow),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              ),
              label: const Text('Avvia partita'),
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
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

/// Responsive board grid shared by preview and game screens: on narrow
/// screens the categories scroll horizontally instead of being squeezed.
class GrigliaTabellone extends StatelessWidget {
  const GrigliaTabellone({
    super.key,
    required this.tabellone,
    required this.builderCella,
  });

  final Tabellone tabellone;
  final Widget Function(Cella cella) builderCella;

  static const double _larghezzaMinimaColonna = 150;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final larghezzaNecessaria =
            tabellone.categorie.length * _larghezzaMinimaColonna;
        final stretta = constraints.maxWidth < larghezzaNecessaria;

        final colonne = [
          for (final categoria in tabellone.categorie)
            SizedBox(
              width: stretta
                  ? _larghezzaMinimaColonna
                  : (constraints.maxWidth - 16) /
                      tabellone.categorie.length,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Card(
                      color: jeopardyBlueLight,
                      child: SizedBox(
                        height: 64,
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              categoria.nomeDisplay.toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final cella in categoria.celle)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: SizedBox.expand(
                            child: builderCella(cella)),
                      ),
                    ),
                ],
              ),
            ),
        ];

        if (stretta) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: colonne,
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: colonne),
        );
      },
    );
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
    final colore = squadraPalette[_squadre.length % squadraPalette.length];
    setState(() {
      _squadre.add((nome: nome, colore: colorToHex(colore)));
      _nomeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Squadre'),
      content: SizedBox(
        width: 360,
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
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _aggiungi(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('aggiungi-squadra'),
                  onPressed: _aggiungi,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final squadra in _squadre)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 10,
                  backgroundColor: parseHexColor(squadra.colore),
                ),
                title: Text(squadra.nome),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      setState(() => _squadre.remove(squadra)),
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
          onPressed:
              _squadre.isEmpty ? null : () => Navigator.of(context).pop(_squadre),
          child: const Text('Inizia'),
        ),
      ],
    );
  }
}
