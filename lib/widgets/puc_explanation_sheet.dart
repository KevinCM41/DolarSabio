// lib/widgets/puc_explanation_sheet.dart
// Catálogo PUC + explicación opcional con IA (Groq).

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/ai_service.dart';
import '../services/puc_catalog.dart';
import '../utils/theme.dart';

Future<void> showPucExplanationSheet(
  BuildContext context, {
  required String codigo,
  required String cuentaEnMovimiento,
}) async {
  await PucCatalog.ensureLoaded();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _PucExplanationPanel(
      codigo: codigo,
      cuentaEnMovimiento: cuentaEnMovimiento,
    ),
  );
}

class _PucExplanationPanel extends StatefulWidget {
  final String codigo;
  final String cuentaEnMovimiento;

  const _PucExplanationPanel({
    required this.codigo,
    required this.cuentaEnMovimiento,
  });

  @override
  State<_PucExplanationPanel> createState() => _PucExplanationPanelState();
}

class _PucExplanationPanelState extends State<_PucExplanationPanel> {
  late final String _catalog;
  String? _ai;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _catalog = PucCatalog.describeCodigoEnCatalogo(widget.codigo);
  }

  Future<void> _runAi() async {
    setState(() {
      _aiLoading = true;
      _ai = null;
    });
    final text = await AiService.explainPucWithAi(
      codigo: widget.codigo,
      cuentaEnLibro: widget.cuentaEnMovimiento.isEmpty
          ? '(no indicada)'
          : widget.cuentaEnMovimiento,
      catalogSummary: _catalog,
    );
    if (!mounted) return;
    setState(() {
      _ai = text;
      _aiLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final h = (MediaQuery.sizeOf(context).height - pad.top) * 0.78;

    return SizedBox(
      height: h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'PUC ${widget.codigo}',
                      style: TextStyle(
                        color: context.appOnSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      'Cuenta en el movimiento: ${widget.cuentaEnMovimiento.isEmpty ? '—' : widget.cuentaEnMovimiento}',
                      style: TextStyle(color: context.appMuted, fontSize: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.appMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.appBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'Según el catálogo en la app',
                  style: context.appLabelStyle,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _catalog,
                  style: TextStyle(
                    color: context.appOnSurface,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                if (AiService.isConfigured)
                  FilledButton.icon(
                    onPressed: _aiLoading ? null : _runAi,
                    icon: _aiLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: Text(
                      _aiLoading
                          ? 'Generando…'
                          : 'Explicación con IA (Groq)',
                    ),
                  )
                else
                  Text(
                    'Para explicación con IA, compila con '
                    '--dart-define=GROQ_API_KEY=…',
                    style: TextStyle(
                      color: context.appMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                if (_ai != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Vista IA',
                    style: context.appLabelStyle,
                  ),
                  const SizedBox(height: 8),
                  MarkdownBody(
                    data: _ai!,
                    shrinkWrap: true,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: context.appOnSurface,
                        fontSize: 14,
                        height: 1.45,
                      ),
                      listBullet: TextStyle(color: context.appOnSurface),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
