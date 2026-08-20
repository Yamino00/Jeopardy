import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design.dart';
import 'tessera.dart';

/// Una tessera, senza dipendenze dai modelli di rete: così la griglia si
/// costruisce in un test senza inventare un `Tabellone` intero.
class DatiTessera {
  const DatiTessera({
    required this.id,
    required this.valore,
    required this.stato,
  });

  final int id;
  final int valore;
  final StatoTessera stato;
}

class CategoriaTessere {
  const CategoriaTessere({required this.nome, required this.tessere});

  final String nome;
  final List<DatiTessera> tessere;
}

/// Il tabellone.
///
/// Due layout veri, scelti sulla **larghezza** e non sull'orientamento: un
/// tablet in verticale è largo 800dp e merita le categorie in testa alle
/// colonne, mentre un telefono in orizzontale è basso e non le merita. La
/// soglia è [Misure.sogliaColonnaEtichetta].
///
/// **Non scorre in orizzontale, mai.** Il codice precedente imponeva 158dp per
/// colonna: su un telefono in verticale con cinque categorie servivano 790dp,
/// quindi si vedevano due categorie e mezzo su cinque. Il tabellone è l'oggetto
/// centrale del gioco e si deve vedere intero.
///
/// Scorre in verticale **solo quando serve**: alle scale di testo alte le
/// tessere crescono, e a quel punto vince chi ha chiesto testo grande.
class RaccoltaTessere extends StatelessWidget {
  const RaccoltaTessere({
    super.key,
    required this.categorie,
    this.onTocco,
  });

  final List<CategoriaTessere> categorie;

  /// Riceve l'id della tessera toccata.
  final void Function(int id)? onTocco;

  int get _tesserePerCategoria =>
      categorie.fold(0, (m, c) => math.max(m, c.tessere.length));

  /// Il numerale più largo del tabellone. La dimensione del carattere si
  /// decide su questo, non tessera per tessera: su una plancia vera tutti i
  /// valori sono composti allo stesso corpo, e misurare 25 volte costa 25
  /// layout di testo per ogni frame di rotazione.
  String get _numeraleMaggiore {
    var peggiore = '';
    for (final c in categorie) {
      for (final t in c.tessere) {
        final s = '${t.valore}';
        if (s.length > peggiore.length) peggiore = s;
      }
    }
    return peggiore.isEmpty ? '0' : peggiore;
  }

  @override
  Widget build(BuildContext context) {
    if (categorie.isEmpty) return const SizedBox.shrink();

    final scala = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, vincoli) {
        final stretto = vincoli.maxWidth < Misure.sogliaColonnaEtichetta;

        // 1. La larghezza della tessera si conosce subito: dipende solo dalla
        //    larghezza disponibile e da quante tessere stanno in fila.
        final inFila = stretto ? _tesserePerCategoria : categorie.length;
        final larghezza = inFila == 0
            ? 0.0
            : (vincoli.maxWidth - Misure.fuga * (inFila - 1)) / inFila;

        // 2. Da lì, la dimensione **base** del numerale, misurata a scala 1.0.
        //    È il punto in cui la regola textScaler non va tradita: la base non
        //    guarda il fattore dell'utente.
        final dimensioneNumerale = Tipografia.dimensioneNumerale(
          testo: _numeraleMaggiore,
          spazio: Size(
            math.max(0, larghezza - Misure.s3 * 2),
            Tipografia.numeraleMassimo * 1.25,
          ),
        );

        // 3. Solo adesso l'altezza. Il fattore dell'utente si applica sopra la
        //    base e non viene compensato, quindi l'altezza minima della tessera
        //    è quella che serve al numerale **scalato**. Se non ci sta, si
        //    scorre: non si rimpicciolisce il testo di chi ha chiesto testo
        //    grande, e la tessera non lo ritaglia in silenzio.
        final altezzaMinima = math.max(
          Misure.areaTattileMinima,
          scala.scale(dimensioneNumerale) * 1.25 + Misure.s2 * 2,
        );

        final (contenuto, necessaria) = stretto
            ? _perFile(vincoli, scala, altezzaMinima, dimensioneNumerale)
            : _perColonne(vincoli, scala, altezzaMinima, dimensioneNumerale);

        // Scorre solo se non ci sta. A scala normale il tabellone si vede
        // intero e non c'è nessuna barra di scorrimento.
        if (necessaria <= vincoli.maxHeight) {
          return SizedBox(height: vincoli.maxHeight, child: contenuto);
        }
        return SingleChildScrollView(
          child: SizedBox(height: necessaria, child: contenuto),
        );
      },
    );
  }

  // ------------------------------------------------------------ schermo largo
  // Il tabellone classico: categorie in testa, valori che scendono.

  (Widget, double) _perColonne(
    BoxConstraints vincoli,
    TextScaler scala,
    double altezzaMinima,
    double dimensioneNumerale,
  ) {
    final righe = _tesserePerCategoria;
    final altezzaHeader =
        scala.scale(Tipografia.headerCategoriaMassimo) * 2.2 + Misure.s3 * 2;

    final spazio = vincoli.maxHeight - altezzaHeader - Misure.fugaCategoria;
    final ideale =
        righe == 0 ? 0.0 : (spazio - Misure.fuga * (righe - 1)) / righe;
    final altezza = math.max(ideale, altezzaMinima);
    final necessaria = altezzaHeader +
        Misure.fugaCategoria +
        altezza * righe +
        Misure.fuga * math.max(0, righe - 1);

    final colonne = <Widget>[];
    for (var c = 0; c < categorie.length; c++) {
      if (c > 0) colonne.add(const SizedBox(width: Misure.fuga));
      colonne.add(
        Expanded(
          child: Column(
            children: [
              SizedBox(
                height: altezzaHeader,
                child: _Intestazione(nome: categorie[c].nome),
              ),
              const SizedBox(height: Misure.fugaCategoria),
              for (var r = 0; r < righe; r++) ...[
                if (r > 0) const SizedBox(height: Misure.fuga),
                SizedBox(
                  height: altezza,
                  child: r < categorie[c].tessere.length
                      ? _tessera(categorie[c], categorie[c].tessere[r],
                          dimensioneNumerale)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return (
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: colonne),
      necessaria,
    );
  }

  // ----------------------------------------------------------- schermo stretto
  // Una categoria per fila, col nome sopra. Il piano prevedeva una
  // colonna-etichetta a sinistra: a textScaler 2.0 un nome di categoria in
  // 72dp fissi non si legge, e il nome sopra non ha quel limite.

  (Widget, double) _perFile(
    BoxConstraints vincoli,
    TextScaler scala,
    double altezzaMinima,
    double dimensioneNumerale,
  ) {
    final altezzaNome =
        scala.scale(Tipografia.headerCategoriaMinimo) * 1.35 + Misure.s1;
    final n = categorie.length;
    final perNomi = (altezzaNome + Misure.s1) * n;
    final spazio =
        vincoli.maxHeight - perNomi - Misure.fugaCategoria * math.max(0, n - 1);
    final ideale = n == 0 ? 0.0 : spazio / n;
    final altezza = math.max(ideale, altezzaMinima);
    final necessaria = (altezzaNome + Misure.s1 + altezza) * n +
        Misure.fugaCategoria * math.max(0, n - 1);

    final file = <Widget>[];
    for (var c = 0; c < categorie.length; c++) {
      if (c > 0) file.add(const SizedBox(height: Misure.fugaCategoria));
      final tessere = categorie[c].tessere;
      file.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: altezzaNome,
              width: double.infinity,
              child: _Intestazione(
                nome: categorie[c].nome,
                allineataASinistra: true,
              ),
            ),
            const SizedBox(height: Misure.s1),
            SizedBox(
              height: altezza,
              child: Row(
                children: [
                  for (var t = 0; t < tessere.length; t++) ...[
                    if (t > 0) const SizedBox(width: Misure.fuga),
                    Expanded(
                      child: _tessera(
                          categorie[c], tessere[t], dimensioneNumerale),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return (
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: file),
      necessaria,
    );
  }

  Widget _tessera(
    CategoriaTessere categoria,
    DatiTessera dati,
    double dimensioneNumerale,
  ) =>
      Tessera(
        key: ValueKey(dati.id),
        valore: dati.valore,
        stato: dati.stato,
        nomeCategoria: categoria.nome,
        dimensioneNumerale: dimensioneNumerale,
        onTocco: dati.stato == StatoTessera.faccia && onTocco != null
            ? () => onTocco!(dati.id)
            : null,
      );
}

/// Il nome di una categoria.
///
/// Non è una tessera e non deve sembrarlo: nessun riempimento, nessun bordo.
/// È ferramenta stampata sul fondo, e sta in Acciaio (8,43:1 sul fondo).
class _Intestazione extends StatelessWidget {
  const _Intestazione({required this.nome, this.allineataASinistra = false});

  final String nome;
  final bool allineataASinistra;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          allineataASinistra ? Alignment.bottomLeft : Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: allineataASinistra ? 0 : Misure.s1,
        ),
        child: Text(
          nome.toUpperCase(),
          textAlign: allineataASinistra ? TextAlign.start : TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Tipografia.headerCategoria(
            allineataASinistra
                ? Tipografia.headerCategoriaMinimo
                : Tipografia.headerCategoriaMassimo,
          ),
        ),
      ),
    );
  }
}
