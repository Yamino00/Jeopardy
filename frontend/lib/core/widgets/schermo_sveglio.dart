import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Tiene lo schermo acceso finché [attivo] è vero e questo widget è montato.
///
/// Requisito del contesto d'uso, non un vezzo: le sessioni durano 20-40 minuti
/// **con lunghe pause di riflessione**, e il timeout di sistema arriva proprio
/// mentre il gruppo sta pensando. Un host che deve toccare lo schermo per
/// riaccenderlo ogni due minuti è un difetto d'uso, non un dettaglio.
///
/// Tre proprietà che rendono questo widget diverso da una chiamata sparsa:
///
/// 1. **Si rilascia da solo.** Il blocco muore con il widget, quindi non può
///    restare acceso dopo l'uscita dalla partita e scaricare la batteria.
/// 2. **Rispetta il ciclo di vita.** Se l'app va in secondo piano il blocco si
///    toglie, e si rimette al ritorno: tenere lo schermo di qualcun altro
///    acceso mentre la nostra app non è in primo piano non è nostro diritto.
/// 3. **Non fa cadere niente se il plugin non c'è.** Nei test il canale nativo
///    non è registrato, e una partita non deve fallire per un blocco schermo.
class SchermoSveglio extends StatefulWidget {
  const SchermoSveglio({
    super.key,
    required this.attivo,
    required this.child,
  });

  /// Vero solo mentre la partita è davvero in corso. Su una partita conclusa,
  /// o su un tabellone in anteprima, lo schermo si comporta come sempre.
  final bool attivo;

  final Widget child;

  @override
  State<SchermoSveglio> createState() => _SchermoSveglioState();
}

class _SchermoSveglioState extends State<SchermoSveglio>
    with WidgetsBindingObserver {
  bool _inPrimoPiano = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applica();
  }

  @override
  void didUpdateWidget(SchermoSveglio vecchio) {
    super.didUpdateWidget(vecchio);
    if (vecchio.attivo != widget.attivo) _applica();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    final primoPiano = stato == AppLifecycleState.resumed;
    if (primoPiano == _inPrimoPiano) return;
    _inPrimoPiano = primoPiano;
    _applica();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _imposta(false);
    super.dispose();
  }

  void _applica() => _imposta(widget.attivo && _inPrimoPiano);

  /// Il plugin è nativo: nei test non esiste, e un errore qui non deve
  /// interrompere la partita. Fallire nel tenere acceso lo schermo è un
  /// fastidio; far cadere la schermata sarebbe un guasto.
  void _imposta(bool acceso) {
    WakelockPlus.toggle(enable: acceso).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
