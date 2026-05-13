import 'package:flutter/material.dart';

/// [Navigator] raíz del [MaterialApp]. Permite hacer `popUntil` tras cerrar sesión
/// desde rutas superpuestas (p. ej. Perfil), para que se vea el login de inmediato.
final GlobalKey<NavigatorState> appRootNavigatorKey = GlobalKey<NavigatorState>();
