import 'package:flutter/material.dart';

// Palette: notte profonda con accenti elettrici. Il blu Jeopardy resta
// riconoscibile ma piu' saturo, l'oro diventa il colore dell'azione.
const Color sfondoNotte = Color(0xFF080B24);
const Color sfondoElevato = Color(0xFF121741);
const Color jeopardyBlue = Color(0xFF1B2A7B);
const Color jeopardyBlueLight = Color(0xFF3B4FD8);
const Color jeopardyGold = Color(0xFFFFC947);
const Color accentoCiano = Color(0xFF22D3EE);
const Color accentoMagenta = Color(0xFFFF4D8D);

/// Sfondo dell'app: due aloni di colore su fondo scuro. Costa poco e toglie
/// l'effetto "tinta unita piatta" senza immagini da caricare.
const BoxDecoration sfondoApp = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B1030), sfondoNotte, Color(0xFF17093A)],
    stops: [0.0, 0.55, 1.0],
  ),
);

/// Gradiente delle celle non ancora giocate.
const LinearGradient gradienteCella = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF24379E), jeopardyBlue],
);

/// Gradiente delle intestazioni di categoria.
const LinearGradient gradienteCategoria = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [jeopardyBlueLight, Color(0xFF6D28D9)],
);

/// Alone luminoso usato su elementi attivi (squadra di turno, pulsanti).
List<BoxShadow> bagliore(Color colore, {double intensita = 0.45}) => [
      BoxShadow(
        color: colore.withValues(alpha: intensita),
        blurRadius: 22,
        spreadRadius: -4,
        offset: const Offset(0, 6),
      ),
    ];

/// Colore di testo leggibile su uno sfondo qualsiasi.
///
/// I colori delle squadre sono scelti dall'utente e finiscono sotto del testo:
/// deciderne a mano il contrasto e' il modo sicuro per ritrovarsi scritte
/// scure su fondo scuro. Qui la scelta e' calcolata dalla luminanza.
Color coloreTestoSu(Color sfondo) =>
    sfondo.computeLuminance() > 0.55 ? const Color(0xFF10121F) : Colors.white;

/// Versione desaturata e scura di un colore, per farne uno sfondo su cui il
/// testo chiaro resta leggibile (usata per i badge delle squadre).
Color sfondoTenue(Color colore) =>
    Color.alphaBlend(colore.withValues(alpha: 0.22), sfondoElevato);

/// Colori proposti alle squadre.
const List<Color> squadraPalette = [
  Color(0xFFFF4D6D),
  Color(0xFF22D3EE),
  Color(0xFF4ADE80),
  Color(0xFFFFA33C),
  Color(0xFFA78BFA),
  Color(0xFFF472B6),
];

/// Parses '#RRGGBB' into a [Color]; null-safe for teams without a color.
Color parseHexColor(String? hex, {Color fallback = jeopardyGold}) {
  if (hex == null || hex.isEmpty) return fallback;
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}

String colorToHex(Color color) {
  final argb = color.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

final ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: jeopardyBlueLight,
    brightness: Brightness.dark,
    primary: jeopardyBlueLight,
    secondary: jeopardyGold,
    surface: sfondoElevato,
  ),
  scaffoldBackgroundColor: sfondoNotte,
  useMaterial3: true,
  fontFamily: 'Roboto',
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1),
    headlineMedium: TextStyle(fontWeight: FontWeight.w800),
    titleLarge: TextStyle(fontWeight: FontWeight.w700),
    bodyMedium: TextStyle(height: 1.45),
  ),
  cardTheme: CardThemeData(
    color: sfondoElevato,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: jeopardyGold, width: 2),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);
