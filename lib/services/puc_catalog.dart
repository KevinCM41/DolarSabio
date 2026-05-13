// lib/services/puc_catalog.dart
// Carga y parsea el archivo PUC desde assets.

import 'package:flutter/services.dart' show rootBundle;

import '../models/puc_entry.dart';

class PucCatalog {
  static final List<PucSection> _sections = [];
  static final List<PucEntry> _flat = [];
  static bool _loaded = false;
  static String? _loadError;

  static bool get isLoaded => _loaded;
  static String? get loadError => _loadError;

  static List<PucSection> get sections => List.unmodifiable(_sections);

  static List<PucEntry> get allEntries => List.unmodifiable(_flat);

  /// Códigos únicos ordenados numéricamente.
  static List<String> get codigosOrdenados {
    final set = <String>{};
    for (final e in _flat) {
      set.add(e.codigo);
    }
    final list = set.toList();
    list.sort((a, b) {
      final ia = int.tryParse(a) ?? 0;
      final ib = int.tryParse(b) ?? 0;
      if (ia != ib) return ia.compareTo(ib);
      return a.compareTo(b);
    });
    return list;
  }

  static List<String> cuentasParaCodigo(String codigo) {
    final names = _flat
        .where((e) => e.codigo == codigo)
        .map((e) => e.cuenta)
        .toList();
    return names;
  }

  /// Entradas del catálogo para un código (puede haber varias cuentas por código).
  static List<PucEntry> entriesForCodigo(String codigo) {
    return _flat.where((e) => e.codigo == codigo).toList();
  }

  /// Texto listo para UI o contexto de IA: clase PUC y nombres oficiales.
  static String describeCodigoEnCatalogo(String codigo) {
    final list = entriesForCodigo(codigo);
    if (list.isEmpty) {
      return 'Este código no aparece en el catálogo PUC cargado en la app. '
          'Verifica el número o la versión del archivo en assets.';
    }
    final buf = StringBuffer();
    buf.writeln('Clase (según PUC en la app):');
    buf.writeln(list.first.claseTitulo);
    buf.writeln('');
    buf.writeln('Cuentas oficiales asociadas al código $codigo:');
    for (final e in list) {
      buf.writeln('• ${e.cuenta}');
    }
    return buf.toString().trim();
  }

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(
        'PLAN ÚNICO DE CUENTAS (PUC) 2026 -.txt',
      );
      _parse(raw);
      _loadError = null;
    } catch (e) {
      _loadError = e.toString();
    } finally {
      _loaded = true;
    }
  }

  static void _parse(String raw) {
    _sections.clear();
    _flat.clear();
    final lineRx = RegExp(r'^(\d{2,4})\s+(.+)$');
    PucSection? current;

    for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('===')) continue;
      if (line.startsWith('PLAN ')) continue;
      if (line.startsWith('Adaptado')) continue;

      if (line.startsWith('CLASE ') && line.contains('-')) {
        current = PucSection(titulo: line);
        _sections.add(current);
        continue;
      }

      final m = lineRx.firstMatch(line);
      if (m != null && current != null) {
        final codigo = m.group(1)!;
        final cuenta = m.group(2)!.trim();
        final entry = PucEntry(
          claseTitulo: current.titulo,
          codigo: codigo,
          cuenta: cuenta,
        );
        current.entries.add(entry);
        _flat.add(entry);
      }
    }
  }
}
