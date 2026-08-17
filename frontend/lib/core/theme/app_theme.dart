import 'package:flutter/material.dart';

/// Jeopardy look: deep blue board, golden values.
const Color jeopardyBlue = Color(0xFF0B1B6B);
const Color jeopardyBlueLight = Color(0xFF2438A8);
const Color jeopardyGold = Color(0xFFF5C542);

/// Team colors offered when creating a squadra.
const List<Color> squadraPalette = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFB8C00),
  Color(0xFF8E24AA),
  Color(0xFF00ACC1),
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
    seedColor: jeopardyBlue,
    brightness: Brightness.dark,
    primary: jeopardyBlueLight,
    secondary: jeopardyGold,
  ),
  scaffoldBackgroundColor: const Color(0xFF060D33),
  useMaterial3: true,
  cardTheme: const CardThemeData(
    color: jeopardyBlue,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF060D33),
    foregroundColor: Colors.white,
  ),
);
