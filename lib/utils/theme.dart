// lib/utils/theme.dart
// Paleta de colores que replica el diseño oscuro del App.tsx original

import 'package:flutter/material.dart';

class AppTheme {
  // ── Colores base mejorados ────────────────────────────────────────────────
  static const Color darkBg = Color.fromARGB(255, 10, 39, 16);        // Azul oscuro profesional
  static const Color darkSurface = Color.fromARGB(255, 18, 61, 36);   // Superficie más profunda
  static const Color darkCard = Color.fromARGB(255, 26, 71, 41);      // Card con gradiente azul
  static const Color darkBorder = Color.fromARGB(255, 46, 111, 49);    // Borde más visible
  static const Color darkMuted = Color.fromARGB(255, 124, 184, 129);     // Gris azulado
  static const Color darkText = Color(0xFFF0F4FF);      // Blanco cálido

  static const Color accentPrimary = Color.fromARGB(255, 0, 255, 64); // Cyan vibrante
  static const Color accentSecondary = Color.fromARGB(255, 0, 227, 57); // Cyan oscuro
  static const Color accentRed = Color(0xFFFF6B6B);     // Rojo moderno
  static const Color accentIndigo = Color.fromARGB(255, 255, 217, 92);  // Púrpura vibrante
  static const Color accentGreen = Color.fromARGB(255, 200, 245, 0);   // Verde neón

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        colorScheme: const ColorScheme.dark(
          surface: darkSurface,
          primary: accentPrimary,
          secondary: accentIndigo,
          error: accentRed,
          onSurface: darkText,
        ),
        cardTheme: CardThemeData(
          color: darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: darkBorder),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accentPrimary),
          ),
          labelStyle: const TextStyle(
              color: darkMuted, fontSize: 11, fontWeight: FontWeight.w700),
          hintStyle: const TextStyle(color: darkMuted, fontSize: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentPrimary,
            foregroundColor: darkBg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.5),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: darkText),
          bodyMedium: TextStyle(color: darkText, fontSize: 13),
          bodySmall: TextStyle(color: darkMuted, fontSize: 11),
          labelSmall: TextStyle(
              color: darkMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5),
        ),
        fontFamily: 'GoogleSans',
      );

  // ── Helpers ───────────────────────────────────────────────────────────────
  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? darkBorder),
      );

  static TextStyle get monoStyle => const TextStyle(
        fontFamily: 'RobotoMono',
        color: darkText,
        fontSize: 13,
      );

  static TextStyle get labelStyle => const TextStyle(
        color: darkMuted,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      );
}
