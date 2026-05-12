// lib/screens/home_screen.dart
// Equivalente al layout principal del App.tsx con sidebar + tabs

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/excel_service.dart';
import '../services/pdf_service.dart';
import '../utils/app_provider.dart';
import '../utils/theme.dart';
import '../widgets/chat_widget.dart';
import 'dashboard_screen.dart';
import 'spreadsheet_screen.dart';
import '../models/transaction.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.trending_up_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.table_chart_rounded, label: 'Hoja de Cálculo'),
  ];

  @override
  void initState() {
    super.initState();
    context.read<AppProvider>().subscribeToTransactions(widget.user.uid);
  }

  @override
  void dispose() {
    context.read<AppProvider>().cancelSubscription();
    super.dispose();
  }

  Future<void> _importExcel() async {
    final provider = context.read<AppProvider>();
    try {
      final rows = await ExcelService.importFromExcel();
      if (rows == null) return;

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

  void _openNewRecord() {
    setState(() => _tabIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAddTransactionSheet(context);
    });
  }

  Transaction _rowToTransaction(Map<String, dynamic> row, String userId) {
    return Transaction(
      userId: userId,
      recordId: row['recordId']?.toString() ?? '',
      codigo: row['codigo']?.toString() ?? '',
      cuenta: row['cuenta']?.toString() ?? '',
      descripcion: row['descripcion']?.toString() ?? '',
      fecha: row['fecha']?.toString() ??
          DateTime.now().toIso8601String().split('T').first,
      debito: (row['debito'] as num?)?.toDouble() ?? 0,
      credito: (row['credito'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isWide = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      drawer: isWide
          ? null
          : Drawer(
              backgroundColor: AppTheme.darkSurface,
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
                  onImport: () async {
                    Navigator.of(context).pop();
                    await _importExcel();
                  },
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
                  onTemplate: () {
                    Navigator.of(context).pop();
                    ExcelService.downloadTemplate(context);
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
            onImport: _importExcel,
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
            onTemplate: () => ExcelService.downloadTemplate(context),
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
                  onImport: _importExcel,
                  onTemplate: () =>
                      ExcelService.downloadTemplate(context),
                  user: widget.user,
                  onLogout: FirebaseService.logout,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: const [
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
  final VoidCallback onTemplate;
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
    required this.onTemplate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppTheme.darkSurface,
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
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.accentPrimary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: AppTheme.darkBg,
                              size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'DolarSabio',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white,
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

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Divider(color: AppTheme.darkBorder),
                  ),

                  // Acciones
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
                      icon: Icons.upload_rounded,
                      label: 'Importar Excel',
                      onTap: onImport),
                ],
              ),
            ),
          ),

          // Usuario
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.darkBorder),
            ),
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
                          (user.displayName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                              color: AppTheme.darkBg,
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
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                      const Text('Admin',
                          style: TextStyle(
                              color: AppTheme.darkMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5)),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                  icon: const Icon(Icons.logout_rounded,
                      color: AppTheme.darkMuted, size: 16),
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
                      : AppTheme.darkMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? AppTheme.accentPrimary
                        : AppTheme.darkMuted,
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
              Icon(icon, size: 18, color: AppTheme.darkMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.darkMuted,
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
  final VoidCallback onTemplate;
  final User user;
  final VoidCallback onLogout;

  const _TopBar({
    required this.isWide,
    required this.tabIndex,
    required this.navItems,
    required this.onTabChanged,
    required this.onImport,
    required this.onTemplate,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final compactTopBar = screenW < 520;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          // Solo en móvil: drawer + logo
          if (!isWide) ...[
            Builder(builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: AppTheme.darkMuted),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            )),
            Expanded(
              child: Text(
                'DolarSabio',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ] else ...[
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'SISTEMA DE CONTROL CONTABLE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.darkMuted,
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
              icon: const Icon(Icons.upload_rounded,
                  color: AppTheme.darkMuted, size: 20),
              onPressed: onImport,
              tooltip: 'Importar Excel',
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded,
                  color: AppTheme.darkMuted, size: 20),
              onPressed: onTemplate,
              tooltip: 'Descargar plantilla',
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
            IconButton(
              icon: const Icon(Icons.download_rounded,
                  color: AppTheme.darkMuted, size: 18),
              onPressed: onTemplate,
              tooltip: 'Descargar Plantilla',
            ),
          ],

          // Logout en móvil
          if (!isWide)
            IconButton(
              icon: const Icon(Icons.logout_rounded,
                  color: AppTheme.darkMuted, size: 18),
              onPressed: onLogout,
              tooltip: 'Cerrar sesión',
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
