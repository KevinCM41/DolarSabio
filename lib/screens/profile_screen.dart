// lib/screens/profile_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_navigator.dart';
import '../services/account_history_service.dart';
import '../services/financial_reminder_service.dart';
import '../services/firebase_service.dart';
import '../utils/app_provider.dart';
import '../utils/theme.dart';
import '../utils/theme_mode_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<SavedAccount> _accounts = [];
  bool _loading = true;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await AccountHistoryService.load();
    final reminderOn = await FinancialReminderService.isEnabled();
    final reminderT = await FinancialReminderService.scheduledTime();
    if (mounted) {
      setState(() {
        _accounts = list;
        _reminderEnabled = reminderOn;
        _reminderTime = reminderT;
        _loading = false;
      });
    }
  }

  Future<void> _applyReminderEnabled(bool value) async {
    await FinancialReminderService.setEnabled(
      context,
      enabled: value,
      time: _reminderTime,
    );
    if (!mounted) return;
    setState(() => _reminderEnabled = value);
    if (value) {
      final app = context.read<AppProvider>();
      await FinancialReminderService.syncScheduledNotification(
        summary: app.summary,
        transactions: app.sortedByDate,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Recordatorio diario activado a las ${_formatTime(_reminderTime)}.'
                : 'Recordatorios desactivados.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null || !mounted) return;
    await FinancialReminderService.setEnabled(
      context,
      enabled: _reminderEnabled,
      time: picked,
    );
    if (!mounted) return;
    setState(() => _reminderTime = picked);
    if (_reminderEnabled) {
      final app = context.read<AppProvider>();
      await FinancialReminderService.syncScheduledNotification(
        summary: app.summary,
        transactions: app.sortedByDate,
      );
    }
  }

  Future<void> _showReminderDemoNow() async {
    if (!FinancialReminderService.supportsScheduledNotifications) return;
    final app = context.read<AppProvider>();
    await FinancialReminderService.showReminderNowManually(
      context,
      summary: app.summary,
      transactions: app.sortedByDate,
    );
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Aplica el tema tras el frame actual para no notificar Provider mientras el
  /// árbol del tile aún se desmonta (evita ancestor desactivado).
  void _setThemeModeAfterFrame(BuildContext context, ThemeMode mode) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      await context.read<ThemeModeProvider>().setThemeMode(mode);
    });
  }

  /// Cierra sesión y deja solo la ruta raíz (login), quitando Perfil u otras superpuestas.
  void _popOverlayRoutesToRoot() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appRootNavigatorKey.currentState
          ?.popUntil((route) => route.isFirst);
    });
  }

  Future<void> _signOutOnly() async {
    await FirebaseService.logout();
    _popOverlayRoutesToRoot();
  }

  Future<void> _logoutAndSignInWithGoogle({String? hintEmail}) async {
    if (hintEmail != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Después, en Google elige «$hintEmail» si aparece en la lista.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    await FirebaseService.logout();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      appRootNavigatorKey.currentState
          ?.popUntil((route) => route.isFirst);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      try {
        await FirebaseService.loginWithGoogle();
      } catch (e) {
        final m = appRootNavigatorKey.currentContext;
        if (m != null && m.mounted) {
          ScaffoldMessenger.of(m).showSnackBar(
            SnackBar(
              content: Text('Error al iniciar con Google: $e'),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
      }
    });
  }

  Future<void> _confirmSwitch() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(
          'Cambiar de cuenta',
          style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface,
              fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Se cerrará la sesión y se abrirá el inicio de sesión de Google. '
          'Elige la cuenta que quieras usar.',
          style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.75),
              height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await _logoutAndSignInWithGoogle();
  }

  Future<void> _removeSaved(SavedAccount a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(
          'Quitar de este dispositivo',
          style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface,
              fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Se borrará «${a.displayName ?? a.email}» de la lista local. '
          'No elimina datos en la nube.',
          style: TextStyle(
              color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.75),
              height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AccountHistoryService.removeUid(a.uid);
    await _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta quitada de la lista en este dispositivo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final otherAccounts = _accounts
        .where((a) => user == null || a.uid != user.uid)
        .toList();

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        foregroundColor: context.appOnSurface,
        title: Text('Perfil', style: TextStyle(color: context.appOnSurface)),
        elevation: 0,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 2,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ListenableBuilder(
                  listenable: context.read<ThemeModeProvider>(),
                  builder: (context, _) {
                    final tm = context.read<ThemeModeProvider>();
                    return Container(
                      decoration: context.appCardDecoration(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Apariencia', style: context.appLabelStyle),
                          const SizedBox(height: 10),
                          Text(
                            'Tema de la interfaz',
                            style: TextStyle(
                              color: context.appOnSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ThemeOptionTile(
                            icon: Icons.brightness_auto_rounded,
                            label: 'Según el sistema',
                            selected: tm.themeMode == ThemeMode.system,
                            onTap: () => _setThemeModeAfterFrame(
                              context,
                              ThemeMode.system,
                            ),
                          ),
                          _ThemeOptionTile(
                            icon: Icons.light_mode_rounded,
                            label: 'Modo claro',
                            selected: tm.themeMode == ThemeMode.light,
                            onTap: () => _setThemeModeAfterFrame(
                              context,
                              ThemeMode.light,
                            ),
                          ),
                          _ThemeOptionTile(
                            icon: Icons.dark_mode_rounded,
                            label: 'Modo oscuro',
                            selected: tm.themeMode == ThemeMode.dark,
                            onTap: () => _setThemeModeAfterFrame(
                              context,
                              ThemeMode.dark,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: context.appCardDecoration(),
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Text(
                          'Recordatorios',
                          style: context.appLabelStyle,
                        ),
                      ),
                      SwitchListTile(
                        value: _reminderEnabled,
                        activeThumbColor: AppTheme.accentPrimary,
                        title: Text(
                          'Consejo financiero diario',
                          style: TextStyle(
                            color: context.appOnSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Una notificación al día con resumen del mes y consejo financiero'
                          ,
                          style: TextStyle(
                            color: context.appMuted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        onChanged: FinancialReminderService
                                .supportsScheduledNotifications
                            ? _applyReminderEnabled
                            : null,
                      ),
                      if (!FinancialReminderService
                          .supportsScheduledNotifications)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            'No disponible en web ni en este escritorio.',
                            style: TextStyle(
                              color: context.appMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ListTile(
                        enabled: _reminderEnabled &&
                            FinancialReminderService
                                .supportsScheduledNotifications,
                        leading: Icon(
                          Icons.schedule_rounded,
                          color: context.appMuted,
                        ),
                        title: Text(
                          'Hora',
                          style: TextStyle(color: context.appOnSurface),
                        ),
                        trailing: Text(
                          _formatTime(_reminderTime),
                          style: TextStyle(
                            color: AppTheme.accentPrimary,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'RobotoMono',
                          ),
                        ),
                        onTap: _reminderEnabled &&
                                FinancialReminderService
                                    .supportsScheduledNotifications
                            ? _pickReminderTime
                            : null,
                      ),
                      if (FinancialReminderService
                          .supportsScheduledNotifications)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _showReminderDemoNow,
                            icon: Icon(
                              Icons.notifications_active_rounded,
                              color: AppTheme.accentPrimary,
                              size: 20,
                            ),
                            label: Text(
                              'Mostrar notificación ahora',
                              style: TextStyle(
                                color: context.appOnSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentPrimary,
                              side: BorderSide(
                                color: AppTheme.accentPrimary
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (user != null) ...[
                  Text('Sesión actual', style: context.appLabelStyle),
                  const SizedBox(height: 10),
                  _UserCard(
                    title: user.displayName ?? 'Usuario',
                    subtitle: user.email ?? user.uid,
                    photoUrl: user.photoURL,
                    letter: (user.displayName ?? user.email ?? 'U')[0],
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.accentPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'Activa',
                        style: TextStyle(
                          color: AppTheme.accentPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                Text('Cuentas en este dispositivo', style: context.appLabelStyle),
                const SizedBox(height: 6),
                Text(
                  'Toca una cuenta para cerrar sesión y abrir Google con esa cuenta. '
                  'La X solo la quita de la lista local.',
                  style: TextStyle(
                    color: context.appMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                if (otherAccounts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No hay otras cuentas guardadas en este dispositivo. '
                      'Cambia de cuenta con Google para sumar otra a la lista.',
                      style: TextStyle(color: context.appMuted, height: 1.4),
                    ),
                  )
                else
                  ...otherAccounts.map((a) {
                    final hint = a.email.isNotEmpty ? a.email : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _UserCard(
                        title: a.displayName?.isNotEmpty == true
                            ? a.displayName!
                            : (a.email.isNotEmpty ? a.email : 'Usuario'),
                        subtitle: a.email.isNotEmpty ? a.email : a.uid,
                        photoUrl: a.photoUrl,
                        letter: ((a.displayName?.isNotEmpty == true)
                                ? a.displayName!
                                : (a.email.isNotEmpty ? a.email : a.uid))[0],
                        onTap: () => _logoutAndSignInWithGoogle(hintEmail: hint),
                        trailing: IconButton(
                          tooltip: 'Quitar de la lista',
                          icon: Icon(Icons.close_rounded,
                              color: context.appMuted, size: 20),
                          onPressed: () => _removeSaved(a),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _confirmSwitch();
                    },
                    icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                    label: const Text('Cambiar de cuenta (Google)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.appOnSurface,
                      side: BorderSide(color: context.appBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _signOutOnly,
                    icon: const Icon(Icons.logout_rounded,
                        color: AppTheme.accentRed, size: 20),
                    label: const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: AppTheme.accentRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: context.appMuted, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: context.appOnSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: AppTheme.accentPrimary, size: 22)
          : null,
      onTap: onTap,
    );
  }
}

class _UserCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? photoUrl;
  final String letter;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _UserCard({
    required this.title,
    required this.subtitle,
    required this.photoUrl,
    required this.letter,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inner = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl!) : null,
            backgroundColor: AppTheme.accentPrimary,
            child: photoUrl == null
                ? Text(
                    letter.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.onAccentBrand,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appOnSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );

    if (onTap == null) {
      return Container(
        decoration: context.appCardDecoration(),
        child: inner,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: context.appCardDecoration(),
          child: inner,
        ),
      ),
    );
  }
}
