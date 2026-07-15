import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'gradient_bg.dart';

/// Paginação numerada compacta (1 2 3 … última) — reutilizável.
/// Mostra no máximo o grupo inicial/atual + reticências + última página,
/// então não cresce com o total. Setas ‹ › para avançar/voltar.
class Pager extends StatelessWidget {
  const Pager({
    super.key,
    required this.total,
    required this.current,
    required this.onSelect,
  });
  final int total; // total de páginas
  final int current; // página atual (base 0)
  final ValueChanged<int> onSelect;

  /// Tokens a exibir: números (1-based) e `null` = reticências.
  /// 1 2 3 … N  ·  1 … k-1 k k+1 … N  ·  1 … N-2 N-1 N
  List<int?> _tokens() {
    final cur = current + 1; // 1-based
    final s = <int>{1, total, cur};
    if (cur <= 3) {
      s.addAll([2, 3]);
    } else if (cur >= total - 2) {
      s.addAll([total - 1, total - 2]);
    } else {
      s.addAll([cur - 1, cur + 1]);
    }
    final sorted = s.where((p) => p >= 1 && p <= total).toList()..sort();
    final out = <int?>[];
    int? prev;
    for (final p in sorted) {
      if (prev != null && p - prev > 1) out.add(null); // reticências
      out.add(p);
      prev = p;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          _arrow(Icons.chevron_left_rounded, current > 0,
              () => onSelect(current - 1)),
          for (final t in _tokens())
            if (t == null)
              const SizedBox(
                width: 28,
                height: 40,
                child: Center(
                  child: Text('…',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.walnutMuted)),
                ),
              )
            else
              _num(t, t == current + 1, () => onSelect(t - 1)),
          _arrow(Icons.chevron_right_rounded, current < total - 1,
              () => onSelect(current + 1)),
        ],
      ),
    );
  }

  Widget _num(int n, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: active ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.coral : AppColors.card,
          borderRadius: BorderRadius.circular(13),
          border: active ? null : Border.all(color: AppColors.hairline, width: 1),
          boxShadow: active ? softShadow(0.12) : null,
        ),
        child: Text('$n',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.paper : AppColors.walnutSoft)),
      ),
    );
  }

  Widget _arrow(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.hairline, width: 1),
        ),
        child: Icon(icon,
            size: 20, color: enabled ? AppColors.coral : AppColors.walnutMuted),
      ),
    );
  }
}
