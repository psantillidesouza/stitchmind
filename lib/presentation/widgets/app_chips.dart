import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'gradient_bg.dart';

/// Pílula de rótulo simples (sem ícone): uma tag pequena com fundo suave.
/// Usada para técnica / dificuldade / categoria nas telas de detalhe.
/// Canônico: fundo `linen @ 0.5`, texto 12 / w500 / walnut, raio de chip.
class AppPill extends StatelessWidget {
  const AppPill({required this.label, this.background, this.foreground, super.key});

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? AppColors.linen.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: foreground ?? AppColors.walnut,
        ),
      ),
    );
  }
}

/// Chip de meta com ícone (fundo `card` + sombra suave, ícone coral).
/// Usado nas telas de detalhe de aula (dificuldade, duração, nº de passos).
class AppMetaChip extends StatelessWidget {
  const AppMetaChip({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        boxShadow: softShadow(0.04),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.coral),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.walnut)),
      ]),
    );
  }
}
