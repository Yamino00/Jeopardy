import 'package:flutter/painting.dart';

import 'colori.dart';
import 'misure.dart';

/// Le due famiglie, la scala, e i ruoli tipografici.
///
/// **Display: Archivo all'asse `wdth` 125** — espanso, non condensato. Il
/// riflesso "game show" porta a un condensato pesante, che è sia il default del
/// genere sia la strada verso il carattere del marchio (uno Swiss 911, cioè un
/// condensato). Le lettere larghe si leggono meglio a distanza: la scelta
/// risolve due problemi con una mossa.
///
/// **Testo: Libre Franklin** — lignaggio Franklin Gothic, altezza-x generosa,
/// aperture larghe, diacritici italiani solidi. È la voce delle domande.
///
/// Entrambi sono file variabili in `assets/fonts`: nessun pacchetto, primo frame
/// senza rete, funziona offline.
abstract final class Tipografia {
  static const String famigliaDisplay = 'Archivo';
  static const String famigliaTesto = 'LibreFranklin';

  /// I default di Archivo sono `wght` 600 e `wdth` 100, quindi **ogni** stile
  /// display deve dichiarare le variazioni esplicitamente: la mappatura
  /// implicita da `fontWeight` all'asse `wght` non è affidabile fra le versioni
  /// dell'engine. Verificato sul file scaricato: `wght` 100–900, `wdth` 62–125.
  static const List<FontVariation> _espansoNero = [
    FontVariation('wdth', 125),
    FontVariation('wght', 900),
  ];
  static const List<FontVariation> _espansoGrassetto = [
    FontVariation('wdth', 125),
    FontVariation('wght', 700),
  ];

  // ------------------------------------------------------------- la domanda

  /// Estremi del fit-to-box della domanda. Vedi [dimensioneDomanda] per la
  /// regola che li governa.
  static const double domandaMinima = 30;
  static const double domandaMassima = 46;

  /// La domanda: il ruolo più importante del progetto.
  ///
  /// Allineata a sinistra (non centrata: su più righe il centrato fa ripartire
  /// l'occhio da un'ascissa diversa a ogni riga, e a un metro e mezzo si paga),
  /// interlinea 1.30, tracking leggermente negativo perché alle dimensioni
  /// display il testo si compatta bene.
  static TextStyle domanda(double dimensione) => TextStyle(
        fontFamily: famigliaTesto,
        fontSize: dimensione,
        fontWeight: FontWeight.w500,
        height: 1.30,
        letterSpacing: dimensione * -0.01,
        color: Colori.ghiaccio,
      );

  /// La risposta, che compare sotto la domanda. Proporzionata alla domanda
  /// invece di avere una misura propria, così il rapporto fra le due resta
  /// costante a ogni dimensione del box.
  static TextStyle risposta(double dimensioneDellaDomanda) {
    final d = dimensioneDellaDomanda * 0.62;
    return TextStyle(
      fontFamily: famigliaDisplay,
      fontVariations: _espansoNero,
      fontSize: d,
      fontWeight: FontWeight.w900,
      height: 1.15,
      letterSpacing: d * 0.04,
      color: Colori.ghiaccio,
    );
  }

  // -------------------------------------------------------- la tessera

  /// Il numerale sulla faccia della tessera. Cifre tabulari: in una griglia le
  /// colonne di numeri devono allinearsi, e con `punti_base` 500 e 5 righe il
  /// backend arriva a valori di quattro cifre.
  static TextStyle numeraleTessera(double dimensione) => TextStyle(
        fontFamily: famigliaDisplay,
        fontVariations: _espansoNero,
        fontSize: dimensione,
        fontWeight: FontWeight.w900,
        height: 1.0,
        color: Colori.ghiaccio,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// L'intestazione di categoria.
  static TextStyle headerCategoria(double dimensione) => TextStyle(
        fontFamily: famigliaDisplay,
        fontVariations: _espansoGrassetto,
        fontSize: dimensione,
        fontWeight: FontWeight.w700,
        height: 1.10,
        letterSpacing: dimensione * 0.10,
        color: Colori.acciaio,
      );

  static const double headerCategoriaMinimo = 13;
  static const double headerCategoriaMassimo = 16;

  // ---------------------------------------------------------- il podio

  /// Le cifre del punteggio a palette.
  static TextStyle punteggio(double dimensione) => TextStyle(
        fontFamily: famigliaDisplay,
        fontVariations: _espansoNero,
        fontSize: dimensione,
        fontWeight: FontWeight.w900,
        height: 1.0,
        letterSpacing: dimensione * 0.02,
        color: Colori.ghiaccio,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static const TextStyle nomeSquadra = TextStyle(
    fontFamily: famigliaTesto,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.20,
    color: Colori.ghiaccio,
  );

  // ------------------------------------------------------------- la UI

  static const TextStyle titolo = TextStyle(
    fontFamily: famigliaDisplay,
    fontVariations: _espansoGrassetto,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 20 * 0.02,
    color: Colori.ghiaccio,
  );

  /// Il nome dell'app nella schermata iniziale. È l'unico posto in cui il
  /// display arriva a questo corpo, e l'unico in cui la tipografia è il
  /// soggetto invece di essere il veicolo.
  static const TextStyle marchio = TextStyle(
    fontFamily: famigliaDisplay,
    fontVariations: _espansoNero,
    fontSize: 44,
    fontWeight: FontWeight.w900,
    height: 1.05,
    letterSpacing: 44 * 0.06,
    color: Colori.ghiaccio,
  );

  static const TextStyle corpo = TextStyle(
    fontFamily: famigliaTesto,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: Colori.ghiaccio,
  );

  static const TextStyle corpoRilievo = TextStyle(
    fontFamily: famigliaTesto,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: Colori.ghiaccio,
  );

  static const TextStyle corpoMinore = TextStyle(
    fontFamily: famigliaTesto,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: Colori.acciaio,
  );

  /// Etichette di servizio: codici, stati, intestazioni di campo.
  static const TextStyle ferramenta = TextStyle(
    fontFamily: famigliaTesto,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.20,
    letterSpacing: 12 * 0.06,
    color: Colori.acciaio,
  );

  /// Il testo dentro un chip acceso: scuro sull'ottone, 8,35:1.
  static const TextStyle sullaLuce = TextStyle(
    fontFamily: famigliaDisplay,
    fontVariations: _espansoNero,
    fontSize: 14,
    fontWeight: FontWeight.w900,
    letterSpacing: 14 * 0.03,
    color: Colori.notte,
  );

  static const double numeraleMinimo = 16;
  static const double numeraleMassimo = 40;

  // ------------------------------------------------------- il fit-to-box

  /// Trentadue caratteri di testo italiano rappresentativo, usati per misurare
  /// la larghezza corrispondente a [Misure.caratteriMassimiDomanda]. Misurare
  /// una stringa reale è più onesto che moltiplicare la larghezza di una cifra.
  static const String _campione32 = 'aeioustnrlcdpmgvbz aeioustnrlcd';

  /// Larghezza, in pixel logici, che corrisponde alla misura massima della
  /// domanda alla dimensione [dimensione].
  static double larghezzaMisuraDomanda(double dimensione) {
    final p = TextPainter(
      text: TextSpan(text: _campione32, style: domanda(dimensione)),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    return p.width;
  }

  /// Sceglie la dimensione **base** del numerale di una tessera.
  ///
  /// Stessa regola della domanda: la base si calcola a textScaler 1.0 e il
  /// fattore dell'utente si applica sopra. In particolare **non** si usa un
  /// `FittedBox`, che rimpicciolirebbe il testo gia' scalato e annullerebbe
  /// l'impostazione di accessibilita'.
  ///
  /// Il numerale non ha ritorni a capo: quando la scala dell'utente lo rende
  /// piu' alto della tessera, cresce la tessera e il tabellone scorre.
  static double dimensioneNumerale({
    required String testo,
    required Size spazio,
  }) {
    bool entra(double dimensione) {
      final p = TextPainter(
        text: TextSpan(text: testo, style: numeraleTessera(dimensione)),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      )..layout();
      return p.width <= spazio.width && p.height <= spazio.height;
    }

    if (entra(numeraleMassimo)) return numeraleMassimo;
    var basso = numeraleMinimo;
    var alto = numeraleMassimo;
    while (alto - basso > 0.5) {
      final mezzo = (basso + alto) / 2;
      if (entra(mezzo)) {
        basso = mezzo;
      } else {
        alto = mezzo;
      }
    }
    return basso;
  }

  /// Sceglie la dimensione **base** della domanda dentro
  /// [domandaMinima]–[domandaMassima].
  ///
  /// La regola, che non ha eccezioni discrezionali:
  ///
  /// 1. La base si calcola **a textScaler 1.0**, da lunghezza del testo e
  ///    spazio disponibile. Questa funzione usa [TextScaler.noScaling] proprio
  ///    per questo.
  /// 2. Il fattore di scala dell'utente si applica **sopra** la base, dal
  ///    normale meccanismo di Flutter, e non viene mai compensato. Se un ramo di
  ///    codice legge `textScaler` per ridurre la dimensione base, è un bug.
  /// 3. Quando il risultato non ci sta, **non si rimpicciolisce: scorre il
  ///    layout.** Chi chiama questa funzione mette il testo in uno scrollable.
  ///
  /// [spazio] è lo spazio disponibile a scala 1.0.
  static double dimensioneDomanda({
    required String testo,
    required Size spazio,
  }) {
    if (testo.isEmpty) return domandaMassima;

    bool entra(double dimensione) {
      final larghezzaMassima = spazio.width < larghezzaMisuraDomanda(dimensione)
          ? spazio.width
          : larghezzaMisuraDomanda(dimensione);
      final p = TextPainter(
        text: TextSpan(text: testo, style: domanda(dimensione)),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout(maxWidth: larghezzaMassima);
      return p.height <= spazio.height && !p.didExceedMaxLines;
    }

    // Ricerca binaria a passo di mezzo punto: sotto il mezzo punto la
    // differenza non è percepibile e le iterazioni si pagano a ogni layout.
    var basso = domandaMinima;
    var alto = domandaMassima;
    if (entra(alto)) return alto;
    while (alto - basso > 0.5) {
      final mezzo = (basso + alto) / 2;
      if (entra(mezzo)) {
        basso = mezzo;
      } else {
        alto = mezzo;
      }
    }
    // Se nemmeno il minimo entra, si restituisce il minimo: il testo non si
    // rimpicciolisce oltre, e il contenitore scorre.
    return basso;
  }
}
