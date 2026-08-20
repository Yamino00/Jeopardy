import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../data/providers.dart';

/// La striscia che dice all'host cosa non è ancora arrivato al server.
///
/// Compare **solo quando serve**: a rete funzionante non c'è niente in attesa e
/// questa riga non esiste. Quando invece c'è, dice tre cose, e nessuna è
/// decorativa:
///
/// 1. **quante** giocate sono in attesa, così l'host sa quanto rischia;
/// 2. che il tabellone continua a funzionare, perché altrimenti la reazione
///    naturale è ripetere il tocco e giocare la cella due volte;
/// 3. che l'invio si fa da qui, quando la rete torna — e non da solo: ritentare
///    a ogni tocco vorrebbe dire bloccare il tabellone per il tempo del timeout
///    di connessione, proprio mentre il gruppo sta giocando.
///
/// Sta in Segnale e non in Ottone: è la macchina che si fa sentire, non
/// qualcosa che è in gioco.
class StrisciaAzioniInAttesa extends ConsumerWidget {
  const StrisciaAzioniInAttesa({super.key, required this.partitaId});

  final int partitaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inAttesa = ref.watch(azioniInAttesaProvider(partitaId));
    if (inAttesa.isEmpty) return const SizedBox.shrink();

    final quante = inAttesa.length;
    final testo = quante == 1
        ? '1 giocata non è ancora arrivata al server'
        : '$quante giocate non sono ancora arrivate al server';

    return Semantics(
      liveRegion: true,
      label: '$testo. I punteggi che vedi sono aggiornati.',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Misure.s4,
          vertical: Misure.s3,
        ),
        decoration: const BoxDecoration(
          color: Colori.notte,
          border: Border(top: BorderSide(color: Colori.segnale)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Colori.segnale, size: 20),
            const SizedBox(width: Misure.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    testo,
                    style:
                        Tipografia.corpoRilievo.copyWith(color: Colori.segnale),
                  ),
                  const SizedBox(height: Misure.s1),
                  Text(
                    'Puoi continuare a giocare: i punteggi che vedi sono '
                    'aggiornati. Quando la rete torna, tocca Riprova e '
                    "partiranno nell'ordine in cui le hai fatte.",
                    style: Tipografia.ferramenta,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Misure.s3),
            TextButton(
              key: const Key('riprova-invio'),
              onPressed: () =>
                  ref.read(partitaProvider(partitaId).notifier).riconcilia(),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}
