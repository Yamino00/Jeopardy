/// Il design system. **Unica sorgente di colori, corpi, spazi e durate.**
///
/// Regola di progetto verificabile con grep: fuori da `lib/core/design/` non
/// esiste nessun letterale `Color(0x...)` e nessun `fontSize:`. Se ne compare
/// uno, è un valore che qualcuno ha scelto in un widget invece di scegliere nel
/// sistema.
///
/// Il concetto: **la plancia dello studio, di notte.** Un blu profondo che porta
/// le tessere, e una sola luce — l'ottone del faretto — che non riempie mai
/// niente e cade solo su ciò che è in gioco.
library;

export 'colori.dart';
export 'intarsio.dart';
export 'luce.dart';
export 'misure.dart';
export 'movimento.dart';
export 'tema.dart';
export 'tipografia.dart';
