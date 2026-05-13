// lib/services/csv_service.dart
// Exportación de transacciones a CSV (UTF-8 con BOM para Excel).

import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';
import '../platform/android_save_downloads.dart';
import 'spreadsheet_import.dart';

const String _kCsvMime = 'text/csv; charset=utf-8';

class CsvService {
  /// El paquete `csv` por defecto espera `\r\n`. Para tolerar archivos guardados con `\n`
  /// (Dart `writeln`, Unix-only) o con `\r` (Mac clásico), normalizamos antes y forzamos `\n`.
  /// Además probamos `;` y tab si con coma todo queda en una sola columna.
  static List<List<dynamic>> _parseCsvRows(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    List<List<dynamic>> conv(String delim) => CsvToListConverter(
          shouldParseNumbers: false,
          fieldDelimiter: delim,
          eol: '\n',
          allowInvalid: true,
        ).convert(normalized);

    var rows = conv(',');
    if (rows.isEmpty) return rows;
    var bestLen = rows.first.length;

    if (bestLen < 7 && normalized.contains(';')) {
      final semi = conv(';');
      if (semi.isNotEmpty && semi.first.length > bestLen) {
        rows = semi;
        bestLen = rows.first.length;
      }
    }
    if (bestLen < 7 && normalized.contains('\t')) {
      final tabs = conv('\t');
      if (tabs.isNotEmpty && tabs.first.length > bestLen) {
        rows = tabs;
      }
    }
    return rows;
  }

  static Future<void> exportToCsv(
    BuildContext context,
    List<Transaction> transactions,
    Map<String, String> labels,
  ) async {
    final bytes = _encodeCsv(transactions, labels);
    final stem = 'DolarSabio_Export_${DateTime.now().millisecondsSinceEpoch}';
    await _pickSaveOrShare(
      context,
      bytes,
      stem,
      subject: 'Exportación CSV DolarSabio',
    );
  }

  /// Diagnóstico del último `importFromCsv`.
  static String lastDiagnostics = '';

  /// Importa filas desde un CSV (UTF-8, coma/punto y coma/tab). Mismas columnas que exporta la app.
  static Future<List<Map<String, dynamic>>?> importFromCsv() async {
    lastDiagnostics = '';
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();

    var off = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      off = 3;
    }
    var text = utf8.decode(bytes.sublist(off), allowMalformed: true);
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }

    final rows = _parseCsvRows(text);
    if (rows.isEmpty) {
      lastDiagnostics = 'Archivo CSV vacío o sin saltos de línea.';
      return [];
    }

    final headerCells = rows.first.map((e) => e?.toString() ?? '').toList();
    if (headerCells.every((h) => normalizeImportHeaderKey(h).isEmpty)) {
      lastDiagnostics =
          'Cabeceras vacías. Solo se detectó ${rows.first.length} columna(s). '
          '¿El separador es realmente coma?';
      return [];
    }

    final out = <Map<String, dynamic>>[];
    var dropped = 0;
    for (var i = 1; i < rows.length; i++) {
      final raw = rows[i];
      final values = <String>[];
      for (var j = 0; j < headerCells.length; j++) {
        values.add(j < raw.length ? (raw[j]?.toString() ?? '') : '');
      }
      final normMap = buildNormalizedHeaderMap(headerCells, values);
      final payload = buildImportPayload(normMap, values);
      if (importRowLooksEmpty(payload)) {
        dropped++;
        continue;
      }
      out.add(payload);
    }
    lastDiagnostics = out.isEmpty
        ? '0 filas válidas, $dropped descartadas, cols=${headerCells.length}.'
        : '';
    return out;
  }

  static Uint8List _encodeCsv(
    List<Transaction> transactions,
    Map<String, String> labels,
  ) {
    final headers = [
      labels['recordId'] ?? 'ID',
      labels['codigo'] ?? 'CODIGO',
      labels['cuenta'] ?? 'CUENTA',
      labels['descripcion'] ?? 'DESCRIPCION',
      labels['fecha'] ?? 'FECHA',
      labels['debito'] ?? 'DEBITO',
      labels['credito'] ?? 'CREDITO',
    ];

    const eol = '\r\n';
    final buf = StringBuffer();
    buf.write('\uFEFF');
    buf.write(headers.map(_escapeField).join(','));
    buf.write(eol);
    for (final t in transactions) {
      buf.write([
        _escapeField(t.recordId),
        _escapeField(t.codigo),
        _escapeField(t.cuenta),
        _escapeField(t.descripcion),
        _escapeField(t.fecha),
        _escapeField(t.debito.toString()),
        _escapeField(t.credito.toString()),
      ].join(','));
      buf.write(eol);
    }
    return Uint8List.fromList(utf8.encode(buf.toString()));
  }

  static String _escapeField(String s) {
    if (s.contains('"') ||
        s.contains(',') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static void _showSaveSuccessSnackBar(BuildContext context, String? path) {
    if (!context.mounted) return;
    final showPath = path != null &&
        path.isNotEmpty &&
        (Platform.isLinux || Platform.isMacOS || Platform.isWindows) &&
        p.isAbsolute(path);
    final text = showPath
        ? 'CSV guardado en:\n$path'
        : 'CSV guardado. Ábrelo desde la carpeta o app que elegiste al guardar.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  static Future<String?> _saveBytesToDevice(Uint8List bytes, String nameStem) async {
    if (kIsWeb) {
      return FileSaver.instance.saveFile(
        name: nameStem,
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
    }

    final defaultName = '$nameStem.csv';

    if (Platform.isAndroid) {
      final native = await AndroidSaveDownloads.save(
        filename: defaultName,
        mimeType: _kCsvMime,
        bytes: bytes,
      );
      if (native != null) return native;
      return FilePicker.platform.saveFile(
        dialogTitle: 'Guardar CSV',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );
    }

    if (Platform.isIOS) {
      return FilePicker.platform.saveFile(
        dialogTitle: 'Guardar CSV',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );
    }

    var path = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar CSV',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (path == null) return null;
    if (!path.toLowerCase().endsWith('.csv')) {
      path = '$path.csv';
    }
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  static Future<void> _shareCsv(
    Uint8List bytes,
    String fileStem,
    String subject,
  ) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'exports'));
    await dir.create(recursive: true);
    final path = p.join(dir.path, '$fileStem.csv');
    await File(path).writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [
        XFile(
          path,
          mimeType: 'text/csv',
          name: '$fileStem.csv',
        ),
      ],
      subject: subject,
    );
  }

  static Future<void> _pickSaveOrShare(
    BuildContext context,
    Uint8List bytes,
    String fileStem, {
    required String subject,
  }) async {
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final onS = scheme.onSurface;
        final muted = onS.withValues(alpha: 0.65);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.save_alt_rounded, color: muted),
                title: Text(
                  'Guardar archivo',
                  style: TextStyle(
                    color: onS,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Archivo .csv (UTF-8). Excel y Hojas de cálculo lo abren bien con el BOM incluido.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final path = await _saveBytesToDevice(bytes, fileStem);
                    if (!context.mounted) return;
                    if (path != null &&
                        path.isNotEmpty &&
                        !path.startsWith('Error') &&
                        !path.contains('Something went wrong')) {
                      _showSaveSuccessSnackBar(context, path);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No se pudo guardar: $e')),
                      );
                    }
                  }
                },
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.35)),
              ListTile(
                leading: Icon(Icons.share_rounded, color: muted),
                title: Text(
                  'Compartir',
                  style: TextStyle(
                    color: onS,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Gmail, WhatsApp, otra app…',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _shareCsv(bytes, fileStem, subject);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No se pudo compartir: $e')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
