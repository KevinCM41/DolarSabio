// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_navigator.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/firebase_service.dart';
import 'services/puc_catalog.dart';
import 'utils/app_provider.dart';
import 'utils/theme.dart';
import 'utils/theme_mode_provider.dart';

// ── IMPORTANTE ───────────────────────────────────────────────────────────────
// Debes crear el archivo lib/firebase_options.dart con FlutterFire CLI:
//   flutterfire configure
// Y reemplazar la línea de DefaultFirebaseOptions abajo.
// ─────────────────────────────────────────────────────────────────────────────
import 'firebase_options.dart';
import 'services/financial_reminder_service.dart';

void main() async {
  FlutterError.onError = FlutterError.presentError;
  try {
    WidgetsFlutterBinding.ensureInitialized();

    await PucCatalog.ensureLoaded();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FinancialReminderService.initialize();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider(create: (_) => ThemeModeProvider()),
        ],
        child: Builder(
          builder: (context) {
            return const _AppRoot();
          },
        ),
      ),
    );
  } catch (e, stackTrace) {
    Error.throwWithStackTrace(e, stackTrace);
  }
}

/// [MaterialApp] con [themeMode] vía listener manual: evita `context.watch` en el
/// mismo widget que devuelve [MaterialApp], que con Provider suele disparar
/// "Looking up a deactivated widget's ancestor" al cambiar tema.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  ThemeModeProvider? _theme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<ThemeModeProvider>();
    if (!identical(_theme, next)) {
      _theme?.removeListener(_onThemeModeChanged);
      _theme = next;
      _theme!.addListener(_onThemeModeChanged);
    }
  }

  void _onThemeModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _theme?.removeListener(_onThemeModeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = _theme?.themeMode ?? ThemeMode.system;

    return MaterialApp(
      title: 'DolarSabio',
      debugShowCheckedModeBanner: false,
      navigatorKey: appRootNavigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      themeAnimationCurve: Curves.linear,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final overlay = dark
            ? SystemUiOverlayStyle.light
                .copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark
                .copyWith(statusBarColor: Colors.transparent);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: StreamBuilder(
        stream: FirebaseService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                ),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return HomeScreen(user: snapshot.data!);
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
