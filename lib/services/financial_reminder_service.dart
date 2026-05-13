// lib/services/financial_reminder_service.dart
// Recordatorios locales diarios con mensaje desde IA (Groq) o heurística.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/transaction.dart';
import 'ai_service.dart';

const int _kNotificationId = 771001;
/// Id distinto para no interferir con la notificación diaria programada.
const int _kManualPreviewNotificationId = 771099;
const String _kChannelId = 'financial_reminders_v1';

class FinancialReminderService {
  FinancialReminderService._();

  static const prefEnabled = 'financial_reminder_enabled';
  static const prefHour = 'financial_reminder_hour';
  static const prefMinute = 'financial_reminder_minute';
  static const prefLastBody = 'financial_reminder_last_body';
  static const prefLastAiMs = 'financial_reminder_last_ai_ms';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static bool get supportsScheduledNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Llamar una vez al arranque (antes de [runApp] está bien).
  static Future<void> initialize() async {
    if (_initialized) return;
    if (!supportsScheduledNotifications) {
      _initialized = true;
      return;
    }

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('America/Bogota'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    const macInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: InitializationSettings(
        android: androidInit,
        iOS: iosInit,
        macOS: macInit,
      ),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _kChannelId,
          'Consejos y gastos',
          description:
              'Recordatorios diarios con resumen de gastos del mes y consejos.',
          importance: Importance.defaultImportance,
        ),
      );
    }

    _initialized = true;
  }

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(prefEnabled) ?? false;
  }

  static Future<TimeOfDay> scheduledTime() async {
    final p = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: p.getInt(prefHour) ?? 9,
      minute: p.getInt(prefMinute) ?? 0,
    );
  }

  static Future<void> setEnabled(
    BuildContext context, {
    required bool enabled,
    required TimeOfDay time,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(prefEnabled, enabled);
    await p.setInt(prefHour, time.hour);
    await p.setInt(prefMinute, time.minute);

    if (!enabled) {
      await _plugin.cancel(id: _kNotificationId);
      return;
    }

    if (!supportsScheduledNotifications) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Las notificaciones programadas no están disponibles en esta plataforma.',
            ),
          ),
        );
      }
      return;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        ok == false &&
        messenger != null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Activa las notificaciones para DolarSabio en Ajustes del sistema.',
          ),
        ),
      );
    }
  }

  /// Muestra **ya** una notificación con el mismo estilo que la diaria (útil en demos).
  /// No exige tener activado el recordatorio programado. Pide permisos si hace falta.
  static Future<void> showReminderNowManually(
    BuildContext context, {
    required FinancialSummary summary,
    required List<Transaction> transactions,
  }) async {
    if (!supportsScheduledNotifications) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Las notificaciones no están disponibles en esta plataforma.',
            ),
          ),
        );
      }
      return;
    }
    if (!_initialized) await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    if (context.mounted) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
    }

    // Texto fresco para la demo (sin depender del throttle de la programada).
    final body = await AiService.getFinancialDailyReminder(
      summary,
      transactions,
    );
    final truncated = _truncate(body, 220);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        'Consejos y gastos',
        channelDescription:
            'Recordatorios diarios con resumen de gastos del mes y consejos.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id: _kManualPreviewNotificationId,
      title: 'DolarSabio · tu mes y tus números',
      body: truncated,
      notificationDetails: details,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notificación enviada. Revisa la barra de estado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Regenera el texto y reprograma la notificación diaria (si está activada).
  static Future<void> syncScheduledNotification({
    required FinancialSummary summary,
    required List<Transaction> transactions,
  }) async {
    if (!supportsScheduledNotifications) return;
    if (!_initialized) await initialize();

    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(prefEnabled) ?? false)) {
      await _plugin.cancel(id: _kNotificationId);
      return;
    }

    final hour = p.getInt(prefHour) ?? 9;
    final minute = p.getInt(prefMinute) ?? 0;

    final body = await _resolveBody(p, summary, transactions);
    final truncated = _truncate(body, 220);

    final when = _nextInstanceOf(hour, minute);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        'Consejos y gastos',
        channelDescription:
            'Recordatorios diarios con resumen de gastos del mes y consejos.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      id: _kNotificationId,
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'DolarSabio · tu mes y tus números',
      body: truncated,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<String> _resolveBody(
    SharedPreferences p,
    FinancialSummary summary,
    List<Transaction> transactions,
  ) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastAi = p.getInt(prefLastAiMs) ?? 0;
    const throttleMs = 30 * 60 * 1000;
    final cached = p.getString(prefLastBody);

    if (cached != null &&
        cached.isNotEmpty &&
        nowMs - lastAi < throttleMs &&
        AiService.isConfigured) {
      return cached;
    }

    final fresh =
        await AiService.getFinancialDailyReminder(summary, transactions);
    await p.setString(prefLastBody, fresh);
    await p.setInt(prefLastAiMs, nowMs);
    return fresh;
  }

  static String _truncate(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
