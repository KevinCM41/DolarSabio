// lib/services/pdf_service.dart
// Equivalente a src/services/pdfService.ts

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';
import '../platform/android_save_downloads.dart';

const String _kPdfMime = 'application/pdf';

class PdfService {
  static Future<void> generateAndShareReport(
    BuildContext context,
    List<Transaction> transactions,
    FinancialSummary summary,
    Map<String, String> labels,
  ) async {
    final bytes = await _buildPdfBytes(transactions, summary, labels);
    if (!context.mounted) return;
    final stem = 'Reporte_DolarSabio_${DateTime.now().millisecondsSinceEpoch}';
    await _pickSaveOrSharePdf(context, bytes, stem);
  }

  static Future<Uint8List> _buildPdfBytes(
    List<Transaction> transactions,
    FinancialSummary summary,
    Map<String, String> labels,
  ) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) => [
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.green800, width: 2),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DolarSabio – Reporte Contable',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generado el: $dateStr',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Resumen Contable',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _summaryItem(
                    'Balance Total', '\$${summary.balance.toStringAsFixed(2)}'),
                _summaryItem('Total Créditos',
                    '\$${summary.totalIncomes.toStringAsFixed(2)}',
                    color: PdfColors.green700),
                _summaryItem('Total Débitos',
                    '\$${summary.totalExpenses.toStringAsFixed(2)}',
                    color: PdfColors.red700),
                _summaryItem(
                    'Registros', '${summary.transactionCount}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Detalle de Transacciones',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.8),
              1: const pw.FlexColumnWidth(1.0),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(2.0),
              4: const pw.FlexColumnWidth(1.0),
              5: const pw.FlexColumnWidth(1.0),
              6: const pw.FlexColumnWidth(1.0),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.green800),
                children: [
                  labels['recordId'] ?? 'ID',
                  labels['codigo'] ?? 'CÓDIGO',
                  labels['cuenta'] ?? 'CUENTA',
                  labels['descripcion'] ?? 'DESCRIPCIÓN',
                  labels['fecha'] ?? 'FECHA',
                  labels['debito'] ?? 'DÉBITO',
                  labels['credito'] ?? 'CRÉDITO',
                ].map((h) => _headerCell(h)).toList(),
              ),
              ...transactions.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                final bg = i.isEven ? PdfColors.white : PdfColors.grey50;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    t.recordId,
                    t.codigo,
                    t.cuenta,
                    t.descripcion,
                    t.fecha,
                    t.debito.toStringAsFixed(2),
                    t.credito.toStringAsFixed(2),
                  ].map((c) => _dataCell(c)).toList(),
                );
              }),
            ],
          ),
        ],
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  static bool _bytesLookLikePdf(Uint8List bytes) =>
      bytes.length >= 5 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;

  static Future<String?> _savePdfBytesToDevice(
      Uint8List bytes, String nameStem) async {
    if (kIsWeb) {
      return FileSaver.instance.saveFile(
        name: nameStem,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    }

    final defaultName = '$nameStem.pdf';

    if (Platform.isAndroid) {
      final native = await AndroidSaveDownloads.save(
        filename: defaultName,
        mimeType: _kPdfMime,
        bytes: bytes,
      );
      if (native != null) return native;
      return FilePicker.platform.saveFile(
        dialogTitle: 'Guardar PDF',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
    }

    if (Platform.isIOS) {
      return FilePicker.platform.saveFile(
        dialogTitle: 'Guardar PDF',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
    }

    var path = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar PDF',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (path == null) return null;
    if (!path.toLowerCase().endsWith('.pdf')) {
      path = '$path.pdf';
    }
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  static Future<void> _sharePdf(
      Uint8List bytes, String fileStem, String subject) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'exports'));
    await dir.create(recursive: true);
    final path = p.join(dir.path, '$fileStem.pdf');
    await File(path).writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [
        XFile(
          path,
          mimeType: _kPdfMime,
          name: '$fileStem.pdf',
        ),
      ],
      subject: subject,
    );
  }

  static void _showPdfSaveSuccessSnackBar(BuildContext context, String? path) {
    if (!context.mounted) return;
    final showPath = path != null &&
        path.isNotEmpty &&
        (Platform.isLinux || Platform.isMacOS || Platform.isWindows) &&
        p.isAbsolute(path);
    final text = showPath
        ? 'PDF guardado en:\n$path'
        : 'PDF guardado. Ábrelo desde la misma carpeta o app que elegiste al guardar.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static Future<void> _pickSaveOrSharePdf(
    BuildContext context,
    Uint8List bytes,
    String fileStem,
  ) async {
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
                'Archivo .pdf. Deja la extensión .pdf en el diálogo del sistema.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  if (!_bytesLookLikePdf(bytes)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('El PDF generado no es válido.'),
                        ),
                      );
                    }
                    return;
                  }
                  final path = await _savePdfBytesToDevice(bytes, fileStem);
                  if (!context.mounted) return;
                  if (path != null &&
                      path.isNotEmpty &&
                      !path.startsWith('Error') &&
                      !path.contains('Something went wrong')) {
                    _showPdfSaveSuccessSnackBar(context, path);
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
                'Gmail, Drive, WhatsApp…',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await _sharePdf(bytes, fileStem, 'Reporte DolarSabio');
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

  static pw.Widget _summaryItem(String label, String value,
      {PdfColor color = PdfColors.black}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: color)),
      ],
    );
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _dataCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 7)),
    );
  }
}
