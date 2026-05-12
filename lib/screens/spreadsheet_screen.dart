// lib/screens/spreadsheet_screen.dart
// Equivalente a la tab "Hoja de Cálculo / Journal" del App.tsx

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../utils/app_provider.dart';
import '../utils/theme.dart';

/// Mismo formulario que el botón «AÑADIR NODO OPERATIVO» en la hoja (p. ej. desde el drawer).
void showAddTransactionSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddTransactionSheet(),
  );
}

/// Anchos de las 8 columnas (ID … STATUS). El scroll horizontal debe usar **la misma suma**.
const List<double> _kSpreadsheetColWidths = [
  90, 110, 130, 200, 120, 110, 110, 80,
];
const double _kSpreadsheetTableWidth = 950;

class SpreadsheetScreen extends StatefulWidget {
  const SpreadsheetScreen({super.key});

  @override
  State<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends State<SpreadsheetScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final labels = provider.columnLabels;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: const Icon(Icons.table_chart_rounded,
                      color: AppTheme.accentPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JOURNAL DETALLADO',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5),
                      ),
                      Text(
                        'Edición sincronizada en tiempo real',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.darkMuted,
                            fontSize: 10,
                            fontFamily: 'RobotoMono'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tabla ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _kSpreadsheetTableWidth,
                child: Column(
                  children: [
                    // Fila de cabeceras
                    Container(
                      color: AppTheme.darkBg,
                      child: _buildHeaderRow(labels, provider),
                    ),
                    // Filas de datos
                    Expanded(
                      child: ListView.separated(
                        itemCount: provider.sortedByDate.length + 1,
                        separatorBuilder: (_, __) => const Divider(
                            color: AppTheme.darkBorder, height: 1),
                        itemBuilder: (_, i) {
                          if (i == provider.sortedByDate.length) {
                            return _AddRowButton(
                              onTap: () => _showAddModal(context),
                            );
                          }
                          return _TransactionRow(
                            transaction: provider.sortedByDate[i],
                            index: i,
                            onUpdate: (id, data) =>
                                provider.updateTransactionField(id, data),
                            onDelete: (id) => provider.deleteTransaction(id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(
      Map<String, String> labels, AppProvider provider) {
    const widths = [90.0, 110.0, 130.0, 200.0, 120.0, 110.0, 110.0, 80.0];
    final keys = [
      'recordId', 'codigo', 'cuenta', 'descripcion',
      'fecha', 'debito', 'credito',
    ];

    return Row(
      children: [
        ...keys.asMap().entries.map((e) => SizedBox(
              width: widths[e.key],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: AppTheme.darkBorder),
                    bottom: BorderSide(color: AppTheme.darkBorder),
                  ),
                ),
                child: _EditableHeader(
                  label: labels[keys[e.key]] ?? keys[e.key].toUpperCase(),
                  onRename: (val) => provider.renameColumn(keys[e.key], val),
                ),
              ),
            )),
        // Status column
        SizedBox(
          width: _kSpreadsheetColWidths[7],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.darkBorder),
              ),
            ),
            child: Text('STATUS', style: AppTheme.labelStyle),
          ),
        ),
      ],
    );
  }

  void _showAddModal(BuildContext context) {
    showAddTransactionSheet(context);
  }
}

// ── Cabecera editable ──────────────────────────────────────────────────────
class _EditableHeader extends StatefulWidget {
  final String label;
  final void Function(String) onRename;

  const _EditableHeader({required this.label, required this.onRename});

  @override
  State<_EditableHeader> createState() => _EditableHeaderState();
}

class _EditableHeaderState extends State<_EditableHeader> {
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.label);
  }

  @override
  void didUpdateWidget(covariant _EditableHeader old) {
    super.didUpdateWidget(old);
    if (!_editing) _ctrl.text = widget.label;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return TextField(
        controller: _ctrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 9),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
        onSubmitted: (val) {
          widget.onRename(val);
          setState(() => _editing = false);
        },
        onTapOutside: (_) {
          widget.onRename(_ctrl.text);
          setState(() => _editing = false);
        },
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _editing = true),
      child: Text(widget.label,
          style: AppTheme.labelStyle,
          overflow: TextOverflow.ellipsis),
    );
  }
}

// ── Fila de transacción editable ───────────────────────────────────────────
class _TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final int index;
  final void Function(String, Map<String, dynamic>) onUpdate;
  final void Function(String) onDelete;

  const _TransactionRow({
    required this.transaction,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final bg = index.isEven ? Colors.transparent : AppTheme.darkCard;

    return Container(
      color: bg,
      child: Row(
        children: [
          _InlineField(
              width: _kSpreadsheetColWidths[0], value: t.recordId,
              onSave: (v) => onUpdate(t.id!, {'recordId': v})),
          _InlineField(
              width: _kSpreadsheetColWidths[1], value: t.codigo, bold: true,
              onSave: (v) => onUpdate(t.id!, {'codigo': v})),
          _InlineField(
              width: _kSpreadsheetColWidths[2], value: t.cuenta,
              onSave: (v) => onUpdate(t.id!, {'cuenta': v})),
          _InlineField(
              width: _kSpreadsheetColWidths[3], value: t.descripcion, italic: true,
              onSave: (v) => onUpdate(t.id!, {'descripcion': v})),
          _InlineField(
              width: _kSpreadsheetColWidths[4], value: t.fecha,
              onSave: (v) => onUpdate(t.id!, {'fecha': v})),
          _InlineField(
              width: _kSpreadsheetColWidths[5],
              value: t.debito.toStringAsFixed(2),
              textColor: AppTheme.accentRed,
              textAlign: TextAlign.right,
              onSave: (v) =>
                  onUpdate(t.id!, {'debito': double.tryParse(v) ?? t.debito})),
          _InlineField(
              width: _kSpreadsheetColWidths[6],
              value: t.credito.toStringAsFixed(2),
              textColor: AppTheme.accentPrimary,
              textAlign: TextAlign.right,
              onSave: (v) => onUpdate(
                  t.id!, {'credito': double.tryParse(v) ?? t.credito})),
          // Status + Delete
          SizedBox(
            width: _kSpreadsheetColWidths[7],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.darkMuted, size: 16),
                  onPressed: () => onDelete(t.id!),
                  tooltip: 'Eliminar',
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
color: AppTheme.accentPrimary.withValues(alpha: 0.5),
                    blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineField extends StatefulWidget {
  final double width;
  final String value;
  final void Function(String) onSave;
  final Color? textColor;
  final bool bold;
  final bool italic;
  final TextAlign textAlign;

  const _InlineField({
    required this.width,
    required this.value,
    required this.onSave,
    this.textColor,
    this.bold = false,
    this.italic = false,
    this.textAlign = TextAlign.left,
  });

  @override
  State<_InlineField> createState() => _InlineFieldState();
}

class _InlineFieldState extends State<_InlineField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _InlineField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_ctrl.selection.isValid) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppTheme.darkBorder)),
        ),
        child: TextField(
          controller: _ctrl,
          textAlign: widget.textAlign,
          style: TextStyle(
            color: widget.textColor ?? AppTheme.darkText,
            fontSize: 11,
            fontFamily: 'RobotoMono',
            fontWeight: widget.bold ? FontWeight.w700 : FontWeight.w400,
            fontStyle: widget.italic ? FontStyle.italic : FontStyle.normal,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: InputBorder.none,
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.accentPrimary),
              borderRadius: BorderRadius.zero,
            ),
          ),
          onSubmitted: widget.onSave,
          onTapOutside: (_) => widget.onSave(_ctrl.text),
        ),
      ),
    );
  }
}

class _AddRowButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddRowButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: AppTheme.darkMuted, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'AÑADIR NODO OPERATIVO',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.darkMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modal de añadir transacción ────────────────────────────────────────────
class _AddTransactionSheet extends StatefulWidget {
  const _AddTransactionSheet();

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ctrls = <String, TextEditingController>{
    'recordId': TextEditingController(),
    'codigo': TextEditingController(),
    'cuenta': TextEditingController(),
    'descripcion': TextEditingController(),
    'fecha': TextEditingController(
        text: DateTime.now().toIso8601String().split('T').first),
    'debito': TextEditingController(text: '0'),
    'credito': TextEditingController(text: '0'),
  };

  bool _saving = false;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final provider = context.read<AppProvider>();
    final user = provider.currentUserId;
    if (user == null || user.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No hay usuario autenticado para guardar.'),
          backgroundColor: AppTheme.accentRed,
        ));
      }
      setState(() => _saving = false);
      return;
    }

    await provider.addTransaction(Transaction(
      userId: user,
      recordId: _ctrls['recordId']!.text,
      codigo: _ctrls['codigo']!.text,
      cuenta: _ctrls['cuenta']!.text,
      descripcion: _ctrls['descripcion']!.text.isEmpty
          ? 'Sin descripción'
          : _ctrls['descripcion']!.text,
      fecha: _ctrls['fecha']!.text,
      debito: double.tryParse(_ctrls['debito']!.text) ?? 0,
      credito: double.tryParse(_ctrls['credito']!.text) ?? 0,
    ));

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final labels = provider.columnLabels;

    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nueva Fila Contable',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic)),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.darkMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Descripción (required)
            TextFormField(
              controller: _ctrls['descripcion'],
              style: const TextStyle(color: Colors.white),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Requerido' : null,
              decoration: InputDecoration(
                  labelText: labels['descripcion'] ?? 'DESCRIPCIÓN'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _ctrls['recordId'],
                  style: const TextStyle(color: Colors.white, fontFamily: 'RobotoMono'),
                  decoration: InputDecoration(labelText: labels['recordId'] ?? 'ID'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ctrls['fecha'],
                  style: const TextStyle(color: Colors.white, fontFamily: 'RobotoMono'),
                  decoration: InputDecoration(labelText: labels['fecha'] ?? 'FECHA'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      builder: (ctx, child) => Theme(
                        data: ThemeData.dark(),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      _ctrls['fecha']!.text =
                          picked.toIso8601String().split('T').first;
                    }
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _ctrls['codigo'],
                  style: const TextStyle(color: Colors.white, fontFamily: 'RobotoMono'),
                  decoration: InputDecoration(labelText: labels['codigo'] ?? 'CÓDIGO'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ctrls['cuenta'],
                  style: const TextStyle(color: Colors.white, fontFamily: 'RobotoMono'),
                  decoration: InputDecoration(labelText: labels['cuenta'] ?? 'CUENTA'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _ctrls['debito'],
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.accentRed, fontFamily: 'RobotoMono'),
                  decoration: InputDecoration(labelText: labels['debito'] ?? 'DÉBITO'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ctrls['credito'],
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.accentPrimary, fontFamily: 'RobotoMono'),
                  decoration: InputDecoration(labelText: labels['credito'] ?? 'CRÉDITO'),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.darkBg))
                    : const Text('GUARDAR FILA'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
