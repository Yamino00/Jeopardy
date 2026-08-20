import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/widgets/punteggio_palette.dart';
import '../../core/widgets/stato_errore.dart';
import '../../data/providers.dart';
import '../../models/partita.dart';

/// La classifica finale, con il rigioca e il codice da passare.
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
      body: SafeArea(
        child: partitaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => StatoErrore(
            errore: e,
            onRiprova: () => ref.invalidate(partitaProvider(partitaId)),
            onIndietro: () => context.go('/'),
          ),
          data: (partita) => _RiepilogoBody(partita: partita),
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
    final classifica = [...partita.squadreAttive]
      ..sort((a, b) => b.punteggio.compareTo(a.punteggio));
    final vincitori = classifica.isEmpty
        ? const <Squadra>[]
        : classifica
            .where((s) => s.punteggio == classifica.first.punteggio)
            .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Misure.larghezzaLettura),
        child: ListView(
          padding: const EdgeInsets.all(Misure.s5),
          children: [
            _Esito(vincitori: vincitori),
            const SizedBox(height: Misure.s6),
            const Text('CLASSIFICA', style: Tipografia.ferramenta),
            const SizedBox(height: Misure.s3),
            for (var i = 0; i < classifica.length; i++) ...[
              if (i > 0) const SizedBox(height: Misure.fuga),
              _RigaClassifica(
                posizione: i + 1,
                squadra: classifica[i],
                primo: vincitori.contains(classifica[i]),
              ),
            ],
            const SizedBox(height: Misure.s6),
            FilledButton.icon(
              key: const Key('rigioca'),
              onPressed: () => _rigioca(context, ref),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Rigioca questo tabellone'),
            ),
            const SizedBox(height: Misure.s3),
            OutlinedButton.icon(
              key: const Key('condividi-codice'),
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: partita.codiceTabellone));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Codice ${partita.codiceTabellone} copiato'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Copia il codice del tabellone'),
            ),
            const SizedBox(height: Misure.s2),
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
      final nuova = await ref.read(partitaRepositoryProvider).avvia(
            partita.codiceTabellone,
            [
              for (final s in partita.squadreAttive)
                (nome: s.nome, colore: s.colore),
            ],
          );
      if (context.mounted) context.go('/partita/${nuova.id}');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(barraErrore(e));
      }
    }
  }
}

/// Chi ha vinto.
///
/// Niente trofeo dentro un cerchio dorato: era l'unico posto dell'app in cui
/// compariva un'icona celebrativa generica, e non appartiene al vocabolario del
/// sistema. Il nome di chi vince, composto in display, è già la celebrazione.
///
/// Gestisce anche il pareggio, che prima non esisteva: `classifica.first` dava
/// per vincitore chiunque capitasse primo nell'ordinamento.
class _Esito extends StatelessWidget {
  const _Esito({required this.vincitori});

  final List<Squadra> vincitori;

  @override
  Widget build(BuildContext context) {
    if (vincitori.isEmpty) {
      return const Text('Partita conclusa', style: Tipografia.marchio);
    }
    final pareggio = vincitori.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(pareggio ? 'PAREGGIO' : 'VINCE', style: Tipografia.ferramenta),
        const SizedBox(height: Misure.s2),
        Text(
          vincitori.map((s) => s.nome).join(' · '),
          key: const Key('vincitore'),
          style: Tipografia.marchio,
        ),
      ],
    );
  }
}

class _RigaClassifica extends StatelessWidget {
  const _RigaClassifica({
    required this.posizione,
    required this.squadra,
    required this.primo,
  });

  final int posizione;
  final Squadra squadra;
  final bool primo;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$posizione. ${squadra.nome}, ${squadra.punteggio} punti',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Misure.s4),
        decoration: BoxDecoration(
          color: Colori.quadro,
          borderRadius: Misure.bordoCartellino,
          // Chi vince ha il bordo di luce. È l'unica cosa accesa della
          // schermata, come vuole la regola della sorgente unica.
          border: primo
              ? Border.all(color: Colori.ottone, width: Misure.bordoLuce)
              : null,
          boxShadow: primo ? Luce.aloneTenue() : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: Misure.s6,
              child: Text('$posizione', style: Tipografia.punteggio(18)),
            ),
            IntarsioInRiga(colore: coloreDaHex(squadra.colore)),
            Expanded(
              child: Text(
                squadra.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tipografia.nomeSquadra,
              ),
            ),
            const SizedBox(width: Misure.s3),
            // Le stesse palette del podio, ferme.
            //
            // La coerenza è nel modo in cui si compongono le cifre, non nel
            // farle girare: qui il punteggio è finale e non cambia, quindi un
            // meccanismo per mostrare il cambiamento sarebbe decorazione — che
            // è precisamente ciò che la firma non deve essere. `PunteggioPalette`
            // al primo frame non gira, quindi si ottiene la resa meccanica
            // senza il movimento.
            PunteggioPalette(
              key: Key('punteggio-finale-${squadra.id}'),
              valore: squadra.punteggio,
              dimensione: 22,
            ),
          ],
        ),
      ),
    );
  }
}
