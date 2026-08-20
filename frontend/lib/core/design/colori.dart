import 'package:flutter/painting.dart';

/// I sei colori del sistema. Ogni token è definito da **cosa fa**, non da dove
/// sta, e ogni rapporto di contrasto in questo file è calcolato, non stimato.
///
/// La regola che tiene insieme il sistema: **il blu è il gioco, l'ottone è la
/// luce, e ciò che non è né blu né ottone è la macchina.** Corollario operativo:
/// una sola sorgente di luce accesa per volta. Se tutto brilla, niente è
/// illuminato.
abstract final class Colori {
  /// Il fondo, e soprattutto **la fuga fra le tessere** (vedi [Misure.fuga]).
  /// È anche il dorso della tessera girata: una tessera giocata sparisce nel
  /// fondo invece di portare un segno di spunta.
  static const Color notte = Color(0xFF0B1533);

  /// La faccia della tessera e la placca della domanda. Blu di plancia, cupo e
  /// desaturato: è la scelta che permette a [ghiaccio] di stare a 9,57:1 sopra
  /// senza vibrare, e che tiene la distanza dal blu elettrico del marchio.
  static const Color quadro = Color(0xFF22377E);

  /// Il testo, su entrambi i blu: 15,69:1 su [notte], 9,57:1 su [quadro].
  /// Bianco **freddo e non puro** — il bianco pieno in grassetto su blu è metà
  /// della trade dress, e alle dimensioni display produce halation.
  static const Color ghiaccio = Color(0xFFEAF0FA);

  /// La luce, e solo la luce: è ciò che **emette**, mai un riempimento
  /// decorativo. Alone sotto il podio di turno, bordo della tessera aperta.
  /// 8,35:1 su [notte], 5,10:1 su [quadro]; [notte] sopra dà 8,35:1.
  ///
  /// Ottone caldo e non giallo puro: il giallo pieno ha luminanza 0,93 e su blu
  /// saturo vibra. Se compare come colore di riempimento di un pulsante, è un
  /// bug del sistema, non una variante.
  static const Color ottone = Color(0xFFE9A33C);

  /// La ferramenta: bordi, etichette secondarie, nomi di categoria.
  /// 8,43:1 su [notte] e 5,14:1 su [quadro] — schiarito appositamente fino a
  /// passare AA su **entrambi** i blu.
  static const Color acciaio = Color(0xFFA3B2D2);

  /// La macchina che si fa sentire: errori, rete assente, quota esaurita.
  /// 8,06:1 su [notte], 4,92:1 su [quadro]. Non compare mai in una partita che
  /// funziona.
  static const Color segnale = Color(0xFFF59480);
}

/// Gli smalti proposti alle squadre.
///
/// Sono **dati, non token di sistema**: il backend salva un esadecimale per
/// squadra e l'utente può sceglierne uno qualsiasi, quindi questi sei sono solo
/// il default offerto.
///
/// Il colore non porta l'identità della squadra — la portano il nome e la
/// posizione stabile nella rastrelliera. Sei tinte tutte distinguibili sotto
/// deuteranopia, protanopia e tritanopia su un unico fondo scuro è un problema
/// sovravincolato (la coppia peggiore resta a dE 10,3), quindi il colore è un
/// **intarsio** laterale, indizio secondario. Da cui la regola dura:
///
/// > Uno smalto squadra non sta **mai** dietro del testo. È una banda, non una
/// > superficie.
///
/// Vale per qualunque esadecimale arrivi dal backend, ed è il motivo per cui
/// non serve più calcolare a mano un contrasto per il testo sopra.
///
/// I sei default stanno su una scala di chiarezza (3,7:1 → 10,1:1 contro
/// [Colori.notte]) perché la chiarezza è l'unica dimensione che sopravvive a
/// tutte le deficienze cromatiche.
abstract final class SmaltiSquadra {
  static const Color vermiglio = Color(0xFFC6482F);
  static const Color guado = Color(0xFF6C84CB);
  static const Color alloro = Color(0xFF6BA343);
  static const Color rosa = Color(0xFFD392AD);
  static const Color pervinca = Color(0xFFBBA7D7);
  static const Color cenere = Color(0xFFC8C1B6);

  /// Nell'ordine in cui vengono proposti: la scala di chiarezza.
  static const List<Color> tutti = [
    vermiglio,
    guado,
    alloro,
    rosa,
    pervinca,
    cenere,
  ];
}

/// Converte `'#RRGGBB'` in un [Color]; tollera il cancelletto assente e
/// l'input nullo, che è il caso di una squadra senza colore scelto.
///
/// Il ripiego è [Colori.acciaio], non [Colori.ottone]: l'ottone significa
/// "in gioco" e non può diventare il colore di una squadra qualsiasi.
Color coloreDaHex(String? hex, {Color ripiego = Colori.acciaio}) {
  if (hex == null || hex.isEmpty) return ripiego;
  final pulito = hex.replaceFirst('#', '');
  if (pulito.length != 6) return ripiego;
  final valore = int.tryParse(pulito, radix: 16);
  if (valore == null) return ripiego;
  return Color(0xFF000000 | valore);
}

/// Serializza un [Color] in `'#rrggbb'`, la forma che il backend si aspetta.
String hexDaColore(Color colore) {
  final argb = colore.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
