// lib/screens/dashboard_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../utils/app_provider.dart';
import '../utils/theme.dart';

/// Barra bajo BALANCE: balance respecto al mayor de los dos totales (0–100 %).
double _balanceCapitalProgress(FinancialSummary s) {
  final hi = s.totalIncomes > s.totalExpenses ? s.totalIncomes : s.totalExpenses;
  if (hi <= 0) return 0;
  return (s.balance / hi).clamp(0, 1);
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final summary = provider.summary;
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final onCard = context.appOnSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tarjetas de métricas ────────────────────────────────────
          LayoutBuilder(builder: (ctx, constraints) {
            final wide = constraints.maxWidth > 600;
            if (wide) {
              return Row(
                children: [
                  Expanded(child: _MetricCard(
                    label: 'BALANCE CAPITAL',
                    value: '\$${fmt.format(summary.balance)}',
                    valueColor: onCard,
                    progress: _balanceCapitalProgress(summary),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(
                    label: 'CRÉDITOS TOTALES',
                    value: '\$${fmt.format(summary.totalIncomes)}',
                    valueColor: AppTheme.accentRed,
                    subtitle: '● Flujo Positivo',
                    subtitleColor: AppTheme.accentRed,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(
                    label: 'DÉBITOS TOTALES',
                    value: '\$${fmt.format(summary.totalExpenses)}',
                    valueColor: AppTheme.accentPrimary,
                    subtitle: '● Pasivos Totales',
                    subtitleColor: AppTheme.accentPrimary,
                  )),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MetricCard(
                  label: 'BALANCE CAPITAL',
                  value: '\$${fmt.format(summary.balance)}',
                  valueColor: onCard,
                  progress: _balanceCapitalProgress(summary),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'CRÉDITOS',
                        value: '\$${fmt.format(summary.totalIncomes)}',
                        valueColor: AppTheme.accentRed,
                        dense: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: 'DÉBITOS',
                        value: '\$${fmt.format(summary.totalExpenses)}',
                        valueColor: AppTheme.accentPrimary,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),

          const SizedBox(height: 16),

          // ── Gráfico de barras ─────────────────────────────────────────
          _FlowChart(summary: summary),

          const SizedBox(height: 16),

          // ── Actividad reciente ────────────────────────────────────────
          _RecentActivity(
            transactions: provider.transactions,
            onEdit: (t) => _showEditSheet(context, t),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, Transaction t) {
    // Delegar al widget padre para abrir el modal
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(transaction: t),
    );
  }
}

// ── Tarjeta de métrica ─────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final String? subtitle;
  final Color? subtitleColor;
  final double? progress;
  /// Tarjetas más compactas (p. ej. fila CRÉDITOS / DÉBITOS en móvil).
  final bool dense;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.valueColor,
    this.subtitle,
    this.subtitleColor,
    this.progress,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final pad = dense ? 12.0 : 20.0;
    final gapLabel = dense ? 8.0 : 10.0;
    final valueSize = dense ? 15.0 : 22.0;
    final gapProg = dense ? 7.0 : 12.0;
    final progMinH = dense ? 3.5 : 4.0;
    final progRadius =
        dense ? BorderRadius.zero : BorderRadius.circular(4);

    final inner = Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: dense
                ? context.appLabelStyle.copyWith(
                    fontSize: 8.5,
                    letterSpacing: 1.15,
                  )
                : context.appLabelStyle,
            maxLines: dense ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: gapLabel),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: valueSize,
              fontWeight: FontWeight.w800,
              fontFamily: 'RobotoMono',
              letterSpacing: -0.5,
            ),
          ),
          if (progress != null) ...[
            SizedBox(height: gapProg),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: progRadius,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: context.appBorder,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.accentPrimary),
                    minHeight: progMinH,
                  ),
                ),
              ),
              SizedBox(width: dense ? 5 : 8),
              Text(
                '${((progress ?? 0) * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: AppTheme.accentPrimary,
                  fontSize: dense ? 9 : 10,
                  fontFamily: 'RobotoMono',
                ),
              ),
            ]),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              subtitle!,
              style: TextStyle(
                color: subtitleColor ?? context.appMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ],
      ),
    );

    final content =
        dense ? Align(alignment: Alignment.topLeft, child: inner) : inner;

    return Container(
      decoration: context.appCardDecoration(),
      child: content,
    );
  }
}

// ── Gráfico de flujo ───────────────────────────────────────────────────────
class _FlowChart extends StatelessWidget {
  final FinancialSummary summary;

  const _FlowChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: context.appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ANÁLISIS DE FLUJO', style: context.appLabelStyle),
          const SizedBox(height: 4),
          Text(
            'Comparativa Crédito vs Débito',
            style: TextStyle(color: context.appMuted, fontSize: 10),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: [summary.totalIncomes, summary.totalExpenses, 1]
                    .reduce((a, b) => a > b ? a : b) *
                    1.2,
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(
                      toY: summary.totalIncomes,
                      color: AppTheme.accentRed,
                      width: 40,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6)),
                    ),
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(
                      toY: summary.totalExpenses,
                      color: AppTheme.accentPrimary,
                      width: 40,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6)),
                    ),
                  ]),
                ],
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final labels = ['CRÉDITOS', 'DÉBITOS'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[value.toInt()],
                            style: TextStyle(
                              color: context.appMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.appBorder,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.appCard,
                    tooltipRoundedRadius: 8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Actividad reciente ────────────────────────────────────────────────────
class _RecentActivity extends StatelessWidget {
  final List<Transaction> transactions;
  final void Function(Transaction) onEdit;

  const _RecentActivity({
    required this.transactions,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<Transaction>.from(transactions)
      ..sort((a, b) {
        final da = DateTime.tryParse(a.fecha) ?? DateTime(0);
        final db = DateTime.tryParse(b.fecha) ?? DateTime(0);
        return db.compareTo(da);
      });

    return Container(
      decoration: context.appCardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVIDAD RECIENTE',
                  style: TextStyle(
                    color: context.appOnSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Nodos activos del sistema',
                  style: TextStyle(color: context.appMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Divider(color: context.appBorder, height: 1),

          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Sin registros',
                style: TextStyle(color: context.appMuted),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sorted.take(20).length,
              separatorBuilder: (_, __) =>
                  Divider(color: context.appBorder, height: 1),
              itemBuilder: (_, i) {
                final t = sorted[i];
                final date = DateTime.tryParse(t.fecha);
                final dateStr = date != null
                    ? DateFormat('dd/MM/yy').format(date)
                    : t.fecha;
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(t.descripcion,
                      style: TextStyle(
                          color: context.appOnSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  subtitle: Text(
                    '${t.recordId.isNotEmpty ? t.recordId : 'N/A'} • $dateStr',
                    style: TextStyle(
                        color: context.appMuted,
                        fontSize: 10,
                        fontFamily: 'RobotoMono'),
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (t.credito > 0)
                        Text('+\$${t.credito.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: AppTheme.accentRed,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'RobotoMono',
                                fontSize: 13)),
                      if (t.debito > 0)
                        Text('-\$${t.debito.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: AppTheme.accentPrimary,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'RobotoMono',
                                fontSize: 13)),
                    ],
                  ),
                  onTap: () => onEdit(t),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Sheet de edición ───────────────────────────────────────────────────────
class _EditSheet extends StatefulWidget {
  final Transaction transaction;

  const _EditSheet({required this.transaction});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _debitoCtrl;
  late final TextEditingController _creditoCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.transaction.descripcion);
    _debitoCtrl =
        TextEditingController(text: widget.transaction.debito.toString());
    _creditoCtrl =
        TextEditingController(text: widget.transaction.credito.toString());
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _debitoCtrl.dispose();
    _creditoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
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
        border:
            Border(top: BorderSide(color: context.appBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Editar Registro',
              style: TextStyle(
                  color: context.appOnSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(
            controller: _descCtrl,
            style: TextStyle(color: context.appOnSurface),
            decoration: const InputDecoration(labelText: 'DESCRIPCIÓN'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _debitoCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.accentPrimary),
                decoration: const InputDecoration(labelText: 'DÉBITO'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _creditoCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.accentRed),
                decoration: const InputDecoration(labelText: 'CRÉDITO'),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await provider.updateTransactionField(
                  widget.transaction.id!,
                  {
                    'descripcion': _descCtrl.text,
                    'debito':
                        double.tryParse(_debitoCtrl.text) ?? widget.transaction.debito,
                    'credito':
                        double.tryParse(_creditoCtrl.text) ?? widget.transaction.credito,
                  },
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('GUARDAR CAMBIOS'),
            ),
          ),
        ],
      ),
    );
  }
}
