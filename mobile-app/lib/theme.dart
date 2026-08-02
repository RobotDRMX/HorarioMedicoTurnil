import 'package:flutter/material.dart';

/// Paleta de colores oficial de HorarioMedicoTurnil.
class HmtColors {
  static const Color textoPrincipal = Color(0xFF2A5643);
  static const Color textoSecundario = Color(0xFF3A674B);
  static const Color acento = Color(0xFF5B8A5F);
  static const Color tarjeta = Color(0xFF8CBD7F);
  static const Color fondo = Color(0xFFD8FFAD);
}

ThemeData buildHorarioMedicoTurnilTheme() {
  return ThemeData(
    primaryColor: HmtColors.textoPrincipal,
    secondaryHeaderColor: HmtColors.tarjeta,
    scaffoldBackgroundColor: HmtColors.fondo,
    colorScheme: ColorScheme.fromSeed(
      seedColor: HmtColors.acento,
      primary: HmtColors.textoPrincipal,
      secondary: HmtColors.acento,
      surface: HmtColors.fondo,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: HmtColors.textoPrincipal,
        fontWeight: FontWeight.bold,
        fontSize: 24,
      ),
      titleMedium: TextStyle(
        color: HmtColors.textoPrincipal,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
      bodyLarge: TextStyle(color: HmtColors.textoSecundario, fontSize: 16),
      bodyMedium: TextStyle(color: HmtColors.textoSecundario, fontSize: 14),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: HmtColors.textoPrincipal,
      foregroundColor: HmtColors.fondo,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: HmtColors.acento,
        foregroundColor: HmtColors.fondo,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: HmtColors.tarjeta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
    ),
    useMaterial3: true,
  );
}
