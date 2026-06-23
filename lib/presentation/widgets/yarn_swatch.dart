import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/entities.dart';

/// Placeholder visual de "novelo" / amostra de tecido por projeto.
/// Sem imagens — usa gradiente diagonal + listras finas que sugerem trama.
class YarnSwatch extends StatelessWidget {
  const YarnSwatch({
    required this.seed,
    required this.technique,
    this.size = 64,
    super.key,
  });

  final String seed;
  final StitchTechnique technique;
  final double size;

  static const _palettes = [
    [AppColors.terracotta, Color(0xFFE89A6F)],
    [AppColors.sage, Color(0xFFB6CCA1)],
    [AppColors.ochre, Color(0xFFEFCB89)],
    [Color(0xFF6B5544), Color(0xFFA38570)],
    [Color(0xFF8C5A3C), Color(0xFFD09B72)],
    [Color(0xFF445E3A), Color(0xFF8FA577)],
  ];

  List<Color> get _colors {
    final i = seed.codeUnits.fold<int>(0, (a, b) => a + b) % _palettes.length;
    return _palettes[i];
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _colors,
          ),
        ),
        child: CustomPaint(painter: _WeavePainter(technique: technique)),
      ),
    );
  }
}

class _WeavePainter extends CustomPainter {
  _WeavePainter({required this.technique});
  final StitchTechnique technique;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final step = technique == StitchTechnique.knit ? 6.0 : 8.0;
    for (var y = 0.0; y < size.height; y += step) {
      final path = Path();
      if (technique == StitchTechnique.knit) {
        path.moveTo(0, y);
        for (var x = 0.0; x < size.width; x += 4) {
          path.lineTo(x + 2, y - 2);
          path.lineTo(x + 4, y);
        }
      } else {
        path.moveTo(0, y);
        path.lineTo(size.width, y + 1);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeavePainter old) =>
      old.technique != technique;
}
