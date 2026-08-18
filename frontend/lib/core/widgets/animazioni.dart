import 'package:flutter/material.dart';

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
      duration: Duration(milliseconds: 340 + indice * 70),
      curve: Curves.easeOutCubic,
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

/// Pulsante/scheda che rimpicciolisce alla pressione: dà un feedback tattile
/// che i widget Material piatti non hanno.
class PremibileAnimato extends StatefulWidget {
  const PremibileAnimato({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scalaPremuta = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scalaPremuta;

  @override
  State<PremibileAnimato> createState() => _PremibileAnimatoState();
}

class _PremibileAnimatoState extends State<PremibileAnimato> {
  bool _premuto = false;

  void _imposta(bool premuto) {
    if (widget.onTap == null) return;
    setState(() => _premuto = premuto);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _imposta(true),
      onTapUp: (_) => _imposta(false),
      onTapCancel: () => _imposta(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _premuto ? widget.scalaPremuta : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Punteggio che scorre fino al nuovo valore invece di saltarci: durante una
/// partita rende visibile *quanto* è cambiato, non solo che è cambiato.
class PunteggioAnimato extends StatelessWidget {
  const PunteggioAnimato({
    super.key,
    required this.valore,
    required this.stile,
  });

  final int valore;
  final TextStyle stile;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // begin omesso: alla prima build parte dal valore finale (nessuna
      // animazione), poi anima dal valore corrente a quello nuovo
      tween: Tween(end: valore.toDouble()),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: stile),
    );
  }
}
