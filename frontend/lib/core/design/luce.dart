import 'package:flutter/painting.dart';

import 'colori.dart';

/// L'alone dell'ottone.
///
/// **La regola, e non è un consiglio: una sola sorgente di luce accesa per
/// volta.** Il codice precedente applicava `bagliore()` a otto cose diverse
/// contemporaneamente in cinque file — pulsanti, schede, badge, trofei — e
/// quando tutto brilla l'alone smette di essere informazione e diventa texture.
///
/// Nel sistema la luce ha esattamente tre usi legittimi:
///
/// 1. sotto il podio della squadra **di turno**;
/// 2. intorno alla tessera **in gioco**;
/// 3. sul campo di input **con il fuoco**.
///
/// Non esiste un quarto uso. In particolare **un pulsante non brilla**: se un
/// pulsante ha bisogno di un alone per farsi trovare, il problema è la sua
/// posizione o la sua dimensione, non la sua luminosità.
abstract final class Luce {
  /// L'alone. [intensita] è l'opacità al centro; oltre 0.45 l'ottone comincia a
  /// slavare il blu sotto e la tessera perde il bordo.
  static List<BoxShadow> alone({
    Color colore = Colori.ottone,
    double intensita = 0.34,
  }) =>
      [
        BoxShadow(
          color: colore.withValues(alpha: intensita),
          blurRadius: 24,
          spreadRadius: -6,
        ),
      ];

  /// L'alone attenuato, per la luce che è accesa ma non è il soggetto.
  static List<BoxShadow> aloneTenue({Color colore = Colori.ottone}) =>
      alone(colore: colore, intensita: 0.18);
}
