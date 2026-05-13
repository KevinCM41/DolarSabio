// lib/utils/theme.dart
// Temas claro y oscuro + colores semánticos vía [BuildContext] (extensión).

import 'package:flutter/material.dart';

class AppTheme {
  // ── Paleta oscura (original) ─────────────────────────────────────────────
  static const Color darkBg = Color.fromARGB(255, 10, 39, 16);
  static const Color darkSurface = Color.fromARGB(255, 18, 61, 36);
  static const Color darkCard = Color.fromARGB(255, 26, 71, 41);
  static const Color darkBorder = Color.fromARGB(255, 46, 111, 49);
  static const Color darkMuted = Color.fromARGB(255, 124, 184, 129);
  static const Color darkText = Color(0xFFF0F4FF);

  // ── Paleta clara ─────────────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF1F7F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color.fromARGB(255, 216, 241, 224);
  static const Color lightBorder = Color(0xFF9DBAA8);
  static const Color lightMuted = Color(0xFF3D5A45);
  static const Color lightOnSurface = Color(0xFF0A1F12);

  static const Color accentPrimary = Color.fromARGB(255, 0, 255, 64);
  static const Color accentSecondary = Color.fromARGB(255, 0, 227, 57);
  static const Color accentRed = Color(0xFFFF6B6B);
  static const Color accentIndigo = Color.fromARGB(255, 255, 217, 92);
  static const Color accentGreen = Color.fromARGB(255, 200, 245, 0);

  /// Icono / texto sobre bloques de [accentPrimary] (contraste con verde neón).
  static const Color onAccentBrand = Color(0xFF021608);

  /// Logo de marca (registrado en pubspec).
  static const String logoAsset = 'assets/images/DolarSabio.jpg';

  /// Botón principal en modo claro (mejor contraste sobre blanco).
  static const Color lightPrimaryButton = Color(0xFF0D7A3E);
  static const Color lightPrimaryButtonOn = Color(0xFFFFFFFF);

  // ── ThemeData ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBg,
        colorScheme: ColorScheme.light(
          surface: lightSurface,
          primary: lightPrimaryButton,
          onPrimary: lightPrimaryButtonOn,
          secondary: const Color(0xFF047857),
          error: accentRed,
          onSurface: lightOnSurface,
          outline: lightBorder,
        ),
        cardTheme: CardThemeData(
          color: lightCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: lightBorder),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: lightPrimaryButton, width: 1.5),
          ),
          labelStyle: const TextStyle(
              color: lightMuted, fontSize: 11, fontWeight: FontWeight.w700),
          hintStyle: const TextStyle(color: lightMuted, fontSize: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightPrimaryButton,
            foregroundColor: lightPrimaryButtonOn,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.5),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: lightOnSurface),
          bodyMedium: TextStyle(color: lightOnSurface, fontSize: 13),
          bodySmall: TextStyle(color: lightMuted, fontSize: 11),
          labelSmall: TextStyle(
              color: lightMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5),
        ),
        fontFamily: 'GoogleSans',
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        colorScheme: const ColorScheme.dark(
          surface: darkSurface,
          primary: accentPrimary,
          onPrimary: darkBg,
          secondary: accentIndigo,
          error: accentRed,
          onSurface: darkText,
          outline: darkBorder,
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

  /// Alias del tema oscuro (compatibilidad).
  static ThemeData get theme => darkTheme;

  static TextStyle monoStyleFor(Color onSurface) => TextStyle(
        fontFamily: 'RobotoMono',
        color: onSurface,
        fontSize: 13,
      );
}

/// Colores de superficie según el brillo actual del [Theme].
extension AppThemeContext on BuildContext {
  bool get isAppDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appBackground =>
      isAppDarkMode ? AppTheme.darkBg : AppTheme.lightBg;

  Color get appSurface =>
      isAppDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface;

  Color get appCard => isAppDarkMode ? AppTheme.darkCard : AppTheme.lightCard;

  Color get appBorder =>
      isAppDarkMode ? AppTheme.darkBorder : AppTheme.lightBorder;

  Color get appMuted => isAppDarkMode ? AppTheme.darkMuted : AppTheme.lightMuted;

  Color get appOnSurface =>
      isAppDarkMode ? AppTheme.darkText : AppTheme.lightOnSurface;

  BoxDecoration appCardDecoration({Color? borderColor}) => BoxDecoration(
        color: appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? appBorder),
      );

  TextStyle get appLabelStyle => TextStyle(
        color: appMuted,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      );

  TextStyle get appMonoStyle => AppTheme.monoStyleFor(appOnSurface);
}
