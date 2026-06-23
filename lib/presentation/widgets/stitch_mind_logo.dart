import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Marca visual do app: quadrado de cantos arredondados em terracota,
/// com uma "trama" de V's (ponto meia do tricô) em creme no interior.
/// Funciona em qualquer tamanho — usado no onboarding e empty states.
class StitchMindLogo extends StatelessWidget {
  const StitchMindLogo({
    this.size = 96,
    this.background = AppColors.terracotta,
    this.foreground = AppColors.cream,
    super.key,
  });

  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LogoPainter(
          background: background,
          foreground: foreground,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.background, required this.foreground});
  final Color background;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width * 0.22),
    );

    // Fundo
    canvas.drawRRect(rrect, Paint()..color = background);

    // Recorta o interior pra desenhar a trama dentro do raio.
    canvas.save();
    canvas.clipRRect(rrect);

    final stroke = Paint()
      ..color = foreground.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Trama central — três V's empilhados (símbolo do ponto meia).
    final cx = size.width / 2;
    final cy = size.height / 2;
    final vWidth = size.width * 0.34;
    final vHeight = size.height * 0.22;
    final spacing = size.height * 0.18;

    for (var i = -1; i <= 1; i++) {
      final yOffset = cy + i * spacing;
      final path = Path()
        ..moveTo(cx - vWidth / 2, yOffset - vHeight / 2)
        ..lineTo(cx, yOffset + vHeight / 2)
        ..lineTo(cx + vWidth / 2, yOffset - vHeight / 2);
      canvas.drawPath(path, stroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) =>
      old.background != background || old.foreground != foreground;
}
