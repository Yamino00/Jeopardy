import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Una squadra a cui si possono assegnare punti. Un record e non il modello di
/// rete, così la placca si monta in un test senza costruire una `Partita`.
typedef SquadraInPlacca = ({int id, String nome, Color colore});

/// La placca: la tessera girata a tutto schermo.
///
/// È la decisione più importante del progetto, e le tre scelte che la governano
/// sono tutte controcorrente rispetto al codice che sostituisce:
///
/// 1. **Corpo adattivo, non fisso.** Prima era `fontSize: 30` sempre: troppo
///    piccolo su tablet, troppo grande per una domanda lunga su telefono. Ora
///    la dimensione si calcola dal box e dalla lunghezza del testo, dentro
///    30→46. È anche il meccanismo che rende innocuo il textScaler: non c'è
///    nessuna misura fissa da sfondare.
/// 2. **Allineata a sinistra, non centrata.** Il testo centrato su più righe fa
///    ripartire l'occhio da un'ascissa diversa a ogni riga, e a un metro e
///    mezzo si paga. Centrato resta solo ciò che è di una riga sola.
/// 3. **Misura tappata a 32 caratteri.** Su un tablet in orizzontale, senza
///    tetto, una domanda si stende su righe da 90 caratteri.
class PlaccaDomanda extends StatelessWidget {
  const PlaccaDomanda({
    super.key,
    required this.nomeCategoria,
    required this.valore,
    required this.domanda,
    required this.risposta,
    required this.rispostaVisibile,
    required this.squadre,
    required this.inviando,
    required this.onChiudi,
    required this.onMostraRisposta,
    required this.onAssegna,
    required this.onPassa,
  });

  final String nomeCategoria;
  final int valore;
  final String domanda;
  final String risposta;
  final bool rispostaVisibile;
  final List<SquadraInPlacca> squadre;
  final bool inviando;

  final VoidCallback onChiudi;
  final VoidCallback onMostraRisposta;

  /// `positivo` distingue l'assegnazione dalla sottrazione. Non c'è nessun
  /// booleano "corretta" da qualche parte nel colore: la direzione è il dato.
  final void Function(int squadraId, bool positivo) onAssegna;
  final VoidCallback onPassa;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colori.quadro,
        // Il bordo di luce: questa cella è in gioco. È l'unica cosa accesa
        // dello schermo, e lo resta.
        border: Border.all(color: Colori.ottone, width: Misure.bordoLuce),
        boxShadow: Luce.alone(),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Misure.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Testa(
                nomeCategoria: nomeCategoria,
                valore: valore,
                inviando: inviando,
                onChiudi: onChiudi,
              ),
              const SizedBox(height: Misure.s5),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, vincoli) {
                    final dueColonne =
                        vincoli.maxWidth >= Misure.sogliaDueColonne;
                    return dueColonne
                        ? _dueColonne(vincoli)
                        : _unaColonna(vincoli);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Telefono, e tablet in verticale: la domanda prende lo spazio che resta,
  // l'assegnazione sta in basso dove arriva il pollice.
  Widget _unaColonna(BoxConstraints vincoli) {
    return Builder(
      builder: (context) {
        // Lo spazio dei comandi e' riservato **prima** della rivelazione, ed e'
        // quello che servira' dopo. Altrimenti nel momento in cui la sala
        // guarda lo schermo un pulsante diventa tre righe di assegnazione e
        // spinge la domanda verso l'alto: e' lo stesso salto che faceva
        // l'AnimatedSwitcher, causato dall'altra metà del layout.
        final altezzaAzioni = math.min(
          vincoli.maxHeight * 0.55,
          _altezzaAzioni(context, squadre.length),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Domanda(testo: domanda)),
            const SizedBox(height: Misure.s4),
            _Risposta(
              testo: risposta,
              visibile: rispostaVisibile,
              larghezzaDisponibile: vincoli.maxWidth,
            ),
            const SizedBox(height: Misure.s4),
            SizedBox(
              height: altezzaAzioni,
              child: _Azioni(
                rispostaVisibile: rispostaVisibile,
                valore: valore,
                squadre: squadre,
                inviando: inviando,
                inColonna: true,
                onMostraRisposta: onMostraRisposta,
                onAssegna: onAssegna,
                onPassa: onPassa,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Quanto spazio serve alle righe di assegnazione, alla scala corrente.
  /// Se non ci sta, la lista scorre al suo interno: la domanda non si muove.
  static double _altezzaAzioni(BuildContext context, int quanteSquadre) {
    final scala = MediaQuery.textScalerOf(context);
    final riga = math.max(
      Misure.areaTattileMinima,
      scala.scale(Tipografia.nomeSquadra.fontSize!) * 1.2 + Misure.s2,
    );
    return quanteSquadre * (riga + Misure.s2) +
        Misure.s2 +
        Misure.areaTattileMinima;
  }

  // Tablet in orizzontale, il caso importante: si legge a sinistra, si assegna
  // a destra. Il gruppo e l'host non si disturbano.
  Widget _dueColonne(BoxConstraints vincoli) {
    final larghezzaDomanda = vincoli.maxWidth * 0.58;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: larghezzaDomanda,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Domanda(testo: domanda)),
              const SizedBox(height: Misure.s4),
              _Risposta(
                testo: risposta,
                visibile: rispostaVisibile,
                larghezzaDisponibile: larghezzaDomanda,
              ),
            ],
          ),
        ),
        const SizedBox(width: Misure.s6),
        Expanded(
          child: _Azioni(
            rispostaVisibile: rispostaVisibile,
            valore: valore,
            squadre: squadre,
            inviando: inviando,
            inColonna: true,
            onMostraRisposta: onMostraRisposta,
            onAssegna: onAssegna,
            onPassa: onPassa,
          ),
        ),
      ],
    );
  }
}

class _Testa extends StatelessWidget {
  const _Testa({
    required this.nomeCategoria,
    required this.valore,
    required this.inviando,
    required this.onChiudi,
  });

  final String nomeCategoria;
  final int valore;
  final bool inviando;
  final VoidCallback onChiudi;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${nomeCategoria.toUpperCase()} · $valore',
            style: Tipografia.ferramenta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Misure.s3),
        IconButton(
          key: const Key('chiudi-cella'),
          onPressed: inviando ? null : onChiudi,
          tooltip: 'Chiudi senza assegnare punti',
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

/// La domanda, con il fit-to-box e la misura tappata.
class _Domanda extends StatelessWidget {
  const _Domanda({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, vincoli) {
        // La base si calcola a scala 1.0 sullo spazio disponibile: il fattore
        // dell'utente si applica sopra e non viene compensato.
        final dimensione = Tipografia.dimensioneDomanda(
          testo: testo,
          spazio: Size(vincoli.maxWidth, vincoli.maxHeight),
        );
        final misura = math.min(
          vincoli.maxWidth,
          Tipografia.larghezzaMisuraDomanda(dimensione),
        );
        // Una riga sola sta al centro; più righe vanno a sinistra, altrimenti
        // l'occhio riparte da un'ascissa diversa a ogni riga.
        final unaRiga = _righe(testo, dimensione, misura) <= 1;

        // Quando non ci sta, scorre: non si rimpicciolisce oltre il minimo.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: vincoli.maxHeight),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: misura,
                child: Text(
                  testo,
                  textAlign: unaRiga ? TextAlign.center : TextAlign.start,
                  style: Tipografia.domanda(dimensione),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _righe(String testo, double dimensione, double larghezza) {
    final p = TextPainter(
      text: TextSpan(text: testo, style: Tipografia.domanda(dimensione)),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: larghezza);
    return p.computeLineMetrics().length;
  }
}

/// La risposta, e prima della rivelazione il **rilievo vuoto**.
///
/// Il rilievo ha la stessa altezza della risposta che comparirà: si vede che
/// c'è qualcosa da girare, e quando compare **nulla si sposta**. Prima un
/// `AnimatedSwitcher` con `SizeTransition` faceva saltare verso l'alto tutto il
/// testo della domanda nel momento in cui la sala guarda lo schermo.
class _Risposta extends StatelessWidget {
  const _Risposta({
    required this.testo,
    required this.visibile,
    required this.larghezzaDisponibile,
  });

  final String testo;
  final bool visibile;
  final double larghezzaDisponibile;

  @override
  Widget build(BuildContext context) {
    final scala = MediaQuery.textScalerOf(context);
    final stile = Tipografia.risposta(Tipografia.domandaMinima);
    final larghezzaTesto =
        math.max(0.0, larghezzaDisponibile - Misure.s4 * 2);

    // L'altezza si prende dalla risposta vera, misurata alla scala corrente:
    // così il rilievo e la risposta occupano esattamente lo stesso spazio.
    final p = TextPainter(
      text: TextSpan(text: testo.toUpperCase(), style: stile),
      textDirection: TextDirection.ltr,
      textScaler: scala,
    )..layout(maxWidth: larghezzaTesto);
    final altezza = math.max(
      Misure.areaTattileMinima,
      p.height + Misure.s3 * 2,
    );

    return Semantics(
      liveRegion: visibile,
      label: visibile ? 'Risposta: $testo' : 'Risposta ancora coperta',
      excludeSemantics: true,
      child: AnimatedContainer(
        key: const Key('rilievo-risposta'),
        duration: context.durata(Movimento.normale),
        curve: Movimento.curva,
        height: altezza,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Misure.s4),
        decoration: BoxDecoration(
          borderRadius: Misure.bordoCartellino,
          border: Border.all(color: Colori.acciaio),
          color: visibile ? Colori.notte : null,
        ),
        child: visibile
            ? Text(
                testo.toUpperCase(),
                textAlign: TextAlign.center,
                style: stile,
              )
            : const Text('RISPOSTA COPERTA', style: Tipografia.ferramenta),
      ),
    );
  }
}

class _Azioni extends StatelessWidget {
  const _Azioni({
    required this.rispostaVisibile,
    required this.valore,
    required this.squadre,
    required this.inviando,
    required this.inColonna,
    required this.onMostraRisposta,
    required this.onAssegna,
    required this.onPassa,
  });

  final bool rispostaVisibile;
  final int valore;
  final List<SquadraInPlacca> squadre;
  final bool inviando;
  final bool inColonna;
  final VoidCallback onMostraRisposta;
  final void Function(int squadraId, bool positivo) onAssegna;
  final VoidCallback onPassa;

  @override
  Widget build(BuildContext context) {
    if (!rispostaVisibile) {
      return Align(
        alignment: Alignment.center,
        child: FilledButton.icon(
          key: const Key('mostra-risposta'),
          onPressed: inviando ? null : onMostraRisposta,
          icon: const Icon(Icons.visibility_rounded),
          label: const Text('Mostra risposta'),
        ),
      );
    }

    final righe = [
      for (final squadra in squadre)
        _RigaAssegnazione(
          squadra: squadra,
          valore: valore,
          inviando: inviando,
          onAssegna: onAssegna,
        ),
      const SizedBox(height: Misure.s2),
      TextButton(
        key: const Key('passa-cella'),
        onPressed: inviando ? null : onPassa,
        child: const Text('Nessuno risponde · passa'),
      ),
    ];

    if (!inColonna) {
      return Column(mainAxisSize: MainAxisSize.min, children: righe);
    }
    // In due colonne la lista può essere più lunga della sua metà: scorre lei,
    // non tutta la placca.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: righe,
      ),
    );
  }
}

/// Una squadra, e i suoi due comandi: **acceso e spento**.
///
/// Corretto e sbagliato non sono codificati dalla tinta. Il codice precedente
/// usava `#4ADE80` e `#FF6B6B` — verde e rosso Tailwind, la coppia peggiore per
/// gli 8% di uomini con deficienza rosso-verde, ed è la scelta che fa ogni app
/// di quiz. Qui l'assegnazione è un chip **riempito di luce** con testo scuro
/// (8,35:1) e la sottrazione è **solo un contorno**: la differenza è il
/// riempimento e il segno, e funziona in bianco e nero.
class _RigaAssegnazione extends StatelessWidget {
  const _RigaAssegnazione({
    required this.squadra,
    required this.valore,
    required this.inviando,
    required this.onAssegna,
  });

  final SquadraInPlacca squadra;
  final int valore;
  final bool inviando;
  final void Function(int squadraId, bool positivo) onAssegna;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Misure.s2),
      child: Row(
        children: [
          IntarsioInRiga(colore: squadra.colore),
          Expanded(
            child: Text(
              squadra.nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tipografia.nomeSquadra,
            ),
          ),
          const SizedBox(width: Misure.s3),
          _Chip(
            key: Key('togli-${squadra.id}'),
            etichetta: '−$valore',
            semantica: 'Togli $valore punti a ${squadra.nome}',
            acceso: false,
            onTocco: inviando ? null : () => onAssegna(squadra.id, false),
          ),
          const SizedBox(width: Misure.s2),
          _Chip(
            key: Key('assegna-${squadra.id}'),
            etichetta: '+$valore',
            semantica: 'Assegna $valore punti a ${squadra.nome}',
            acceso: true,
            onTocco: inviando ? null : () => onAssegna(squadra.id, true),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.etichetta,
    required this.semantica,
    required this.acceso,
    required this.onTocco,
  });

  final String etichetta;
  final String semantica;
  final bool acceso;
  final VoidCallback? onTocco;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTocco != null,
      label: semantica,
      excludeSemantics: true,
      child: SizedBox(
        height: Misure.areaTattileMinima,
        child: acceso
            ? FilledButton(onPressed: onTocco, child: Text(etichetta))
            : OutlinedButton(onPressed: onTocco, child: Text(etichetta)),
      ),
    );
  }
}
