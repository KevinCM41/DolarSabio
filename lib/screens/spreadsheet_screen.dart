// lib/screens/spreadsheet_screen.dart
// Equivalente a la tab "Hoja de Cálculo / Journal" del App.tsx

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../services/puc_catalog.dart';
import '../utils/app_provider.dart';
import '../utils/theme.dart';
import '../widgets/puc_explanation_sheet.dart';
import 'puc_guide_screen.dart';

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
  90, 130, 130, 200, 120, 110, 110, 80,
];
const double _kSpreadsheetTableWidth = 970;

class SpreadsheetScreen extends StatefulWidget {
  const SpreadsheetScreen({super.key});

  @override
  State<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends State<SpreadsheetScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static bool _rowMatchesQuery(Transaction t, String query) {
    final raw = query.trim().toLowerCase();
    if (raw.isEmpty) return true;
    final hay = [
      t.recordId,
      t.codigo,
      t.cuenta,
      t.descripcion,
      t.fecha,
      t.debito.toString(),
      t.credito.toString(),
    ].join('\n').toLowerCase();
    for (final token in raw.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      if (!hay.contains(token)) return false;
    }
    return true;
  }

  List<Transaction> _visibleRows(AppProvider provider) {
    final all = provider.sortedByDate;
    final q = _searchCtrl.text;
    if (q.trim().isEmpty) return all;
    return all.where((t) => _rowMatchesQuery(t, q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final labels = provider.columnLabels;
    final visible = _visibleRows(provider);
    final total = provider.sortedByDate.length;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: context.appCardDecoration(),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.appBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.appBackground,
                    border: Border.all(color: context.appBorder),
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
                        style: TextStyle(
                            color: context.appOnSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5),
                      ),
                      Text(
                        'Edición sincronizada en tiempo real',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.appMuted,
                            fontSize: 10,
                            fontFamily: 'RobotoMono'),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Guía PUC',
                  icon: Icon(Icons.menu_book_rounded,
                      color: context.appMuted, size: 22),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const PucGuideScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Buscador ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: context.appOnSurface, fontSize: 13),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText:
                        'Buscar por ID, código, cuenta, descripción, fecha o montos…',
                    hintMaxLines: 2,
                    prefixIcon: Icon(Icons.search_rounded,
                        color: context.appMuted, size: 22),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            icon: Icon(Icons.close_rounded,
                                color: context.appMuted, size: 20),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          ),
                  ),
                ),
                if (_searchCtrl.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      '${visible.length} de $total filas',
                      style: TextStyle(
                        color: context.appMuted,
                        fontSize: 11,
                        fontFamily: 'RobotoMono',
                      ),
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
                    _buildHeaderRow(context, labels, provider),
                    // Filas de datos
                    Expanded(
                      child: ListView.builder(
                        itemCount: visible.length + 1,
                        itemBuilder: (_, i) {
                          if (i == visible.length) {
                            return _AddRowButton(
                              onTap: () => _showAddModal(context),
                            );
                          }
                          return _TransactionRow(
                            transaction: visible[i],
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
      BuildContext context, Map<String, String> labels, AppProvider provider) {
    final keys = [
      'recordId', 'codigo', 'cuenta', 'descripcion',
      'fecha', 'debito', 'credito',
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.appBackground,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      child: Row(
        children: [
          ...keys.asMap().entries.map((e) => SizedBox(
                width: _kSpreadsheetColWidths[e.key],
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: _EditableHeader(
                    label: labels[keys[e.key]] ?? keys[e.key].toUpperCase(),
                    onRename: (val) => provider.renameColumn(keys[e.key], val),
                  ),
                ),
              )),
          SizedBox(
            width: _kSpreadsheetColWidths[7],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text('STATUS', style: context.appLabelStyle),
            ),
          ),
        ],
      ),
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
        style: TextStyle(color: context.appOnSurface, fontSize: 9),
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
          style: context.appLabelStyle,
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
    final bg = index.isEven ? Colors.transparent : context.appCard;

    return Container(
      color: bg,
      child: Row(
        children: [
          _InlineField(
              width: _kSpreadsheetColWidths[0], value: t.recordId,
              onSave: (v) => onUpdate(t.id!, {'recordId': v})),
          SizedBox(
            width: _kSpreadsheetColWidths[1],
            child: Row(
              children: [
                Expanded(
                  child: _InlineField(
                    width: _kSpreadsheetColWidths[1] - 34,
                    value: t.codigo,
                    bold: true,
                    onSave: (v) => onUpdate(t.id!, {'codigo': v}),
                  ),
                ),
                IconButton(
                  tooltip: 'Explicación PUC',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: t.codigo.trim().isEmpty
                        ? context.appMuted.withValues(alpha: 0.35)
                        : context.appMuted,
                  ),
                  onPressed: t.codigo.trim().isEmpty
                      ? null
                      : () {
                          showPucExplanationSheet(
                            context,
                            codigo: t.codigo.trim(),
                            cuentaEnMovimiento: t.cuenta,
                          );
                        },
                ),
              ],
            ),
          ),
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
              textColor: AppTheme.accentPrimary,
              textAlign: TextAlign.right,
              onSave: (v) =>
                  onUpdate(t.id!, {'debito': double.tryParse(v) ?? t.debito})),
          _InlineField(
              width: _kSpreadsheetColWidths[6],
              value: t.credito.toStringAsFixed(2),
              textColor: AppTheme.accentRed,
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
                  icon: Icon(Icons.delete_outline,
                      color: context.appMuted, size: 16),
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
      child: TextField(
        controller: _ctrl,
        textAlign: widget.textAlign,
        style: TextStyle(
          color: widget.textColor ?? context.appOnSurface,
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
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
        onSubmitted: widget.onSave,
        onTapOutside: (_) => widget.onSave(_ctrl.text),
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
            Icon(Icons.add, color: context.appMuted, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'AÑADIR NODO OPERATIVO',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.appMuted,
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
    'descripcion': TextEditingController(),
    'fecha': TextEditingController(
        text: DateTime.now().toIso8601String().split('T').first),
    'debito': TextEditingController(text: '0'),
    'credito': TextEditingController(text: '0'),
  };

  bool _pucLoading = true;
  bool _saving = false;
  String? _codigo;
  String? _cuenta;

  @override
  void initState() {
    super.initState();
    _ensurePuc();
  }

  Future<void> _ensurePuc() async {
    await PucCatalog.ensureLoaded();
    if (!mounted) return;
    setState(() => _pucLoading = false);
  }

  void _syncCuentaTrasCodigo(String? nuevoCodigo) {
    if (nuevoCodigo == null) {
      _cuenta = null;
      return;
    }
    final opts = PucCatalog.cuentasParaCodigo(nuevoCodigo);
    if (opts.isEmpty) {
      _cuenta = null;
    } else if (opts.length == 1) {
      _cuenta = opts.first;
    } else {
      _cuenta =
          (_cuenta != null && opts.contains(_cuenta)) ? _cuenta : null;
    }
  }

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

    final codigo = _codigo ?? '';
    final cuenta = _cuenta ?? '';
    if (codigo.isEmpty || cuenta.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selecciona código y cuenta del PUC.'),
          backgroundColor: AppTheme.accentRed,
        ));
      }
      setState(() => _saving = false);
      return;
    }

    await provider.addTransaction(Transaction(
      userId: user,
      recordId: provider.nextRecordId().toString(),
      codigo: codigo,
      cuenta: cuenta,
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
    final codigos = PucCatalog.codigosOrdenados;
    final codigoValue =
        _codigo != null && codigos.contains(_codigo) ? _codigo : null;
    final cuentasOpts = codigoValue == null
        ? const <String>[]
        : PucCatalog.cuentasParaCodigo(codigoValue);
    final cuentaValue =
        _cuenta != null && cuentasOpts.contains(_cuenta) ? _cuenta : null;

    Widget body;
    if (_pucLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.accentPrimary,
          ),
        ),
      );
    } else if (PucCatalog.loadError != null || codigos.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          PucCatalog.loadError != null
              ? 'No se pudo cargar el PUC. Revisa que el archivo esté en assets.'
              : 'El catálogo PUC está vacío.',
          style: const TextStyle(color: AppTheme.accentRed, fontSize: 13),
        ),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _ctrls['descripcion'],
            style: TextStyle(color: context.appOnSurface),
            validator: (v) =>
                v == null || v.isEmpty ? 'Requerido' : null,
            decoration: InputDecoration(
                labelText: labels['descripcion'] ?? 'DESCRIPCIÓN'),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: labels['recordId'] ?? 'ID',
                    helperText: 'Asignado automáticamente',
                    helperMaxLines: 1,
                  ),
                  child: Text(
                    '${provider.nextRecordId()}',
                    style: TextStyle(
                      color: context.appOnSurface,
                      fontFamily: 'RobotoMono',
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ctrls['fecha'],
                  style: TextStyle(
                      color: context.appOnSurface, fontFamily: 'RobotoMono'),
                  decoration:
                      InputDecoration(labelText: labels['fecha'] ?? 'FECHA'),
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(context),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      _ctrls['fecha']!.text =
                          picked.toIso8601String().split('T').first;
                      setState(() {});
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  // ignore: deprecated_member_use
                  value: codigoValue,
                  menuMaxHeight: 360,
                  dropdownColor: context.appSurface,
                  style: TextStyle(
                    color: context.appOnSurface,
                    fontFamily: 'RobotoMono',
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    labelText: labels['codigo'] ?? 'CÓDIGO',
                  ),
                  hint: Text('Seleccionar',
                      style: TextStyle(color: context.appMuted)),
                  items: codigos
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _codigo = v;
                      _syncCuentaTrasCodigo(v);
                    });
                  },
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Elige un código' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  // ignore: deprecated_member_use
                  value: cuentaValue,
                  menuMaxHeight: 360,
                  dropdownColor: context.appSurface,
                  style: TextStyle(color: context.appOnSurface, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: labels['cuenta'] ?? 'CUENTA',
                  ),
                  hint: Text('Seleccionar',
                      style: TextStyle(color: context.appMuted)),
                  items: cuentasOpts
                      .map(
                        (n) => DropdownMenuItem(
                          value: n,
                          child: Text(
                            n,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: cuentasOpts.isEmpty
                      ? null
                      : (v) => setState(() => _cuenta = v),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Elige la cuenta' : null,
                ),
              ),
            ],
          ),
          if (codigoValue != null && codigoValue.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  final cta = cuentaValue ??
                      (cuentasOpts.isNotEmpty ? cuentasOpts.first : '');
                  showPucExplanationSheet(
                    context,
                    codigo: codigoValue,
                    cuentaEnMovimiento: cta,
                  );
                },
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppTheme.accentPrimary,
                ),
                label: Text(
                  'Explicación PUC',
                  style: TextStyle(
                    color: AppTheme.accentPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _ctrls['debito'],
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    color: AppTheme.accentPrimary, fontFamily: 'RobotoMono'),
                decoration:
                    InputDecoration(labelText: labels['debito'] ?? 'DÉBITO'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _ctrls['credito'],
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    color: AppTheme.accentRed, fontFamily: 'RobotoMono'),
                decoration:
                    InputDecoration(labelText: labels['credito'] ?? 'CRÉDITO'),
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
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary))
                  : const Text('GUARDAR FILA'),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: context.appBorder)),
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
                Text(
                  'Nueva Fila Contable',
                  style: TextStyle(
                      color: context.appOnSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_pucLoading && codigos.isNotEmpty)
                      IconButton(
                        tooltip: 'Guía PUC',
                        icon: Icon(Icons.menu_book_rounded,
                            color: context.appMuted),
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const PucGuideScreen(),
                            ),
                          );
                        },
                      ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: context.appMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            body,
          ],
        ),
      ),
    );
  }
}
