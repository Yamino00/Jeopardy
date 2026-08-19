import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/animazioni.dart';
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
      body: DecoratedBox(
        decoration: sfondoApp,
        child: Column(
          children: [
            AppBar(
              title: Row(
                children: [
                  const Text('Codice '),
                  Text(codice,
                      style: const TextStyle(
                          color: jeopardyGold, letterSpacing: 3)),
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
            ),
          ],
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
          ComparsaAnimata(
            child: _BannerCodiceModifica(codice: codiceModifica!),
          ),
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
          child: GrigliaTabellone(
            tabellone: tabellone,
            builderCella: (cella, indice) => ComparsaAnimata(
              indice: indice,
              child: _CellaValore(valore: cella.valore),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: PremibileAnimato(
              onTap: () => _configuraSquadre(context, ref),
              child: Container(
                key: const Key('avvia-partita'),
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: bagliore(const Color(0xFF22C55E), intensita: 0.3),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Avvia partita',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
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
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _BannerCodiceModifica extends StatelessWidget {
  const _BannerCodiceModifica({required this.codice});

  final String codice;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: jeopardyGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: jeopardyGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_rounded, color: jeopardyGold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Conserva il codice di modifica',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                SelectableText(codice,
                    style: const TextStyle(
                        color: jeopardyGold,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: codice)),
            child: const Text('Copia'),
          ),
        ],
      ),
    );
  }
}

class _CellaValore extends StatelessWidget {
  const _CellaValore({required this.valore});

  final int valore;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradienteCella,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Center(
        child: Text(
          '$valore',
          style: const TextStyle(
            color: jeopardyGold,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
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

  /// Riceve la cella e un indice progressivo, usato per scaglionare le
  /// animazioni di comparsa.
  final Widget Function(Cella cella, int indice) builderCella;

  static const double _larghezzaMinimaColonna = 158;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final larghezzaNecessaria =
            tabellone.categorie.length * _larghezzaMinimaColonna;
        final stretta = constraints.maxWidth < larghezzaNecessaria;
        var progressivo = 0;

        final colonne = [
          for (var c = 0; c < tabellone.categorie.length; c++)
            SizedBox(
              width: stretta
                  ? _larghezzaMinimaColonna
                  : (constraints.maxWidth - 16) / tabellone.categorie.length,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ComparsaAnimata(
                      indice: c,
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: gradienteCategoria,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: bagliore(jeopardyBlueLight,
                              intensita: 0.20),
                        ),
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              tabellone.categorie[c].nomeDisplay
                                  .toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 13,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final cella in tabellone.categorie[c].celle)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: SizedBox.expand(
                          child: builderCella(cella, progressivo++),
                        ),
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
      backgroundColor: sfondoElevato,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  colore: parseHexColor(_squadre[i].colore),
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
      decoration: BoxDecoration(
        // Sfondo tenue derivato dal colore squadra: il testo resta bianco e
        // leggibile qualunque colore venga scelto
        color: sfondoTenue(colore),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colore.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: colore, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(nome,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: Colors.white70,
            onPressed: onRimuovi,
          ),
        ],
      ),
    );
  }
}
