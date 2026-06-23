import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Placeholder de capa on-brand: um wash quente com a marca do app (trama de
/// pontos) discreta ao centro. Usado quando uma aula/peça não tem imagem,
/// no lugar de um ícone genérico.
class CoverPlaceholder extends StatelessWidget {
  const CoverPlaceholder({this.iconSize = 34, super.key});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.linenSoft, AppColors.peach],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.gesture_rounded,
          size: iconSize,
          color: AppColors.coral.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
