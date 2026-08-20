import 'package:flutter/widgets.dart';

/// Una curva, poche durate, e **un solo punto in cui si legge la preferenza di
/// sistema sulle animazioni**.
///
/// Il codice precedente aveva cinque durate hardcoded e scollegate
/// (110/260/280/320/450ms) sparse in quattro file, e zero occorrenze di
/// `MediaQuery.disableAnimationsOf`: il requisito "durate a zero se l'utente ha
/// ridotto le animazioni" non era implementato da nessuna parte.
abstract final class Movimento {
  /// Reazione al tocco. Sotto i 120ms il tocco sembra rotto, sopra i 160
  /// sembra lento.
  static const Duration reazione = Duration(milliseconds: 140);

  /// La durata di riferimento: comparse, cambi di stato, transizioni interne.
  static const Duration normale = Duration(milliseconds: 280);

  /// Il giro della tessera e l'apertura della placca — l'unico movimento che ha
  /// diritto di farsi guardare.
  static const Duration giro = Duration(milliseconds: 520);

  /// Un passo di paletta del punteggio. Le cifre girano una alla volta con
  /// questo sfasamento fra l'una e l'altra.
  static const Duration paletta = Duration(milliseconds: 180);
  static const Duration sfasamentoPaletta = Duration(milliseconds: 55);

  /// L'ottone ha **inerzia termica**: un filamento non si accende e non si
  /// spegne alla stessa velocità. È l'unico posto del sistema in cui andata e
  /// ritorno hanno durate diverse, e serve a far sembrare la luce una cosa
  /// fisica invece di un'opacità che cambia.
  static const Duration accende = Duration(milliseconds: 380);
  static const Duration spegne = Duration(milliseconds: 900);

  /// La curva condivisa. Decelerazione senza rimbalzo: gli oggetti del sistema
  /// sono lastre, e una lastra non rimbalza.
  static const Curve curva = Curves.easeOutCubic;

  /// Per ciò che entra da fuori schermo.
  static const Curve curvaEntrata = Curves.easeOutQuart;

  /// Per la luce, che sale e scende senza spigoli.
  static const Curve curvaLuce = Curves.easeInOutSine;
}

/// L'**unico** punto del progetto in cui si consulta
/// `MediaQuery.disableAnimationsOf`. Tutto il resto passa da qui.
///
/// Uso:
/// ```dart
/// AnimatedContainer(duration: context.durata(Movimento.normale), ...)
/// ```
///
/// Quando l'utente ha ridotto le animazioni le durate diventano zero e nulla si
/// rompe: gli stati cambiano di colpo, che è esattamente ciò che ha chiesto.
extension DurateAccessibili on BuildContext {
  /// [d] ridotta a zero se l'utente ha disattivato le animazioni.
  Duration durata(Duration d) =>
      MediaQuery.disableAnimationsOf(this) ? Duration.zero : d;

  /// Vero se le animazioni sono disattivate. Da usare solo quando servirebbe
  /// saltare del tutto una costruzione — per le durate basta [durata].
  bool get animazioniRidotte => MediaQuery.disableAnimationsOf(this);
}
