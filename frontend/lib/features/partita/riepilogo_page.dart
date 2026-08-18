import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/animazioni.dart';
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
      body: DecoratedBox(
        decoration: sfondoApp,
        child: Column(
          children: [
            AppBar(
              title: const Text('Riepilogo'),
              leading: BackButton(onPressed: () => context.go('/')),
            ),
            Expanded(
              child: partitaAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (partita) => _RiepilogoBody(partita: partita),
              ),
            ),
          ],
        ),
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
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            const ComparsaAnimata(indice: 0, child: _Trofeo()),
            const SizedBox(height: 12),
            if (classifica.isNotEmpty)
              ComparsaAnimata(
                indice: 1,
                child: Text(
                  'Vince ${classifica.first.nome}!',
                  key: const Key('vincitore'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            const SizedBox(height: 26),
            for (var i = 0; i < classifica.length; i++)
              ComparsaAnimata(
                indice: 2 + i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RigaClassifica(
                    posizione: i + 1,
                    squadra: classifica[i],
                  ),
                ),
              ),
            const SizedBox(height: 26),
            ComparsaAnimata(
              indice: 2 + classifica.length,
              child: PremibileAnimato(
                onTap: () => _rigioca(context, ref),
                child: Container(
                  key: const Key('rigioca'),
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [jeopardyGold, Color(0xFFFF9F1C)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: bagliore(jeopardyGold, intensita: 0.3),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.replay_rounded, color: Colors.black87),
                      SizedBox(width: 10),
                      Text('Rigioca questo tabellone',
                          style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
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
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Condividi il codice del tabellone'),
            ),
            const SizedBox(height: 6),
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

class _Trofeo extends StatelessWidget {
  const _Trofeo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [jeopardyGold, Color(0xFFFF9F1C)],
          ),
          shape: BoxShape.circle,
          boxShadow: bagliore(jeopardyGold, intensita: 0.5),
        ),
        // Icona scura su fondo oro: contrasto garantito
        child: const Icon(Icons.emoji_events_rounded,
            size: 52, color: Color(0xFF3A2A00)),
      ),
    );
  }
}

class _RigaClassifica extends StatelessWidget {
  const _RigaClassifica({required this.posizione, required this.squadra});

  final int posizione;
  final Squadra squadra;

  @override
  Widget build(BuildContext context) {
    final primo = posizione == 1;
    final coloreSquadra = parseHexColor(squadra.colore);
    final sfondoBadge = primo ? jeopardyGold : Colors.white.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: sfondoTenue(coloreSquadra),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primo
              ? jeopardyGold.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: primo ? 2 : 1,
        ),
        boxShadow: primo ? bagliore(jeopardyGold, intensita: 0.22) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: sfondoBadge,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$posizione',
                style: TextStyle(
                  // Su fondo oro serve testo scuro, su fondo tenue serve chiaro
                  color: coloreTestoSu(
                      primo ? jeopardyGold : const Color(0xFF2A2F55)),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: coloreSquadra, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              squadra.nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
          ),
          Text(
            '${squadra.punteggio}',
            style: const TextStyle(
              color: jeopardyGold,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
