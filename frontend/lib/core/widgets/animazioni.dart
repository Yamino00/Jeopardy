import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/design.dart';

/// Entrata in scena: dissolvenza + risalita, con ritardo progressivo così gli
/// elementi di una lista non compaiono tutti insieme di colpo.
class ComparsaAnimata extends StatelessWidget {
  const ComparsaAnimata({
    super.key,
    required this.child,
    this.indice = 0,
    this.scostamento = 18,
  });

  final Widget child;

  /// Posizione nella lista: determina il ritardo.
  final int indice;
  final double scostamento;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(indice),
      tween: Tween(begin: 0, end: 1),
      duration: context.durata(Movimento.normale),
      curve: Movimento.curva,
      builder: (context, t, figlio) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, scostamento * (1 - t)),
          child: figlio,
        ),
      ),
      child: child,
    );
  }
}

/// Scheda o pulsante che rimpicciolisce alla pressione.
///
/// C4: prima era un `GestureDetector` nudo — nessun ruolo di pulsante, nessuna
/// etichetta, nessuna area minima garantita, nessun feedback aptico. Per
/// TalkBack semplicemente **non esisteva**: l'annulla, l'avvio partita e le
/// schede squadra erano invisibili a chi non vede lo schermo.
class PremibileAnimato extends StatefulWidget {
  const PremibileAnimato({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.etichetta,
    this.suggerimento,
    this.scalaPremuta = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Cosa annuncia uno screen reader. Se è nulla, il chiamante deve avere già
  /// un `Semantics` proprio più in alto — è il caso dell'annulla e della
  /// tessera, che descrivono se stessi con più contesto di quanto potremmo
  /// fare qui.
  final String? etichetta;

  final String? suggerimento;
  final double scalaPremuta;

  @override
  State<PremibileAnimato> createState() => _PremibileAnimatoState();
}

class _PremibileAnimatoState extends State<PremibileAnimato> {
  bool _premuto = false;

  bool get _attivo => widget.onTap != null || widget.onLongPress != null;

  void _imposta(bool premuto) {
    if (!_attivo) return;
    setState(() => _premuto = premuto);
  }

  void _tocca() {
    // Un feedback aptico leggero: su un tabellone toccato al buio, in gruppo,
    // conferma il tocco senza che serva guardare.
    HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  void _pressioneLunga() {
    HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final gesto = GestureDetector(
      // `opaque`: l'area vale tutta, non solo dove c'è del disegno.
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _imposta(true),
      onTapUp: (_) => _imposta(false),
      onTapCancel: () => _imposta(false),
      onTap: widget.onTap == null ? null : _tocca,
      onLongPress: widget.onLongPress == null ? null : _pressioneLunga,
      child: AnimatedScale(
        scale: _premuto ? widget.scalaPremuta : 1,
        duration: context.durata(Movimento.reazione),
        curve: Movimento.curva,
        child: widget.child,
      ),
    );

    final conArea = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: Misure.areaTattileMinima,
        minHeight: Misure.areaTattileMinima,
      ),
      child: gesto,
    );

    if (widget.etichetta == null) return conArea;
    return Semantics(
      button: widget.onTap != null,
      enabled: _attivo,
      label: widget.etichetta,
      hint: widget.suggerimento,
      onLongPress: widget.onLongPress,
      excludeSemantics: true,
      child: conArea,
    );
  }
}
