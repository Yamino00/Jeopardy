import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design.dart';

/// Il punteggio a palette: il contatore meccanico del podio.
///
/// **È la firma del progetto**, e l'unico elemento che risolve un problema
/// invece di decorare. Il punteggio non fa un tween verso il nuovo valore: le
/// cifre **girano**, una alla volta, con un breve sfasamento — e quando il
/// punteggio scende girano **al contrario**.
///
/// Perché non un tween: `PunteggioAnimato` interpolava il numero e mostrava
/// valori intermedi **che non sono mai esistiti nel log eventi** (A4). Su un
/// punteggio negativo passava per numeri mai avvenuti. Un contatore a palette
/// non può mentire: mostra soltanto passaggi da una cifra alla successiva.
///
/// E soprattutto: l'annulla oggi non dà **nessun** feedback, benché il backend
/// restituisca già l'evento annullato. Delle palette che tornano indietro sono
/// la conferma più leggibile possibile a un metro e mezzo, senza una riga di
/// testo.
///
/// Implementato con un `CustomPainter` e **un solo** `AnimationController` per
/// podio: quattro podi che girano insieme devono stare nei 16ms, e un
/// `TextPainter` per cifra per frame non ci starebbe. Le dieci cifre sono
/// disegnate una volta e riusate.
class PunteggioPalette extends StatefulWidget {
  const PunteggioPalette({
    super.key,
    required this.valore,
    required this.dimensione,
  });

  final int valore;

  /// Corpo **base** delle cifre. Il fattore di scala dell'utente si applica
  /// sopra, dentro il painter, e non viene mai compensato.
  final double dimensione;

  @override
  State<PunteggioPalette> createState() => _PunteggioPaletteState();
}

class _PunteggioPaletteState extends State<PunteggioPalette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giro;

  /// Il valore da cui si sta girando. Al primo frame coincide con quello
  /// nuovo: un punteggio già a 400 all'apertura non deve girare da zero.
  late int _da;
  late int _a;

  PianoPalette _piano = const PianoPalette.fermo();

  /// Le dieci cifre composte, tenute fra i frame. Ricrearle a ogni rebuild
  /// vanificherebbe la ragione per cui esistono.
  _CifreDisegnate? _cifre;

  @override
  void initState() {
    super.initState();
    _da = widget.valore;
    _a = widget.valore;
    _giro = AnimationController(vsync: this, duration: Duration.zero);
  }

  @override
  void didUpdateWidget(PunteggioPalette vecchio) {
    super.didUpdateWidget(vecchio);
    if (vecchio.valore == widget.valore) return;

    // Si riparte da dove si è arrivati: se un giro è ancora in corso, il nuovo
    // parte dal valore che stava mostrando, non da quello vecchio.
    _da = _giro.isAnimating ? _a : _da;
    _a = widget.valore;
    _piano = PianoPalette.fra(_da, _a);

    final durata = context.durata(_piano.durata);
    if (durata == Duration.zero) {
      // Animazioni ridotte: il valore cambia di colpo e nulla si rompe.
      setState(() {
        _da = _a;
        _piano = const PianoPalette.fermo();
      });
      return;
    }
    _giro
      ..duration = durata
      ..forward(from: 0).then((_) {
        if (!mounted) return;
        setState(() {
          _da = _a;
          _piano = const PianoPalette.fermo();
        });
      });
  }

  @override
  void dispose() {
    _giro.dispose();
    _cifre?.smaltisci();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scala = MediaQuery.textScalerOf(context);
    final stile = Tipografia.punteggio(widget.dimensione);
    final cifre = _cifreDa(stile, scala);

    return Semantics(
      // Il valore annunciato è solo quello finale: uno screen reader non deve
      // leggere i passaggi intermedi delle palette, che non sono informazione.
      label: 'Punteggio',
      value: '${widget.valore}',
      liveRegion: true,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Il segno non è una paletta che gira: è uno stato del punteggio,
            // e sta fuori dalla rastrelliera come su un contatore vero.
            if (widget.valore < 0)
              Padding(
                padding: const EdgeInsets.only(right: Misure.s1),
                child: Text('−', style: stile),
              ),
            SizedBox(
              width: cifre.larghezzaTotale(math.max(
                _testo(_da).length,
                _testo(_a).length,
              )),
              height: cifre.altezza,
              child: AnimatedBuilder(
                animation: _giro,
                builder: (context, _) => CustomPaint(
                  painter: _PittorePalette(
                    da: _testo(_da),
                    a: _testo(_a),
                    piano: _piano,
                    avanzamento: _giro.value,
                    cifre: cifre,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Le cifre composte, ricreate solo se cambia il corpo o la scala.
  _CifreDisegnate _cifreDa(TextStyle stile, TextScaler scala) {
    final attuali = _cifre;
    if (attuali != null &&
        attuali.stile.fontSize == stile.fontSize &&
        attuali.scala == scala) {
      return attuali;
    }
    attuali?.smaltisci();
    final nuove = _CifreDisegnate(stile: stile, scala: scala);
    _cifre = nuove;
    return nuove;
  }

  /// Il segno sta fuori dalle palette: non è una cifra che gira, è uno stato
  /// del punteggio.
  String _testo(int v) => v.abs().toString();
}

/// Il piano di un giro: quanti passi fa ogni posizione e in che verso.
///
/// È pubblica perché è **il contratto della firma** ed è logica pura: la
/// direzione del giro e il numero di passi si verificano qui, con un test, e non
/// deducendoli dai pixel disegnati.
class PianoPalette {
  const PianoPalette({
    required this.passi,
    required this.indietro,
    required this.durata,
    required this.msPerPasso,
  });

  const PianoPalette.fermo()
      : passi = const [],
        indietro = false,
        durata = Duration.zero,
        msPerPasso = 0;

  /// Passi per posizione, allineati a destra come le cifre.
  final List<int> passi;

  /// Vero quando il punteggio **scende**: le palette girano al contrario.
  /// Vale sia per l'annulla sia per una sottrazione di punti, ed è giusto —
  /// la direzione racconta il verso del cambiamento, non il tipo di evento.
  final bool indietro;

  final Duration durata;

  /// Millisecondi per singolo passo di paletta. Conservato invece di essere
  /// ricalcolato: due formule diverse per lo stesso numero divergono.
  final double msPerPasso;

  factory PianoPalette.fra(int da, int a) {
    final indietro = a < da;
    final sDa = da.abs().toString();
    final sA = a.abs().toString();
    final n = math.max(sDa.length, sA.length);
    final padDa = sDa.padLeft(n, '0');
    final padA = sA.padLeft(n, '0');

    final passi = <int>[];
    for (var i = 0; i < n; i++) {
      final c = padDa.codeUnitAt(i) - 0x30;
      final v = padA.codeUnitAt(i) - 0x30;
      // Distanza ciclica nel verso scelto: una paletta non torna indietro per
      // fare meno strada, gira sempre nella direzione del cambiamento.
      passi.add(indietro ? (c - v + 10) % 10 : (v - c + 10) % 10);
    }

    final massimo = passi.isEmpty ? 0 : passi.reduce(math.max);
    // Con molti passi il tempo per passo si accorcia: altrimenti un 0→9
    // durerebbe più di un secondo e mezzo e diventerebbe fastidioso.
    final perPasso =
        (Movimento.paletta.inMilliseconds / (1 + massimo * 0.25))
            .clamp(70.0, Movimento.paletta.inMilliseconds.toDouble());
    // Se nessuna posizione si muove non c'è nulla da sfasare: lo sfasamento
    // riguarda le palette che partono, non le posizioni che esistono.
    final durata = massimo == 0
        ? Duration.zero
        : Duration(
            milliseconds: (perPasso * massimo).round() +
                Movimento.sfasamentoPaletta.inMilliseconds * math.max(0, n - 1),
          );

    return PianoPalette(
      passi: passi,
      indietro: indietro,
      durata: durata,
      msPerPasso: perPasso,
    );
  }

  /// L'avanzamento locale della posizione [i], con lo sfasamento applicato.
  double localePer(int i, double t) {
    if (i >= passi.length || passi[i] == 0) return 1;
    final totale = durata.inMilliseconds;
    if (totale == 0) return 1;
    final inizio = Movimento.sfasamentoPaletta.inMilliseconds * i / totale;
    final ampiezza = msPerPasso * passi[i] / totale;
    if (ampiezza <= 0) return 1;
    return ((t - inizio) / ampiezza).clamp(0.0, 1.0);
  }
}

/// Le dieci cifre, disegnate una volta e riusate.
///
/// È la ragione per cui quattro podi possono girare insieme senza perdere
/// frame: comporre il testo è la parte cara, e i glifi possibili sono dieci.
class _CifreDisegnate {
  _CifreDisegnate({required this.stile, required this.scala}) {
    for (var c = 0; c <= 9; c++) {
      final p = TextPainter(
        text: TextSpan(text: '$c', style: stile),
        textDirection: TextDirection.ltr,
        textScaler: scala,
      )..layout();
      _painters.add(p);
    }
  }

  final TextStyle stile;
  final TextScaler scala;
  final List<TextPainter> _painters = [];

  TextPainter operator [](int cifra) => _painters[cifra];

  void smaltisci() {
    for (final p in _painters) {
      p.dispose();
    }
  }

  /// Le cifre tabulari hanno tutte la stessa larghezza: si misura una volta.
  double get larghezzaCifra => _painters[0].width;
  double get altezza => _painters[0].height;

  double get passoOrizzontale => larghezzaCifra + Misure.s1 / 2;

  double larghezzaTotale(int quanteCifre) =>
      passoOrizzontale * quanteCifre - Misure.s1 / 2;
}

class _PittorePalette extends CustomPainter {
  _PittorePalette({
    required this.da,
    required this.a,
    required this.piano,
    required this.avanzamento,
    required this.cifre,
  });

  final String da;
  final String a;
  final PianoPalette piano;
  final double avanzamento;
  final _CifreDisegnate cifre;

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.max(da.length, a.length);
    final padDa = da.padLeft(n, '0');
    final padA = a.padLeft(n, '0');

    for (var i = 0; i < n; i++) {
      final x = i * cifre.passoOrizzontale;
      final partenza = padDa.codeUnitAt(i) - 0x30;
      final arrivo = padA.codeUnitAt(i) - 0x30;
      final passi = i < piano.passi.length ? piano.passi[i] : 0;

      if (passi == 0) {
        _cifraFerma(canvas, x, arrivo);
        continue;
      }

      final locale = piano.localePer(i, avanzamento);
      final passoCorrente = math.min((locale * passi).floor(), passi - 1);
      final dentro = (locale * passi) - passoCorrente;
      final corrente = _dopo(partenza, passoCorrente);
      final successiva = _dopo(partenza, passoCorrente + 1);

      if (locale >= 1) {
        _cifraFerma(canvas, x, arrivo);
      } else {
        _cifraCheGira(canvas, x, corrente, successiva, dentro);
      }
    }
  }

  int _dopo(int partenza, int passi) => piano.indietro
      ? (partenza - passi + 100) % 10
      : (partenza + passi) % 10;

  Rect _riquadro(double x) =>
      Rect.fromLTWH(x, 0, cifre.larghezzaCifra, cifre.altezza);

  void _cifraFerma(Canvas canvas, double x, int cifra) {
    _tessera(canvas, _riquadro(x));
    cifre[cifra].paint(canvas, Offset(x, 0));
    _cucitura(canvas, _riquadro(x));
  }

  /// Un passo di paletta, in due tempi: la metà che se ne va si schiaccia
  /// verso la cucitura, poi quella che arriva si apre da lì.
  ///
  /// La rotazione è resa con una scalatura verticale: su una tela 2D è quello
  /// che fa un tabellone vero visto di fronte, e costa una `scale` invece di
  /// una matrice con prospettiva.
  void _cifraCheGira(
    Canvas canvas,
    double x,
    int corrente,
    int successiva,
    double dentro,
  ) {
    final r = _riquadro(x);
    final mezzo = r.top + r.height / 2;
    _tessera(canvas, r);

    // Le due metà statiche: in avanti si scopre la nuova sopra e resta la
    // vecchia sotto; indietro è lo specchio.
    final sopraFerma = piano.indietro ? corrente : successiva;
    final sottoFerma = piano.indietro ? successiva : corrente;
    _mezzaCifra(canvas, r, sopraFerma, alto: true);
    _mezzaCifra(canvas, r, sottoFerma, alto: false);

    // La paletta in movimento.
    final primaMeta = dentro < 0.5;
    final t = primaMeta ? dentro * 2 : (dentro - 0.5) * 2;
    final scalaY = primaMeta ? 1 - t : t;
    final cifraMobile = primaMeta ? corrente : successiva;
    // In avanti: prima cade la metà alta della cifra corrente, poi arriva la
    // metà bassa della nuova. Indietro: al contrario.
    final metaAlta = piano.indietro ? !primaMeta : primaMeta;

    canvas.save();
    canvas.translate(0, mezzo);
    canvas.scale(1, scalaY.clamp(0.0, 1.0));
    canvas.translate(0, -mezzo);
    _mezzaCifra(canvas, r, cifraMobile, alto: metaAlta, conFondo: true);
    canvas.restore();

    _cucitura(canvas, r);
  }

  void _tessera(Canvas canvas, Rect r) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Misure.raggioTessera),
      Paint()..color = Colori.notte,
    );
  }

  void _mezzaCifra(
    Canvas canvas,
    Rect r,
    int cifra, {
    required bool alto,
    bool conFondo = false,
  }) {
    final meta = alto
        ? Rect.fromLTWH(r.left, r.top, r.width, r.height / 2)
        : Rect.fromLTWH(r.left, r.top + r.height / 2, r.width, r.height / 2);
    canvas.save();
    canvas.clipRect(meta);
    if (conFondo) {
      canvas.drawRect(meta, Paint()..color = Colori.notte);
    }
    cifre[cifra].paint(canvas, Offset(r.left, r.top));
    canvas.restore();
  }

  void _cucitura(Canvas canvas, Rect r) {
    final y = r.top + r.height / 2;
    canvas.drawLine(
      Offset(r.left, y),
      Offset(r.right, y),
      Paint()
        ..color = Colori.acciaio
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PittorePalette vecchio) =>
      vecchio.avanzamento != avanzamento ||
      vecchio.da != da ||
      vecchio.a != a;
}
