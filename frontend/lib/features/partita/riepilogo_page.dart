import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../models/partita.dart';

/// Final ranking with replay and code sharing.
class RiepilogoPage extends ConsumerWidget {
  const RiepilogoPage({super.key, required this.partitaId});

  final int partitaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partitaAsync = ref.watch(partitaProvider(partitaId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riepilogo'),
        leading: BackButton(onPressed: () => context.go('/')),
      ),
      body: partitaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (partita) => _RiepilogoBody(partita: partita),
      ),
    );
  }
}

class _RiepilogoBody extends ConsumerWidget {
  const _RiepilogoBody({required this.partita});

  final Partita partita;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classifica = [...partita.squadre.where((s) => s.attiva)]
      ..sort((a, b) => b.punteggio.compareTo(a.punteggio));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.emoji_events, size: 72, color: jeopardyGold),
            const SizedBox(height: 8),
            if (classifica.isNotEmpty)
              Text(
                'Vince ${classifica.first.nome}!',
                key: const Key('vincitore'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            const SizedBox(height: 24),
            for (var i = 0; i < classifica.length; i++)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: i == 0
                        ? jeopardyGold
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i == 0 ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      CircleAvatar(
                        radius: 6,
                        backgroundColor:
                            parseHexColor(classifica[i].colore),
                      ),
                      const SizedBox(width: 8),
                      Text(classifica[i].nome),
                    ],
                  ),
                  trailing: Text(
                    '${classifica[i].punteggio}',
                    style: const TextStyle(
                      color: jeopardyGold,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('rigioca'),
              onPressed: () => _rigioca(context, ref),
              icon: const Icon(Icons.replay),
              label: const Text('Rigioca questo tabellone'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('condividi-codice'),
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: partita.codiceTabellone));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Codice ${partita.codiceTabellone} copiato!')),
                  );
                }
              },
              icon: const Icon(Icons.share),
              label: const Text('Condividi il codice del tabellone'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Torna alla home'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rigioca(BuildContext context, WidgetRef ref) async {
    try {
      // Nuova partita sullo stesso tabellone con le stesse squadre,
      // punteggi azzerati
      final nuova = await ref.read(partitaRepositoryProvider).avvia(
            partita.codiceTabellone,
            [
              for (final s in partita.squadre.where((s) => s.attiva))
                (nome: s.nome, colore: s.colore),
            ],
          );
      if (context.mounted) {
        context.go('/partita/${nuova.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
