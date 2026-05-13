import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// Logo cuadrado / marca en tarjetas y drawer.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    required this.size,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  final double size;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.14);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          AppTheme.logoAsset,
          fit: fit,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: AppTheme.accentPrimary.withValues(alpha: 0.12),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: AppTheme.accentPrimary,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo en barra (altura fija, mantiene proporción).
/// Esquinas como [AppBrandLogo]: `height * 0.14`.
class AppBrandLogoBar extends StatelessWidget {
  const AppBrandLogoBar({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height * 0.14);
    return ClipRRect(
      borderRadius: radius,
      child: Image.asset(
        AppTheme.logoAsset,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => SizedBox(
          height: height,
          width: height,
          child: ColoredBox(
            color: AppTheme.accentPrimary.withValues(alpha: 0.12),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: AppTheme.accentPrimary,
              size: height * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}
