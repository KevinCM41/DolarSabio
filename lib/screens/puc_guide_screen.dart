// lib/screens/puc_guide_screen.dart
// Vista de referencia del Plan Único de Cuentas (PUC).

import 'package:flutter/material.dart';

import '../models/puc_entry.dart';
import '../services/puc_catalog.dart';
import '../utils/theme.dart';

class PucGuideScreen extends StatefulWidget {
  const PucGuideScreen({super.key});

  @override
  State<PucGuideScreen> createState() => _PucGuideScreenState();
}

class _PucGuideScreenState extends State<PucGuideScreen> {
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await PucCatalog.ensureLoaded();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        foregroundColor: context.appOnSurface,
        title: Text('Guía PUC 2026',
            style: TextStyle(color: context.appOnSurface)),
        elevation: 0,
      ),
      body: _busy
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 2,
              ),
            )
          : PucCatalog.loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No se pudo cargar el PUC:\n${PucCatalog.loadError}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.accentRed),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: context.appCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PLAN ÚNICO DE CUENTAS',
                            style: TextStyle(
                              color: context.appOnSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Códigos más comunes adaptados para comerciantes en '
                            'Colombia. Al crear una fila, elige código y cuenta '
                            'desde los listados alineados con este plan.',
                            style: TextStyle(
                              color: context.appMuted,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...PucCatalog.sections.map((s) => _SectionCard(section: s)),
                  ],
                ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final PucSection section;

  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: context.appCardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          collapsedIconColor: context.appMuted,
          iconColor: AppTheme.accentPrimary,
          title: Text(
            section.titulo,
            style: TextStyle(
              color: context.appOnSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            '${section.entries.length} cuentas',
            style: TextStyle(color: context.appMuted, fontSize: 11),
          ),
          children: [
            Divider(height: 1, color: context.appBorder),
            ...section.entries.map((e) => _EntryRow(entry: e)),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final PucEntry entry;

  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              entry.codigo,
              style: const TextStyle(
                color: AppTheme.accentPrimary,
                fontFamily: 'RobotoMono',
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.cuenta,
              style: TextStyle(
                color: context.appOnSurface,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
