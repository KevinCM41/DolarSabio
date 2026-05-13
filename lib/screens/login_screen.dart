// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../utils/theme.dart';
import '../widgets/app_brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _registerMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _googleLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(BuildContext context, String label,
      {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.appMuted, fontSize: 13),
      floatingLabelStyle: const TextStyle(color: AppTheme.accentPrimary),
      filled: true,
      fillColor: context.appBackground,
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.appBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.appBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppTheme.accentPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.accentRed.withValues(alpha: 0.8)),
      ),
    );
  }

  void _onEmailFormSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _registerMode
              ? 'Registro por email: vista de demostración. Para ingresar usa «Continuar con Google».'
              : 'Inicio de sesión por email: vista de demostración. Para ingresar usa «Continuar con Google».',
        ),
        backgroundColor: context.appCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await FirebaseService.loginWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar sesión: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
    if (!v.contains('@') || v.trim().length < 5) return 'Correo no válido';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa la contraseña';
    if (v.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (!_registerMode) return null;
    if (v != _passwordCtrl.text) return 'Las contraseñas no coinciden';
    return _validatePassword(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: context.appBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                        alpha: context.isAppDarkMode ? 0.4 : 0.08),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: ColoredBox(
                          color: AppTheme.accentPrimary.withValues(alpha: 0.08),
                          child: const AppBrandLogo(
                            size: 72,
                            fit: BoxFit.contain,
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'DolarSabio',
                        style: TextStyle(
                          color: context.appOnSurface,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Gestión financiera con IA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.appMuted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('Iniciar sesión'),
                            icon: Icon(Icons.login_rounded, size: 18),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('Registrarse'),
                            icon: Icon(Icons.person_add_rounded, size: 18),
                          ),
                        ],
                        selected: {_registerMode},
                        onSelectionChanged: (Set<bool> next) {
                          setState(() => _registerMode = next.single);
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? (context.isAppDarkMode
                                    ? AppTheme.darkBg
                                    : AppTheme.lightPrimaryButtonOn)
                                : context.appMuted,
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? AppTheme.accentPrimary
                                : context.appBackground,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_registerMode) ...[
                        TextFormField(
                          controller: _nameCtrl,
                          style: TextStyle(color: context.appOnSurface),
                          textInputAction: TextInputAction.next,
                          decoration: _fieldDecoration(context, 'Nombre (opcional)'),
                        ),
                        const SizedBox(height: 14),
                      ],

                      TextFormField(
                        controller: _emailCtrl,
                        style: TextStyle(color: context.appOnSurface),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: _validateEmail,
                        decoration: _fieldDecoration(context, 'Correo electrónico'),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _passwordCtrl,
                        style: TextStyle(color: context.appOnSurface),
                        obscureText: _obscurePassword,
                        textInputAction: _registerMode
                            ? TextInputAction.next
                            : TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        validator: _validatePassword,
                        decoration: _fieldDecoration(
                          context,
                          'Contraseña',
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: context.appMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),

                      if (_registerMode) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmCtrl,
                          style: TextStyle(color: context.appOnSurface),
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          validator: _validateConfirm,
                          decoration: _fieldDecoration(
                            context,
                            'Confirmar contraseña',
                            suffix: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: context.appMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _onEmailFormSubmit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _registerMode ? 'Crear cuenta' : 'Entrar',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(child: Divider(color: context.appBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'o',
                              style: TextStyle(
                                color: context.appMuted.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: context.appBorder)),
                        ],
                      ),
                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _googleLoading ? null : _loginWithGoogle,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                            shadowColor: Colors.black26,
                          ),
                          child: _googleLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.accentPrimary,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.g_mobiledata_rounded,
                                      size: 28,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Continuar con Google',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.appMuted.withValues(alpha: 0.85),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
