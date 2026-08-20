import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../data/providers.dart';

/// La riga che dice all'host cosa non è ancora arrivato al server.
///
/// Compare **solo quando serve**: a rete funzionante non c'è niente in attesa e
/// questa riga non esiste.
///
/// **Sta su una riga sola, e non è un dettaglio estetico.** La prima versione
/// occupava un quarto dello schermo con un paragrafo di spiegazioni, e su un
/// telefono tagliava l'ultima fila di tessere: un avviso che impedisce di
/// giocare è peggio del problema che segnala. La spiegazione lunga non è andata
/// persa — vive nella `Semantics`, dove serve davvero a chi non vede lo schermo.
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
    final breve = quante == 1
        ? '1 giocata in attesa'
        : '$quante giocate in attesa';

    return Semantics(
      liveRegion: true,
      label: '$breve. Puoi continuare a giocare: i punteggi che vedi sono '
          'aggiornati. Quando la rete torna, tocca Riprova e le giocate '
          "partiranno nell'ordine in cui le hai fatte.",
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: Misure.s4, right: Misure.s2),
        decoration: const BoxDecoration(
          color: Colori.notte,
          border: Border(top: BorderSide(color: Colori.segnale)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Colori.segnale, size: 18),
            const SizedBox(width: Misure.s3),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: breve,
                      style: Tipografia.ferramenta
                          .copyWith(color: Colori.segnale),
                    ),
                    // Il punteggio è aggiornato: senza dirlo, la reazione
                    // naturale è ripetere il tocco e giocare la cella due volte.
                    const TextSpan(
                      text: ' · i punteggi che vedi sono aggiornati',
                      style: Tipografia.ferramenta,
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
