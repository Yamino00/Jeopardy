import 'package:flutter/widgets.dart';

import 'misure.dart';

/// La banda di smalto che identifica una squadra.
///
/// Vive nel design system e non fra i widget di feature perché **è** la regola
/// sul colore, resa oggetto: uno smalto squadra non sta mai dietro del testo.
///
/// I colori delle squadre arrivano dal backend come esadecimali scelti
/// dall'utente, quindi possono essere qualunque cosa — inclusi un giallo
/// chiarissimo e un blu quasi nero. Una scheda colorata dietro un'etichetta
/// obbliga a calcolare il contrasto a runtime e a indovinare (era il mestiere di
/// `sfondoTenue()` e `coloreTestoSu()`, entrambi rimossi). Una banda laterale
/// non ha quel problema: non porta testo, quindi nessun colore la rompe.
///
/// L'identità della squadra la portano il nome e la posizione stabile nella
/// rastrelliera; questo è l'indizio secondario che li rende scandibili a colpo
/// d'occhio.
class IntarsioSquadra extends StatelessWidget {
  const IntarsioSquadra({
    super.key,
    required this.colore,
    this.altezza,
    this.spessore = 4,
  });

  final Color colore;

  /// Se nullo, l'intarsio si stira sull'altezza del genitore.
  final double? altezza;

  final double spessore;

  @override
  Widget build(BuildContext context) {
    final banda = DecoratedBox(
      decoration: BoxDecoration(
        color: colore,
        borderRadius: const BorderRadius.all(Radius.circular(1)),
      ),
      child: SizedBox(width: spessore, height: altezza),
    );
    // Decorativo: il nome della squadra accanto porta già l'informazione, e uno
    // screen reader che annuncia "banda color #C6482F" è rumore.
    return ExcludeSemantics(
      child: altezza == null
          ? SizedBox(width: spessore, child: banda)
          : banda,
    );
  }
}

/// L'intarsio nella sua forma più comune: alto quanto la riga in cui sta, con
/// lo spazio dopo di sé già previsto.
class IntarsioInRiga extends StatelessWidget {
  const IntarsioInRiga({super.key, required this.colore, this.altezza = 22});

  final Color colore;
  final double altezza;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Misure.s3),
      child: IntarsioSquadra(colore: colore, altezza: altezza),
    );
  }
}
