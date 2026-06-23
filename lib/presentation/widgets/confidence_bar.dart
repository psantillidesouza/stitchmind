import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Barra visual de confiança 0..1.
/// - 0.0–0.4: terracota (incerteza alta)
/// - 0.4–0.7: ocre (incerteza média)
/// - 0.7–1.0: sage (confiável)
class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({
    required this.value,
    this.label,
    this.height = 6,
    this.showPercent = true,
    super.key,
  });

  final double value;
  final String? label;
  final double height;
  final bool showPercent;

  Color get _color {
    if (value >= 0.7) return AppColors.sage;
    if (value >= 0.4) return AppColors.ochre;
    return AppColors.terracotta;
  }

  String get _labelText {
    if (value >= 0.7) return 'high confidence';
    if (value >= 0.4) return 'medium confidence';
    return 'low confidence';
  }

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (showPercent)
                Text(
                  '${(clamped * 100).round()}%',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Container(color: AppColors.linen),
                FractionallySizedBox(
                  widthFactor: clamped,
                  child: Container(color: _color),
                ),
              ],
            ),
          ),
        ),
        if (label == null && showPercent) ...[
          const SizedBox(height: 4),
          Text(
            '$_labelText · ${(clamped * 100).round()}%',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}
