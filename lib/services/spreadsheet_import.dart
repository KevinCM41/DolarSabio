// lib/services/spreadsheet_import.dart
// Normalización de cabeceras y filas común a import Excel / CSV.

/// Quita BOM, espacios, mayúsculas y acentos típicos para emparejar columnas.
String normalizeImportHeaderKey(String raw) {
  var s = raw.trim();
  if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) {
    s = s.substring(1).trim();
  }
  s = s.toUpperCase();
  for (final p in _accentPairs) {
    s = s.replaceAll(p.$1, p.$2);
  }
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _accentPairs = <(String, String)>[
  ('Á', 'A'),
  ('É', 'E'),
  ('Í', 'I'),
  ('Ó', 'O'),
  ('Ú', 'U'),
  ('Ü', 'U'),
  ('Ñ', 'N'),
  ('À', 'A'),
  ('È', 'E'),
  ('Ì', 'I'),
  ('Ò', 'O'),
  ('Ù', 'U'),
];

/// Construye mapa cabecera normalizada → valor celda (última columna gana si hay duplicados).
Map<String, String> buildNormalizedHeaderMap(
  List<String> headers,
  List<String> values,
) {
  final m = <String, String>{};
  final n = headers.length < values.length ? headers.length : values.length;
  for (var i = 0; i < n; i++) {
    final k = normalizeImportHeaderKey(headers[i]);
    if (k.isEmpty) continue;
    m[k] = values[i].trim();
  }
  return m;
}

String _pickField(Map<String, String> row, List<String> aliases) {
  for (final a in aliases) {
    final want = normalizeImportHeaderKey(a);
    final v = row[want];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  final compactAliases = aliases.map((a) => normalizeImportHeaderKey(a).replaceAll(' ', '')).toList();
  for (final e in row.entries) {
    final ck = e.key.replaceAll(' ', '');
    for (final want in compactAliases) {
      if (want.isEmpty) continue;
      if (ck == want || ck.contains(want) || want.contains(ck)) {
        if (e.value.trim().isNotEmpty) return e.value.trim();
      }
    }
  }
  return '';
}

/// Acepta `1.234,56` / `1,234.56` / espacios / símbolo moneda simple.
double? parseImportAmount(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s.replaceAll(RegExp(r'[\s\$€]'), '');
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    if (lastComma > lastDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (lastComma >= 0) {
    final parts = s.split(',');
    if (parts.length == 2 && parts[1].length <= 2) {
      s = '${parts[0].replaceAll('.', '')}.${parts[1]}';
    } else {
      s = s.replaceAll(',', '.');
    }
  }
  return double.tryParse(s);
}

/// Convierte una fila ya indexada por cabecera normalizada al mapa que usa [HomeScreen._rowToTransaction].
Map<String, dynamic> importRowToPayload(Map<String, String> row) {
  final recordId = _pickField(row, ['ID', 'RECORDID', 'RECORD ID']);
  final codigo = _pickField(row, ['CODIGO', 'CODE', 'CÓDIGO']);
  final cuenta = _pickField(row, ['CUENTA', 'ACCOUNT', 'NOMBRE CUENTA', 'NOMBRE DE CUENTA']);
  final descripcion = _pickField(row, [
    'DESCRIPCION',
    'DESCRIPCIÓN',
    'DETALLE',
    'CONCEPTO',
    'GLOSA',
  ]);
  var fecha = _pickField(row, ['FECHA', 'DATE']);
  if (fecha.isEmpty) {
    fecha = DateTime.now().toIso8601String().split('T').first;
  }
  final debStr = _pickField(row, ['DEBITO', 'DÉBITO', 'DEBIT', 'DEB']);
  final credStr = _pickField(row, ['CREDITO', 'CRÉDITO', 'CREDIT', 'CRED', 'HABER']);
  final debito = parseImportAmount(debStr) ?? 0.0;
  final credito = parseImportAmount(credStr) ?? 0.0;

  return {
    'recordId': recordId,
    'codigo': codigo,
    'cuenta': cuenta,
    'descripcion': descripcion,
    'fecha': fecha,
    'debito': debito,
    'credito': credito,
  };
}

bool importRowLooksEmpty(Map<String, dynamic> payload) {
  final c = (payload['codigo'] as String?)?.trim() ?? '';
  final u = (payload['cuenta'] as String?)?.trim() ?? '';
  final d = (payload['descripcion'] as String?)?.trim() ?? '';
  final deb = (payload['debito'] as num?)?.toDouble() ?? 0;
  final cred = (payload['credito'] as num?)?.toDouble() ?? 0;
  return c.isEmpty && u.isEmpty && d.isEmpty && deb == 0 && cred == 0;
}

/// Orden de columnas al exportar en Excel/CSV (idéntico en [ExcelService] / [CsvService]).
Map<String, dynamic> importFromFixedColumnOrder(List<String> cols) {
  final padded = List<String>.from(cols);
  while (padded.length < 7) {
    padded.add('');
  }
  final c = padded.sublist(0, 7);
  var fecha = c[4].trim();
  if (fecha.isEmpty) {
    fecha = DateTime.now().toIso8601String().split('T').first;
  }
  return {
    'recordId': c[0].trim(),
    'codigo': c[1].trim(),
    'cuenta': c[2].trim(),
    'descripcion': c[3].trim(),
    'fecha': fecha,
    'debito': parseImportAmount(c[5].trim()) ?? 0.0,
    'credito': parseImportAmount(c[6].trim()) ?? 0.0,
  };
}

String _mergeImportStr(dynamic byNameVal, dynamic byPosVal) {
  final a = byNameVal?.toString().trim() ?? '';
  if (a.isNotEmpty) return a;
  return byPosVal?.toString().trim() ?? '';
}

/// Combina mapeo por cabecera (archivos ajenos) y por **posición** (export propio con etiquetas renombradas
/// o montos que no matchean alias como DEB/CRED).
Map<String, dynamic> buildImportPayload(
  Map<String, String> headerKeyToValue,
  List<String> valuesInColumnOrder,
) {
  final byName = importRowToPayload(headerKeyToValue);
  if (valuesInColumnOrder.length < 7) {
    return byName;
  }
  final byPos = importFromFixedColumnOrder(valuesInColumnOrder);

  final dn = (byName['debito'] as num?)?.toDouble() ?? 0.0;
  final cn = (byName['credito'] as num?)?.toDouble() ?? 0.0;
  final dp = (byPos['debito'] as num?)?.toDouble() ?? 0.0;
  final cp = (byPos['credito'] as num?)?.toDouble() ?? 0.0;

  var fecha = _mergeImportStr(byName['fecha'], byPos['fecha']);
  if (fecha.isEmpty) {
    fecha = DateTime.now().toIso8601String().split('T').first;
  }

  final usePosAmounts = dn == 0 && cn == 0 && (dp != 0 || cp != 0);

  return {
    'recordId': _mergeImportStr(byName['recordId'], byPos['recordId']),
    'codigo': _mergeImportStr(byName['codigo'], byPos['codigo']),
    'cuenta': _mergeImportStr(byName['cuenta'], byPos['cuenta']),
    'descripcion': _mergeImportStr(byName['descripcion'], byPos['descripcion']),
    'fecha': fecha,
    'debito': usePosAmounts ? dp : dn,
    'credito': usePosAmounts ? cp : cn,
  };
}
