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

  // ── Importar ──────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>?> importFromExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result == null || result.files.isEmpty) return null;

    final bytes = result.files.first.bytes ??
        await File(result.files.first.path!).readAsBytes();

    final excel = Excel.decodeBytes(bytes);
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) return [];

    // Primera fila = cabeceras
    final headerRow = sheet.rows.first;
    final headers = headerRow.map((c) => c?.value?.toString() ?? '').toList();

    final transactions = <Map<String, dynamic>>[];

    for (var rowIdx = 1; rowIdx < sheet.rows.length; rowIdx++) {
      final row = sheet.rows[rowIdx];
      final map = <String, dynamic>{};
      for (var colIdx = 0; colIdx < headers.length; colIdx++) {
        final header = headers[colIdx].toUpperCase();
        final value = colIdx < row.length ? row[colIdx]?.value : null;
        map[header] = value?.toString() ?? '';
      }

      // Mapeo flexible igual al original (acepta CODIGO, Codigo, codigo, etc.)
      transactions.add({
        'recordId': _pick(map, ['ID', 'RECORDID']),
        'codigo': _pick(map, ['CODIGO']),
        'cuenta': _pick(map, ['CUENTA']),
        'descripcion': _pick(map, ['DESCRIPCION', 'DESCRIPCIÓN']),
        'fecha': _pick(map, ['FECHA'],
            fallback: DateTime.now().toIso8601String().split('T').first),
        'debito': double.tryParse(_pick(map, ['DEBITO', 'DÉBITO'])) ?? 0.0,
        'credito': double.tryParse(_pick(map, ['CREDITO', 'CRÉDITO'])) ?? 0.0,
      });
    }

    return transactions;
  }

  // ── Plantilla ──────────────────────────────────────────────────────────────
  static Future<void> downloadTemplate(BuildContext context) async {
    final bytes = _encodeWorkbook(_buildTemplateWorkbook());
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

  static Excel _buildTemplateWorkbook() {
    final excel = Excel.createExcel();
    final sheet = excel['Plantilla'];
    excel.delete('Sheet1');

    const headers = [
      'ID',
      'CODIGO',
      'CUENTA',
      'DESCRIPCION',
      'FECHA',
      'DEBITO',
      'CREDITO'
    ];
    const example = [
      '1',
      '110505',
      'Caja General',
      'Apertura de caja',
      '2024-05-11',
      '0',
      '1000'
    ];

    final hStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#14532D'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
    );

    for (var i = 0; i < headers.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = hStyle;

      final dataCell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      dataCell.value = TextCellValue(example[i]);
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
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt_rounded, color: Colors.white70),
              title: const Text(
                'Guardar archivo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Archivo .xlsx (Excel). En el nombre del sistema, deja la extensión .xlsx.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
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
            const Divider(height: 1, color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Colors.white70),
              title: const Text(
                'Compartir',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Gmail, WhatsApp, otra app…',
                style: TextStyle(color: Colors.white54, fontSize: 12),
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
      ),
    );
  }

  static String _pick(Map<String, dynamic> map, List<String> keys,
      {String fallback = ''}) {
    for (final key in keys) {
      if (map.containsKey(key) && (map[key] as String).isNotEmpty) {
        return map[key] as String;
      }
    }
    return fallback;
  }
}
