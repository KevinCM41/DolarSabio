// lib/screens/home_screen.dart
// Equivalente al layout principal del App.tsx con sidebar + tabs

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/account_history_service.dart';
import '../services/firebase_service.dart';
import '../services/csv_service.dart';
import '../services/excel_service.dart';
import '../services/financial_reminder_service.dart';
import '../services/pdf_service.dart';
import '../services/spreadsheet_import.dart';
import '../utils/app_provider.dart';
import '../utils/theme.dart';
import '../utils/theme_mode_provider.dart';
import '../widgets/app_brand_logo.dart';
import '../widgets/chat_widget.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'spreadsheet_screen.dart';
import 'puc_guide_screen.dart';
import '../models/transaction.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tabIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.trending_up_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.table_chart_rounded, label: 'Hoja de Cálculo'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<AppProvider>().subscribeToTransactions(widget.user.uid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccountHistoryService.touchUser(widget.user);
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (mounted) _syncFinancialReminder();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<AppProvider>().cancelSubscription();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncFinancialReminder();
    }
  }

  void _syncFinancialReminder() {
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    FinancialReminderService.syncScheduledNotification(
      summary: provider.summary,
      transactions: provider.sortedByDate,
    );
  }

  Future<void> _showImportSheet(BuildContext context) async {
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
        final menuText = TextStyle(
          color: onS,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.table_chart_rounded, color: muted),
                title: Text('Importar Excel (.xlsx / .xls)', style: menuText),
                subtitle: Text(
                  'Hoja recomendada: «Transacciones». Columnas: ID, Código, Cuenta…',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _importRows(ExcelService.importFromExcel);
                },
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.35)),
              ListTile(
                leading: Icon(Icons.text_snippet_rounded, color: muted),
                title: Text('Importar CSV (.csv)', style: menuText),
                subtitle: Text(
                  'UTF-8, separador coma. Mismas columnas que la exportación.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _importRows(CsvService.importFromCsv);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importRows(
    Future<List<Map<String, dynamic>>?> Function() loadRows,
  ) async {
    final provider = context.read<AppProvider>();
    try {
      final rows = await loadRows();
      if (rows == null) return;

      final diag = loadRows == ExcelService.importFromExcel
          ? ExcelService.lastDiagnostics
          : (loadRows == CsvService.importFromCsv
              ? CsvService.lastDiagnostics
              : '');

      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 8),
              content: Text(
                diag.isEmpty
                    ? 'No se importó ninguna fila. Revisa cabeceras y que el archivo no esté vacío.'
                    : 'No se importó ninguna fila.\n$diag',
              ),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
        return;
      }

      final userId = provider.currentUserId ?? widget.user.uid;
      for (final row in rows) {
        await provider.addTransaction(_rowToTransaction(row, userId));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${rows.length} registros importados correctamente'),
            backgroundColor: AppTheme.accentPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  void _openImportFromDrawer(BuildContext context) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showImportSheet(context);
    });
  }

  void _openNewRecord() {
    setState(() => _tabIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAddTransactionSheet(context);
    });
  }

  Transaction _rowToTransaction(Map<String, dynamic> row, String userId) {
    double asDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is String) return parseImportAmount(v) ?? 0;
      return double.tryParse(v.toString()) ?? 0;
    }

    return Transaction(
      userId: userId,
      recordId: row['recordId']?.toString() ?? '',
      codigo: row['codigo']?.toString() ?? '',
      cuenta: row['cuenta']?.toString() ?? '',
      descripcion: row['descripcion']?.toString() ?? '',
      fecha: row['fecha']?.toString() ??
          DateTime.now().toIso8601String().split('T').first,
      debito: asDouble(row['debito']),
      credito: asDouble(row['credito']),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
    );
  }

  void _openPucGuide(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PucGuideScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isWide = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: context.appBackground,
      drawer: isWide
          ? null
          : Drawer(
              backgroundColor: context.appSurface,
              child: SafeArea(
                child: _SideNav(
                  user: widget.user,
                  selectedIndex: _tabIndex,
                  navItems: _navItems,
                  onSelect: (i) {
                    Navigator.of(context).pop(); // cierra el drawer
                    setState(() => _tabIndex = i);
                  },
                  onNewRecord: () {
                    Navigator.of(context).pop();
                    _openNewRecord();
                  },
                  onImport: () => _openImportFromDrawer(context),
                  onExportPdf: () {
                    Navigator.of(context).pop();
                    PdfService.generateAndShareReport(
                      context,
                      provider.transactions,
                      provider.summary,
                      provider.columnLabels,
                    );
                  },
                  onExportExcel: () {
                    Navigator.of(context).pop();
                    ExcelService.exportToExcel(
                      context,
                      provider.transactions,
                      provider.columnLabels,
                    );
                  },
                  onExportCsv: () {
                    Navigator.of(context).pop();
                    CsvService.exportToCsv(
                      context,
                      provider.transactions,
                      provider.columnLabels,
                    );
                  },
                  onTemplate: () {
                    Navigator.of(context).pop();
                    ExcelService.downloadTemplate(
                      context,
                      provider.columnLabels,
                    );
                  },
                  onProfile: () {
                    Navigator.of(context).pop();
                    _openProfile(context);
                  },
                  onPucGuide: () {
                    Navigator.of(context).pop();
                    _openPucGuide(context);
                  },
                  onLogout: () {
                    Navigator.of(context).pop();
                    FirebaseService.logout();
                  },
                ),
              ),
            ),
      // ── Navigation Rail para tablet/desktop ────────────────────────
      body: Row(
        children: [
          if (isWide) _SideNav(
            user: widget.user,
            selectedIndex: _tabIndex,
            navItems: _navItems,
            onSelect: (i) => setState(() => _tabIndex = i),
            onNewRecord: _openNewRecord,
            onImport: () => _showImportSheet(context),
            onExportPdf: () => PdfService.generateAndShareReport(
              context,
              provider.transactions,
              provider.summary,
              provider.columnLabels,
            ),
            onExportExcel: () => ExcelService.exportToExcel(
              context,
              provider.transactions,
              provider.columnLabels,
            ),
            onExportCsv: () => CsvService.exportToCsv(
              context,
              provider.transactions,
              provider.columnLabels,
            ),
            onTemplate: () => ExcelService.downloadTemplate(
              context,
              provider.columnLabels,
            ),
            onProfile: () => _openProfile(context),
            onPucGuide: () => _openPucGuide(context),
            onLogout: FirebaseService.logout,
          ),

          // ── Contenido principal ──────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  isWide: isWide,
                  tabIndex: _tabIndex,
                  navItems: _navItems,
                  onTabChanged: (i) => setState(() => _tabIndex = i),
                  onImport: () => _showImportSheet(context),
                  onExportPdf: () => PdfService.generateAndShareReport(
                    context,
                    provider.transactions,
                    provider.summary,
                    provider.columnLabels,
                  ),
                  onExportExcel: () => ExcelService.exportToExcel(
                    context,
                    provider.transactions,
                    provider.columnLabels,
                  ),
                  onExportCsv: () => CsvService.exportToCsv(
                    context,
                    provider.transactions,
                    provider.columnLabels,
                  ),
                  onTemplate: () => ExcelService.downloadTemplate(
                    context,
                    provider.columnLabels,
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      DashboardScreen(),
                      SpreadsheetScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ── FAB del chat flotante ──────────────────────────────────────
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 8, right: 8),
        child: ChatWidget(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ── Barra lateral (tablet / desktop) ──────────────────────────────────────
class _SideNav extends StatelessWidget {
  final User user;
  final int selectedIndex;
  final List<_NavItem> navItems;
  final void Function(int) onSelect;
  final VoidCallback onNewRecord;
  final VoidCallback onImport;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;
  final VoidCallback onExportCsv;
  final VoidCallback onTemplate;
  final VoidCallback onProfile;
  final VoidCallback onPucGuide;
  final VoidCallback onLogout;

  const _SideNav({
    required this.user,
    required this.selectedIndex,
    required this.navItems,
    required this.onSelect,
    required this.onNewRecord,
    required this.onImport,
    required this.onExportPdf,
    required this.onExportExcel,
    required this.onExportCsv,
    required this.onTemplate,
    required this.onProfile,
    required this.onPucGuide,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: context.appSurface,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                    child: Row(
                      children: [
                        const AppBrandLogo(size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'DolarSabio',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: context.appOnSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Nav tabs
                  ...navItems.asMap().entries.map((e) => _NavButton(
                        item: e.value,
                        selected: selectedIndex == e.key,
                        onTap: () => onSelect(e.key),
                      )),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Divider(color: context.appBorder),
                  ),

                  // Acciones
                  _ActionButton(
                      icon: Icons.person_rounded,
                      label: 'Perfil',
                      onTap: onProfile),
                  _ActionButton(
                      icon: Icons.menu_book_rounded,
                      label: 'Guía PUC',
                      onTap: onPucGuide),
                  _ActionButton(
                      icon: Icons.add,
                      label: 'Nuevo Registro',
                      onTap: onNewRecord),
                  _ActionButton(
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'Reporte PDF',
                      onTap: onExportPdf),
                  _ActionButton(
                      icon: Icons.download_rounded,
                      label: 'Exportar Excel',
                      onTap: onExportExcel),
                  _ActionButton(
                      icon: Icons.text_snippet_rounded,
                      label: 'Exportar CSV',
                      onTap: onExportCsv),
                  _ActionButton(
                      icon: Icons.upload_rounded,
                      label: 'Importar datos',
                      onTap: onImport),
                ],
              ),
            ),
          ),

          // Usuario (toca para Perfil; botón solo cierra sesión)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.appBackground.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onProfile,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: user.photoURL != null
                                  ? NetworkImage(user.photoURL!)
                                  : null,
                              backgroundColor: AppTheme.accentPrimary,
                              child: user.photoURL == null
                                  ? Text(
                                      (user.displayName ?? 'U')[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          color: AppTheme.onAccentBrand,
                                          fontWeight: FontWeight.w700),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName ?? 'Usuario',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: context.appOnSurface,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text('Admin',
                                      style: TextStyle(
                                          color: context.appMuted,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 36, height: 36),
                  icon: Icon(Icons.logout_rounded,
                      color: context.appMuted, size: 16),
                  onPressed: onLogout,
                  tooltip: 'Cerrar sesión',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton(
      {required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accentPrimary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(item.icon,
                  size: 18,
                  color: selected
                      ? AppTheme.accentPrimary
                      : context.appMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? AppTheme.accentPrimary
                        : context.appMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: context.appMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.appMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top bar (móvil + cabecera) ─────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final bool isWide;
  final int tabIndex;
  final List<_NavItem> navItems;
  final void Function(int) onTabChanged;
  final VoidCallback onImport;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;
  final VoidCallback onExportCsv;
  final VoidCallback onTemplate;

  const _TopBar({
    required this.isWide,
    required this.tabIndex,
    required this.navItems,
    required this.onTabChanged,
    required this.onImport,
    required this.onExportPdf,
    required this.onExportExcel,
    required this.onExportCsv,
    required this.onTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final compactTopBar = screenW < 520;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      child: Row(
        children: [
          // Solo en móvil: drawer + logo
          if (!isWide) ...[
            Builder(builder: (ctx) => IconButton(
              icon: Icon(Icons.menu_rounded, color: context.appMuted),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            )),
            Expanded(
              child: Row(
                children: [
                  const AppBrandLogoBar(height: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'DolarSabio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.appOnSurface,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Expanded(
              child: Row(
                children: [
                  const AppBrandLogoBar(height: 22),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'SISTEMA DE CONTROL CONTABLE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.appMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              AppTheme.accentPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.accentPrimary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentPrimary
                                    .withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'AI Core Online',
                          style: TextStyle(
                              color: AppTheme.accentPrimary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Importar / plantilla: en pantallas estrechas solo iconos (evita overflow)
          if (!isWide && compactTopBar) ...[
            IconButton(
              icon: Icon(Icons.upload_rounded,
                  color: context.appMuted, size: 20),
              onPressed: onImport,
              tooltip: 'Importar datos',
            ),
            _TopBarExportMenu(
              iconSize: 20,
              onExportExcel: onExportExcel,
              onExportCsv: onExportCsv,
              onExportPdf: onExportPdf,
              onTemplate: onTemplate,
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_rounded, size: 14),
              label: const Text('Importar'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            _TopBarExportMenu(
              iconSize: 18,
              onExportExcel: onExportExcel,
              onExportCsv: onExportCsv,
              onExportPdf: onExportPdf,
              onTemplate: onTemplate,
            ),
          ],

          const _ThemeModePopupButton(),
        ],
      ),
    );
  }
}

/// Mismas acciones que en el drawer lateral: exportar datos + plantilla vacía.
class _TopBarExportMenu extends StatelessWidget {
  final double iconSize;
  final VoidCallback onExportExcel;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;
  final VoidCallback onTemplate;

  const _TopBarExportMenu({
    required this.iconSize,
    required this.onExportExcel,
    required this.onExportCsv,
    required this.onExportPdf,
    required this.onTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final menuText = TextStyle(
      color: context.appOnSurface,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    return PopupMenuButton<int>(
      tooltip: 'Exportar / plantilla',
      color: context.appSurface,
      surfaceTintColor: Colors.transparent,
      icon: Icon(Icons.download_rounded,
          color: context.appMuted, size: iconSize),
      offset: const Offset(0, 40),
      onSelected: (v) {
        switch (v) {
          case 0:
            onExportExcel();
            break;
          case 1:
            onExportCsv();
            break;
          case 2:
            onExportPdf();
            break;
          case 3:
            onTemplate();
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 0,
          child: Row(
            children: [
              Icon(Icons.table_chart_rounded,
                  size: 18, color: context.appMuted),
              const SizedBox(width: 10),
              Text('Exportar Excel', style: menuText),
            ],
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: Row(
            children: [
              Icon(Icons.text_snippet_rounded,
                  size: 18, color: context.appMuted),
              const SizedBox(width: 10),
              Text('Exportar CSV', style: menuText),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded,
                  size: 18, color: context.appMuted),
              const SizedBox(width: 10),
              Text('Reporte PDF', style: menuText),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 3,
          child: Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 18, color: context.appMuted),
              const SizedBox(width: 10),
              Text('Descargar plantilla', style: menuText),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeModePopupButton extends StatelessWidget {
  const _ThemeModePopupButton();

  @override
  Widget build(BuildContext context) {
    final listenable = context.read<ThemeModeProvider>();
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final icon = switch (listenable.themeMode) {
          ThemeMode.dark => Icons.dark_mode_rounded,
          ThemeMode.light => Icons.light_mode_rounded,
          _ => Icons.brightness_auto_rounded,
        };
        return IconButton(
          tooltip: 'Tema',
          icon: Icon(icon, color: context.appMuted, size: 22),
          onPressed: () => _openThemeBottomSheet(context),
        );
      },
    );
  }

  /// Cierra el sheet antes de [setThemeMode], evitando la ruta del popup y el
  /// error "Looking up a deactivated widget's ancestor".
  static Future<void> _openThemeBottomSheet(BuildContext context) async {
    final provider = context.read<ThemeModeProvider>();
    final current = provider.themeMode;
    final surface = Theme.of(context).colorScheme.surface;

    final chosen = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      backgroundColor: surface,
      builder: (sheetContext) {
        Widget tile(ThemeMode mode, IconData ic, String label) {
          final selected = current == mode;
          return ListTile(
            leading: Icon(ic, color: sheetContext.appOnSurface),
            title: Text(
              label,
              style: TextStyle(color: sheetContext.appOnSurface),
            ),
            trailing: selected
                ? Icon(
                    Icons.check,
                    color: Theme.of(sheetContext).colorScheme.primary,
                  )
                : null,
            onTap: () => Navigator.pop(sheetContext, mode),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(
                ThemeMode.system,
                Icons.brightness_auto_rounded,
                'Según el sistema',
              ),
              tile(
                ThemeMode.light,
                Icons.light_mode_rounded,
                'Modo claro',
              ),
              tile(
                ThemeMode.dark,
                Icons.dark_mode_rounded,
                'Modo oscuro',
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted || chosen == null || chosen == current) return;
    await provider.setThemeMode(chosen);
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
