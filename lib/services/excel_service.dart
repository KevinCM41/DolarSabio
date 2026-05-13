// lib/services/excel_service.dart
// Equivalente a src/services/excelService.ts

import 'dart:io';

import 'package:excel/excel.dart';
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

/// MIME OOXML para que Gmail / Drive reconozcan el adjunto al compartir.
const String _kXlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

class ExcelService {
  // ── Exportar ──────────────────────────────────────────────────────────────
  static Future<void> exportToExcel(
    BuildContext context,
    List<Transaction> transactions,
    Map<String, String> labels,
  ) async {
    final bytes = _encodeWorkbook(_buildTransactionsWorkbook(transactions, labels));
    if (bytes == null) return;
    final stem = 'DolarSabio_Export_${DateTime.now().millisecondsSinceEpoch}';
    await _pickSaveOrShare(context, bytes, stem, subject: 'Exportación DolarSabio');
  }

  /// Diagnóstico del último `importFromExcel` (se rellena aunque se devuelvan filas).
  static String lastDiagnostics = '';

  // ── Importar ──────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>?> importFromExcel() async {
    lastDiagnostics = '';
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();

    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      lastDiagnostics = 'No se pudo abrir el archivo: $e';
      return [];
    }

    final allSheets = excel.tables.keys.toList();
    final sheetName = _bestSheetName(excel);
    final sheet = excel.tables[sheetName];
    if (sheet == null) {
      lastDiagnostics = 'Hoja «$sheetName» vacía. Hojas: ${allSheets.join(", ")}';
      return [];
    }

    final maxRows = sheet.maxRows;
    final maxCols = sheet.maxColumns;
    if (maxRows < 2 || maxCols < 1) {
      lastDiagnostics =
          'Hoja «$sheetName» con $maxRows filas × $maxCols columnas. Hojas: ${allSheets.join(", ")}';
      return [];
    }

    final headers = <String>[];
    for (var col = 0; col < maxCols; col++) {
      final c = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      headers.add(_cellToString(c));
    }

    if (headers.every((h) => normalizeImportHeaderKey(h).isEmpty)) {
      lastDiagnostics = 'Cabeceras vacías en hoja «$sheetName».';
      return [];
    }

    final transactions = <Map<String, dynamic>>[];
    var dropped = 0;
    for (var rowIdx = 1; rowIdx < maxRows; rowIdx++) {
      final values = <String>[];
      for (var col = 0; col < maxCols; col++) {
        final c = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx),
        );
        values.add(_cellToString(c));
      }
      final normMap = buildNormalizedHeaderMap(headers, values);
      final payload = buildImportPayload(normMap, values);
      if (importRowLooksEmpty(payload)) {
        dropped++;
        continue;
      }
      transactions.add(payload);
    }

    lastDiagnostics = transactions.isEmpty
        ? 'Hoja «$sheetName»: 0 filas válidas, $dropped descartadas '
            '(maxRows=$maxRows, cols=${headers.length}).'
        : '';
    return transactions;
  }

  /// Elige la hoja con **más filas** (donde suelen estar los datos) y desempata por nombre conocido.
  ///
  /// Antes se priorizaba siempre «Transacciones» aunque tuviera solo la cabecera; Excel a veces deja
  /// ahí una hoja vacía y mueve los datos a otra pestaña.
  static String _bestSheetName(Excel excel) {
    final keys = excel.tables.keys.toList();
    if (keys.isEmpty) return 'Sheet1';

    int rank(String name) {
      final lower = name.toLowerCase();
      if (lower == 'transacciones') return 0;
      if (lower == 'plantilla') return 1;
      if (lower == 'hoja1' || lower == 'sheet1') return 2;
      return 10;
    }

    keys.sort((a, b) {
      final sa = excel.tables[a]?.rows.length ?? 0;
      final sb = excel.tables[b]?.rows.length ?? 0;
      if (sa != sb) return sb.compareTo(sa);
      return rank(a).compareTo(rank(b));
    });
    return keys.first;
  }

  static String _cellToString(Data? c) {
    if (c == null) return '';
    final Object? val = c.value;
    if (val == null) return '';
    if (val is String) return val.trim();
    if (val is int) return val.toString();
    if (val is double) {
      final d = val;
      if (d == d.roundToDouble()) return d.toInt().toString();
      return d.toString();
    }
    if (val is DateTime) {
      return val.toIso8601String().split('T').first;
    }
    if (val is bool) {
      return val ? '1' : '0';
    }
    return val.toString().trim();
  }

  // ── Plantilla ──────────────────────────────────────────────────────────────
  /// [labels] = `provider.columnLabels`, para respetar los nombres de columna
  /// que el usuario haya renombrado en la app.
  static Future<void> downloadTemplate(
    BuildContext context,
    Map<String, String> labels,
  ) async {
    final bytes = _encodeWorkbook(_buildTemplateWorkbook(labels));
    if (bytes == null) return;
    await _pickSaveOrShare(
      context,
      bytes,
      'DolarSabio_Plantilla',
      subject: 'Plantilla DolarSabio',
    );
  }

  // ── Internos ─────────────────────────────────────────────────────────────

  static Excel _buildTransactionsWorkbook(
    List<Transaction> transactions,
    Map<String, String> labels,
  ) {
    final excel = Excel.createExcel();
    final sheet = excel['Transacciones'];
    excel.delete('Sheet1');

    final headers = [
      labels['recordId'] ?? 'ID',
      labels['codigo'] ?? 'CODIGO',
      labels['cuenta'] ?? 'CUENTA',
      labels['descripcion'] ?? 'DESCRIPCION',
      labels['fecha'] ?? 'FECHA',
      labels['debito'] ?? 'DEBITO',
      labels['credito'] ?? 'CREDITO',
    ];

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#14532D'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (var row = 0; row < transactions.length; row++) {
      final t = transactions[row];
      final rowData = [
        t.recordId,
        t.codigo,
        t.cuenta,
        t.descripcion,
        t.fecha,
        t.debito.toString(),
        t.credito.toString(),
      ];
      for (var col = 0; col < rowData.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1),
        );
        if (col >= 5) {
          cell.value = DoubleCellValue(double.tryParse(rowData[col]) ?? 0);
        } else {
          cell.value = TextCellValue(rowData[col]);
        }
      }
    }
    return excel;
  }

  /// Plantilla con cabeceras según [labels] y 2 filas de ejemplo, manteniendo
  /// el mismo formato que la exportación real (montos como número, no texto)
  /// para que el import por `_bestSheetName` / `buildImportPayload` la reconozca.
  static Excel _buildTemplateWorkbook(Map<String, String> labels) {
    final excel = Excel.createExcel();
    final sheet = excel['Plantilla'];
    excel.delete('Sheet1');

    final headers = [
      labels['recordId'] ?? 'ID',
      labels['codigo'] ?? 'CODIGO',
      labels['cuenta'] ?? 'CUENTA',
      labels['descripcion'] ?? 'DESCRIPCION',
      labels['fecha'] ?? 'FECHA',
      labels['debito'] ?? 'DEBITO',
      labels['credito'] ?? 'CREDITO',
    ];

    final today = DateTime.now().toIso8601String().split('T').first;
    final examples = <List<Object>>[
      ['1', '110505', 'Caja General',  'Apertura de caja', today, 0.0, 1000.0],
      ['2', '410505', 'Comercio al por mayor', 'Venta de mercancía', today, 0.0, 500.0],
    ];

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#14532D'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (var row = 0; row < examples.length; row++) {
      final rowData = examples[row];
      for (var col = 0; col < rowData.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1),
        );
        final value = rowData[col];
        if (value is num) {
          cell.value = DoubleCellValue(value.toDouble());
        } else {
          cell.value = TextCellValue(value.toString());
        }
      }
    }
    return excel;
  }

  static Uint8List? _encodeWorkbook(Excel excel) {
    final raw = excel.save(fileName: 'DolarSabio.xlsx');
    if (raw == null) return null;
    return Uint8List.fromList(raw);
  }

  /// .xlsx es un ZIP; los bytes válidos empiezan por PK\x03\x04.
  static bool _bytesLookLikeXlsx(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;

  static void _showSaveSuccessSnackBar(BuildContext context, String? path) {
    if (!context.mounted) return;
    // En Android/iOS, file_picker puede devolver una ruta bajo Download que no
    // es el archivo real si el usuario guardó en Drive u otra ubicación (bug conocido del plugin).
    final showPath = path != null &&
        path.isNotEmpty &&
        (Platform.isLinux || Platform.isMacOS || Platform.isWindows) &&
        p.isAbsolute(path);
    final text = showPath
        ? 'Excel (.xlsx) guardado en:\n$path'
        : 'Excel guardado: formato .xlsx (Microsoft Excel / Hojas de cálculo). '
            'Ábrelo desde la misma carpeta o app que elegiste al guardar '
            '(p. ej. Google Drive o Descargas), no desde una ruta distinta.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  /// Guarda el .xlsx en el dispositivo. En **Android/iOS** usa [FilePicker]
  /// (diálogo del sistema; el plugin ya está enlazado en casi todos los builds).
  /// `file_saver.saveAs` puede dar [MissingPluginException] si el registro nativo
  /// falla; no lo usamos en móvil. En **escritorio** el picker devuelve la ruta y
  /// escribimos nosotros los bytes (macOS no admite `bytes` en el picker).
  static Future<String?> _saveBytesToDevice(Uint8List bytes, String nameStem) async {
    if (kIsWeb) {
      return FileSaver.instance.saveFile(
        name: nameStem,
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }

    final defaultName = '$nameStem.xlsx';

    if (Platform.isAndroid) {
      final native =
          await AndroidSaveDownloads.save(
        filename: defaultName,
        mimeType: _kXlsxMime,
        bytes: bytes,
      );
      if (native != null) return native;
      return FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Excel',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: bytes,
      );
    }

    if (Platform.isIOS) {
      return FilePicker.platform.saveFile(
        dialogTitle: 'Guardar Excel',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: bytes,
      );
    }

    var path = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar Excel',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (path == null) return null;
    if (!path.toLowerCase().endsWith('.xlsx')) {
      path = '$path.xlsx';
    }
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  /// Archivo en almacenamiento de la app (no caché volátil) + MIME para compartir.
  static Future<void> _shareXlsx(
    Uint8List bytes,
    String fileStem,
    String subject,
  ) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'exports'));
    await dir.create(recursive: true);
    final path = p.join(dir.path, '$fileStem.xlsx');
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [
        XFile(
          path,
          mimeType: _kXlsxMime,
          name: '$fileStem.xlsx',
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
                'Archivo .xlsx (Excel). En el nombre del sistema, deja la extensión .xlsx.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  if (!_bytesLookLikeXlsx(bytes)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'El archivo generado no parece un Excel válido.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
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
                  await _shareXlsx(bytes, fileStem, subject);
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
