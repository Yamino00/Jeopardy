import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design.dart';

/// Lo stato di una tessera sul tabellone.
enum StatoTessera {
  /// Da giocare: faccia in su, numerale leggibile.
  faccia,

  /// Già giocata: girata, mostra il dorso. Non è un segno di spunta sopra la
  /// tessera — è la tessera che si volta, come su un tavolo.
  dorso,

  /// Aperta adesso. È l'unica cosa illuminata del tabellone.
  inGioco,
}

/// Una tessera del tabellone.
///
/// Faccia [Colori.quadro] con il numerale, dorso [Colori.notte]. Il giro è
/// esplicito — un [AnimationController] e una rotazione — e non un
/// `AnimatedSwitcher`: il movimento deve avere una direzione fisica, e al
/// cambio di stato la tessera deve *voltarsi*, non dissolversi.
class Tessera extends StatefulWidget {
  const Tessera({
    super.key,
    required this.valore,
    required this.stato,
    required this.nomeCategoria,
    required this.dimensioneNumerale,
    this.onTocco,
  });

  final int valore;
  final StatoTessera stato;

  /// La dimensione **base** del numerale, decisa una volta per tutto il
  /// tabellone da [RaccoltaTessere]: su una plancia vera tutti i valori sono
  /// composti allo stesso corpo, e misurare tessera per tessera costava un
  /// layout di testo per tessera a ogni frame del giro.
  ///
  /// È una base a scala 1.0: il fattore dell'utente si applica sopra, dal
  /// normale meccanismo di Flutter, e non viene mai compensato.
  final double dimensioneNumerale;

  /// Serve solo alla `Semantics`: uno screen reader deve sentire "Storia
  /// romana, 300 punti", non "300".
  final String nomeCategoria;

  /// Nullo quando la tessera non è giocabile.
  final VoidCallback? onTocco;

  @override
  State<Tessera> createState() => _TesseraState();
}

class _TesseraState extends State<Tessera>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giro;

  bool get _girata => widget.stato == StatoTessera.dorso;

  @override
  void initState() {
    super.initState();
    // Il valore iniziale è già quello finale: una tessera che al primo frame
    // risulta giocata non deve girarsi davanti agli occhi di nessuno.
    _giro = AnimationController(
      vsync: this,
      duration: Movimento.giro,
      value: _girata ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(Tessera vecchia) {
    super.didUpdateWidget(vecchia);
    if (_girata == (vecchia.stato == StatoTessera.dorso)) return;
    _giro.duration = context.durata(Movimento.giro);
    if (_girata) {
      _giro.forward();
    } else {
      _giro.reverse();
    }
  }

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etichetta = '${widget.nomeCategoria}, ${widget.valore} punti';

    return Semantics(
      button: widget.onTocco != null,
      enabled: widget.onTocco != null,
      label: etichetta,
      // Lo stato non sta nella label: chi usa TalkBack sente prima cosa è la
      // tessera e poi com'è, non una frase sola da decifrare.
      value: switch (widget.stato) {
        StatoTessera.faccia => 'da giocare',
        StatoTessera.dorso => 'già giocata',
        StatoTessera.inGioco => 'in gioco',
      },
      hint: widget.onTocco != null ? 'apri la domanda' : null,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: Misure.areaTattileMinima,
            minHeight: Misure.areaTattileMinima,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTocco,
            child: AnimatedBuilder(
              animation: _giro,
              builder: (context, _) {
                final angolo = _giro.value * math.pi;
                final mostraDorso = angolo > math.pi / 2;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateX(angolo),
                  child: mostraDorso
                      // Ruotata di mezzo giro, altrimenti il dorso apparirebbe
                      // riflesso.
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateX(math.pi),
                          child: const _Dorso(),
                        )
                      : _Faccia(
                          valore: widget.valore,
                          dimensione: widget.dimensioneNumerale,
                          inGioco: widget.stato == StatoTessera.inGioco,
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Faccia extends StatelessWidget {
  const _Faccia({
    required this.valore,
    required this.dimensione,
    required this.inGioco,
  });

  final int valore;
  final double dimensione;
  final bool inGioco;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colori.quadro,
        borderRadius: Misure.bordoTessera,
        border: inGioco
            ? Border.all(color: Colori.ottone, width: Misure.bordoLuce)
            : null,
        boxShadow: inGioco ? Luce.alone() : null,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Misure.s2),
          child: Text(
            '$valore',
            maxLines: 1,
            // Nessun ellipsis e nessun FittedBox: un FittedBox rimpicciolirebbe
            // il testo gia' scalato dall'utente, annullando la sua impostazione
            // di accessibilita'. Se il numerale non ci sta, deve crescere la
            // tessera — e lo fa RaccoltaTessere, che calcola l'altezza minima
            // dalla dimensione **scalata**.
            softWrap: false,
            style: Tipografia.numeraleTessera(dimensione),
          ),
        ),
      ),
    );
  }
}

class _Dorso extends StatelessWidget {
  const _Dorso();

  @override
  Widget build(BuildContext context) {
    // Notte come il fondo, quindi la tessera sparisce nel campo. Non del tutto
    // però: un filo di Acciaio (8,43:1 sul fondo) lascia leggere che lì c'era
    // una tessera. Prima questo stato era un segno di spunta al 24% di opacità,
    // cioè 2,1:1 — il contrasto più basso dell'app sull'informazione più
    // importante del tabellone.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colori.notte,
        borderRadius: Misure.bordoTessera,
        border: Border.all(color: Colori.acciaio),
      ),
    );
  }
}
