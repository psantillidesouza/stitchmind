import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Selo "Premium" com cadeado, sobreposto na capa de aulas/cursos premium
/// (mostrado para quem ainda não é assinante).
class PremiumLockBadge extends StatelessWidget {
  const PremiumLockBadge({this.compact = false, super.key});

  /// Versão menor (para tiles/linhas).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [AppColors.ochre, AppColors.gold]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: compact ? 11 : 12, color: AppColors.paper),
          const SizedBox(width: 4),
          Text(
            'Premium',
            style: AppText.badge.copyWith(
              fontSize: compact ? 10 : 11,
              color: AppColors.paper,
            ),
          ),
        ],
      ),
    );
  }
}
