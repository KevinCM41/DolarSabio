// lib/utils/theme.dart
// Paleta de colores que replica el diseño oscuro del App.tsx original

import 'package:flutter/material.dart';

class AppTheme {
  // ── Colores base ──────────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF0C0C0F);
  static const Color darkSurface = Color(0xFF111114);
  static const Color darkCard = Color(0xFF151518);
  static const Color darkBorder = Color(0xFF222226);
  static const Color darkMuted = Color(0xFF64748B);
  static const Color darkText = Color(0xFFE2E8F0);

  static const Color accentPrimary = Color(0xFF10B981); // emerald-500
  static const Color accentRed = Color(0xFFEF4444);     // rose-500
  static const Color accentIndigo = Color(0xFF6366F1);  // indigo-500

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
