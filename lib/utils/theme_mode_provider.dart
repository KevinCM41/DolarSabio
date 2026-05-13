// lib/utils/theme_mode_provider.dart
// Preferencia de tema claro / oscuro / sistema (persistida).

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeProvider extends ChangeNotifier {
  static const _prefsKey = 'theme_mode_index';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get themeMode => _mode;

  ThemeModeProvider() {
    _load();
  }

  /// Primera carga async: notificar tras el frame para no chocar con el arranque.
  void _notifyAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final i = p.getInt(_prefsKey);
      if (i != null && i >= 0 && i < ThemeMode.values.length) {
        _mode = ThemeMode.values[i];
      }
    } finally {
      _notifyAfterFrame();
    }
  }

  /// Cambio explícito por el usuario: notificación inmediata (el flujo UI debe
  /// cerrar overlays *antes* de llamar aquí, p. ej. tras [await showModalBottomSheet]).
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_prefsKey, mode.index);
    } catch (_) {}
  }
}
