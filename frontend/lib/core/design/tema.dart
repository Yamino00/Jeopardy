import 'package:flutter/material.dart';

import 'colori.dart';
import 'misure.dart';
import 'tipografia.dart';

/// Il tema Material costruito dai token.
///
/// Il tema precedente esisteva e non governava niente: usava
/// `ColorScheme.fromSeed` e poi ogni widget bypassava il `colorScheme` per
/// pescare da costanti globali. Qui il `ColorScheme` è scritto a mano, senza
/// seed, perché i sei colori hanno ruoli precisi e non c'è nessuna armonia da
/// far derivare a una funzione.
///
/// **Zero gradienti.** Notte e Quadro sono tinte piatte; l'unica sfumatura
/// ammessa nel sistema è la caduta di luce dell'ottone, che è un fenomeno e non
/// una decorazione — e vive nei widget che la disegnano, non nel tema.
abstract final class Tema {
  static ThemeData get scuro {
    const schema = ColorScheme(
      brightness: Brightness.dark,
      // Il blu è il gioco.
      primary: Colori.quadro,
      onPrimary: Colori.ghiaccio,
      primaryContainer: Colori.quadro,
      onPrimaryContainer: Colori.ghiaccio,
      // L'ottone è la luce: secondario perché non riempie quasi mai niente.
      secondary: Colori.ottone,
      onSecondary: Colori.notte,
      secondaryContainer: Colori.ottone,
      onSecondaryContainer: Colori.notte,
      // La ferramenta.
      tertiary: Colori.acciaio,
      onTertiary: Colori.notte,
      // Ciò che non è né blu né ottone è la macchina.
      error: Colori.segnale,
      onError: Colori.notte,
      errorContainer: Colori.segnale,
      onErrorContainer: Colori.notte,
      surface: Colori.notte,
      onSurface: Colori.ghiaccio,
      surfaceContainer: Colori.quadro,
      onSurfaceVariant: Colori.acciaio,
      outline: Colori.acciaio,
      outlineVariant: Colori.acciaio,
      shadow: Colori.notte,
      scrim: Colori.notte,
      inverseSurface: Colori.ghiaccio,
      onInverseSurface: Colori.notte,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: schema,
      scaffoldBackgroundColor: Colori.notte,
      fontFamily: Tipografia.famigliaTesto,
      textTheme: const TextTheme(
        titleLarge: Tipografia.titolo,
        titleMedium: Tipografia.nomeSquadra,
        bodyLarge: Tipografia.corpo,
        bodyMedium: Tipografia.corpo,
        bodySmall: Tipografia.corpoMinore,
        labelSmall: Tipografia.ferramenta,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colori.notte,
        foregroundColor: Colori.ghiaccio,
        surfaceTintColor: Colori.notte,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: Tipografia.titolo,
      ),
      cardTheme: const CardThemeData(
        color: Colori.quadro,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Misure.bordoCartellino),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colori.quadro,
        surfaceTintColor: Colori.quadro,
        elevation: 0,
        titleTextStyle: Tipografia.titolo,
        contentTextStyle: Tipografia.corpo,
        shape: RoundedRectangleBorder(borderRadius: Misure.bordoCartellino),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colori.quadro,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Misure.s4,
          vertical: Misure.s3,
        ),
        labelStyle: Tipografia.corpoMinore,
        helperStyle: Tipografia.ferramenta,
        hintStyle: Tipografia.corpoMinore,
        errorStyle: Tipografia.ferramenta.copyWith(color: Colori.segnale),
        border: const OutlineInputBorder(
          borderRadius: Misure.bordoCartellino,
          borderSide: BorderSide(color: Colori.acciaio),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: Misure.bordoCartellino,
          borderSide: BorderSide(color: Colori.acciaio),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: Misure.bordoCartellino,
          borderSide: BorderSide(color: Colori.ottone, width: Misure.bordoLuce),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: Misure.bordoCartellino,
          borderSide: BorderSide(color: Colori.segnale),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: Misure.bordoCartellino,
          borderSide: BorderSide(color: Colori.segnale, width: Misure.bordoLuce),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colori.ottone,
          foregroundColor: Colori.notte,
          minimumSize: const Size(0, Misure.areaTattileMinima),
          shape: const RoundedRectangleBorder(
            borderRadius: Misure.bordoCartellino,
          ),
          textStyle: Tipografia.sullaLuce,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colori.ghiaccio,
          minimumSize: const Size(0, Misure.areaTattileMinima),
          side: const BorderSide(color: Colori.acciaio),
          shape: const RoundedRectangleBorder(
            borderRadius: Misure.bordoCartellino,
          ),
          textStyle: Tipografia.corpoRilievo,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colori.acciaio,
          minimumSize: const Size(0, Misure.areaTattileMinima),
          textStyle: Tipografia.corpoRilievo,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Colori.ghiaccio,
          minimumSize: const Size.square(Misure.areaTattileMinima),
        ),
      ),
      iconTheme: const IconThemeData(color: Colori.ghiaccio),
      dividerTheme: const DividerThemeData(
        color: Colori.acciaio,
        thickness: 1,
        space: Misure.s4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colori.quadro,
        labelStyle: Tipografia.corpoMinore.copyWith(color: Colori.ghiaccio),
        side: const BorderSide(color: Colori.acciaio),
        shape: const RoundedRectangleBorder(
          borderRadius: Misure.bordoCartellino,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: Colori.notte,
          foregroundColor: Colori.acciaio,
          selectedBackgroundColor: Colori.ottone,
          selectedForegroundColor: Colori.notte,
          side: const BorderSide(color: Colori.acciaio),
          shape: const RoundedRectangleBorder(
            borderRadius: Misure.bordoCartellino,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colori.quadro,
        contentTextStyle: Tipografia.corpo,
        actionTextColor: Colori.ottone,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: Misure.bordoCartellino),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Colori.ottone,
        linearTrackColor: Colori.quadro,
        circularTrackColor: Colori.quadro,
      ),
    );
  }
}
