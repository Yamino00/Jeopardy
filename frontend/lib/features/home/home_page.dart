import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';

/// Entry point: create a board, join with a code, or reopen your boards.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _codiceController = TextEditingController();

  @override
  void dispose() {
    _codiceController.dispose();
    super.dispose();
  }

  void _entraConCodice() {
    final codice = _codiceController.text.trim().toUpperCase();
    if (codice.isNotEmpty) {
      context.go('/tabellone/$codice');
    }
  }

  @override
  Widget build(BuildContext context) {
    final miei = ref.watch(mieiTabelloniProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'QUIZ GRID',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: jeopardyGold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Quiz a griglia stile Jeopardy',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                key: const Key('crea-tabellone'),
                onPressed: () => context.go('/crea'),
                icon: const Icon(Icons.add),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                label: const Text('Crea nuovo tabellone'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('campo-codice'),
                      controller: _codiceController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Codice tabellone',
                        hintText: 'es. KDSYMS',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _entraConCodice(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    key: const Key('entra-codice'),
                    onPressed: _entraConCodice,
                    child: const Text('Entra'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('I miei tabelloni',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              miei.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  'Impossibile caricare i tabelloni: $e',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                ),
                data: (tabelloni) => tabelloni.isEmpty
                    ? const Text('Nessun tabellone ancora: creane uno!')
                    : Column(
                        children: [
                          for (final t in tabelloni)
                            Card(
                              child: ListTile(
                                title: Text(t.titolo),
                                subtitle: Text(
                                    '${t.codicePubblico} - ${t.righe} righe'),
                                trailing:
                                    const Icon(Icons.chevron_right),
                                onTap: () => context
                                    .go('/tabellone/${t.codicePubblico}'),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
