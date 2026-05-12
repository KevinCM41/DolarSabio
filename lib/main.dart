// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/firebase_service.dart';
import 'utils/app_provider.dart';
import 'utils/theme.dart';

// ── IMPORTANTE ───────────────────────────────────────────────────────────────
// Debes crear el archivo lib/firebase_options.dart con FlutterFire CLI:
//   flutterfire configure
// Y reemplazar la línea de DefaultFirebaseOptions abajo.
// ─────────────────────────────────────────────────────────────────────────────
import 'firebase_options.dart';

void main() async {
  FlutterError.onError = FlutterError.presentError;
  try {
    WidgetsFlutterBinding.ensureInitialized();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    runApp(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const DolarSabioApp(),
      ),
    );
  } catch (e, stackTrace) {
    Error.throwWithStackTrace(e, stackTrace);
  }
}

class DolarSabioApp extends StatelessWidget {
  const DolarSabioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DolarSabio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: StreamBuilder(
        stream: FirebaseService.authStateChanges,
        builder: (context, snapshot) {
          // Cargando
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppTheme.darkBg,
              body: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.accentPrimary,
                  strokeWidth: 2,
                ),
              ),
            );
          }

          // Autenticado
          if (snapshot.hasData && snapshot.data != null) {
            return HomeScreen(user: snapshot.data!);
          }

          // No autenticado
          return const LoginScreen();
        },
      ),
    );
  }
}
