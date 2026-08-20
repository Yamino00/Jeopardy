import 'package:flutter/painting.dart';

/// Spazi, raggi, aree tattili. Un insieme chiuso di valori: se una misura non è
/// qui, non si inventa nel widget.
abstract final class Misure {
  // ---------------------------------------------------------------- spazi
  /// Scala di spaziatura. Passo di 4, che è il passo delle densità Android.
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;

  // ----------------------------------------------------------------- fuga
  /// **La fuga fra le tessere.** Non è un margine scelto a occhio: è un
  /// elemento portante del sistema.
  ///
  /// Nessuna coppia di due blu arriva a 3:1 di contrasto — provate tutte le
  /// combinazioni fondo/tessera, il massimo è 2,36, e [Colori.quadro] su
  /// [Colori.notte] sta a 1,64:1. Una tessera blu su fondo blu **non si stacca
  /// per luminanza**: il bordo lo fa il vuoto.
  ///
  /// È anche il motivo per cui i tabelloni del genere hanno fughe nere spesse.
  /// Sotto i 3dp l'effetto crolla e la griglia diventa una macchia.
  static const double fuga = 4;

  /// Fuga fra i blocchi di categoria, il doppio: separa i gruppi prima delle
  /// singole tessere.
  static const double fugaCategoria = 8;

  // ---------------------------------------------------------------- raggi
  /// Le tessere. Raggio piccolo: sono lastre, non bolle. Un raggio grande su
  /// una griglia serrata mangia la fuga e fa perdere l'allineamento delle file.
  static const Radius raggioTessera = Radius.circular(3);

  /// La placca della domanda a tutto schermo.
  static const Radius raggioPlacca = Radius.circular(4);

  /// Cartellini del podio e superfici di controllo.
  static const Radius raggioCartellino = Radius.circular(6);

  static const BorderRadius bordoTessera = BorderRadius.all(raggioTessera);
  static const BorderRadius bordoPlacca = BorderRadius.all(raggioPlacca);
  static const BorderRadius bordoCartellino =
      BorderRadius.all(raggioCartellino);

  // --------------------------------------------------------- aree tattili
  /// Minimo assoluto per qualunque bersaglio tattile. Sotto questo valore non
  /// si scende, nemmeno per far stare un layout.
  static const double areaTattileMinima = 48;

  /// L'annulla. Più grande del minimo perché è l'azione che l'host cerca col
  /// pollice mentre guarda il tavolo, non lo schermo — e perché sbagliare ad
  /// assegnare i punti è il guasto d'uso più frequente.
  static const double areaAnnulla = 56;

  // ------------------------------------------------------------- larghezze
  /// Misura massima della domanda, in caratteri. Senza un tetto, su tablet in
  /// orizzontale una domanda si stende su righe da 90 caratteri.
  static const int caratteriMassimiDomanda = 32;

  /// Larghezza massima dei contenuti di lettura (form, dialog, riepilogo).
  static const double larghezzaLettura = 560;

  /// Sotto questa larghezza il tabellone passa al layout a colonna-etichetta
  /// invece delle categorie in testa. Non è un "breakpoint da telefono": è il
  /// punto in cui cinque intestazioni di categoria non stanno più affiancate
  /// senza scendere sotto la leggibilità.
  static const double sogliaColonnaEtichetta = 520;

  /// Sopra questa larghezza la placca della domanda si sdoppia: la domanda a
  /// sinistra, l'assegnazione dei punti a destra. Non è un vezzo responsive —
  /// su un tablet appoggiato al tavolo il gruppo legge a sinistra mentre l'host
  /// arriva col pollice a destra, e le due cose non si disturbano.
  static const double sogliaDueColonne = 720;

  /// Spessore del bordo di luce sulla tessera in gioco.
  static const double bordoLuce = 2;
}
