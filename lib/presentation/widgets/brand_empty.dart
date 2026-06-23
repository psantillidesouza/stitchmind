import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Estado vazio on-brand: ilustração + título + texto opcional.
///
/// Usa `assets/illustrations/empty.png` (com fallback para um ícone caso o
/// asset ainda não tenha sido adicionado). Reutilizável em listas vazias
/// (favoritos, publicações, busca sem resultado, etc.).
class BrandEmpty extends StatelessWidget {
  const BrandEmpty({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/illustrations/empty.png',
              height: 180,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.inbox_rounded,
                size: 72,
                color: AppColors.walnutMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
