import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Fundo padrão do app: branco neutro (#FAFAFA), liso.
/// Mantém o parâmetro [gradient] para telas que queiram um degradê específico.
class GradientBg extends StatelessWidget {
  const GradientBg({required this.child, this.gradient, super.key});
  final Widget child;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    if (gradient != null) {
      return DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: child,
      );
    }
    return ColoredBox(color: AppColors.background, child: child);
  }
}

/// Sombra suave de duas camadas — uma sombra de contato curta + uma ambiente
/// difusa, ambas quentes. Dá aos cards a sensação de papel flutuando, bem mais
/// rica que uma sombra única.
List<BoxShadow> softShadow([double opacity = 0.06]) => [
      BoxShadow(
        color: AppColors.shadow.withValues(alpha: opacity * 0.7),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: AppColors.shadow.withValues(alpha: opacity),
        blurRadius: 28,
        spreadRadius: -4,
        offset: const Offset(0, 12),
      ),
    ];

/// Sombra mais presente para elementos flutuantes (nav, FABs, botões-herói).
List<BoxShadow> elevatedShadow([double opacity = 0.16]) => [
      BoxShadow(
        color: AppColors.shadow.withValues(alpha: opacity * 0.5),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
      BoxShadow(
        color: AppColors.shadow.withValues(alpha: opacity),
        blurRadius: 36,
        spreadRadius: -6,
        offset: const Offset(0, 18),
      ),
    ];
