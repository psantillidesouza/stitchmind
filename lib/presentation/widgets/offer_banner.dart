import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'gradient_bg.dart';

/// Banner de oferta/premium reutilizável (home e perfil) — card pêssego com a
/// ilustração da raposinha de crochê (premium.png). O fundo do card usa a
/// MESMA cor do fundo da imagem, então a arte "encaixa" sem emenda.
///
/// Os textos têm padrão (strings da home de compra) mas podem ser sobrescritos
/// para reaproveitar o mesmo visual em outros lugares. [showCta] esconde o
/// botão (usado no estado "premium ativo", em que não há o que comprar).
class OfferBanner extends StatelessWidget {
  const OfferBanner({
    super.key,
    required this.onTap,
    this.title,
    this.subtitle,
    this.cta,
    this.badge,
    this.showCta = true,
  });

  final VoidCallback? onTap;
  final String? title;
  final String? subtitle;
  final String? cta;
  final String? badge;
  final bool showCta;

  // Cor do fundo da ilustração (premium.png) — base do card.
  static const _peach = Color(0xFFFFC69B);
  static const _peachLight = Color(0xFFFFD8B6);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: softShadow(0.12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Base pêssego (degradê sutil pra dar profundidade).
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_peachLight, _peach],
                    ),
                  ),
                ),
              ),
              // Ilustração à direita (fundo idêntico ao card → sem emenda).
              Positioned(
                right: -8,
                top: 0,
                bottom: 0,
                child: Image.asset(
                  'assets/illustrations/premium.png',
                  fit: BoxFit.fitHeight,
                  alignment: Alignment.centerRight,
                ),
              ),
              // Véu pêssego à esquerda → garante leitura do texto sobre a arte.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [_peachLight, Color(0x00FFD8B6)],
                      stops: [0.46, 0.74],
                    ),
                  ),
                ),
              ),
              // Conteúdo: texto à esquerda (em Expanded, com largura limitada)
              // + um gutter reservado pra ilustração não ser sobreposta.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tag PREMIUM coral.
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.coral,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: softShadow(0.12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.workspace_premium_rounded,
                                    size: 12, color: AppColors.paper),
                                const SizedBox(width: 4),
                                Text(
                                  badge ?? l10n.tr('home_offer_badge'),
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: AppColors.paper,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(title ?? l10n.tr('home_offer_title'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  color: AppColors.walnut)),
                          const SizedBox(height: 3),
                          Text(subtitle ?? l10n.tr('home_offer_subtitle'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12.5,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.walnutSoft)),
                          if (showCta) ...[
                            const SizedBox(height: 13),
                            // Botão CTA coral.
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 9),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  AppColors.coral,
                                  AppColors.coralDeep
                                ]),
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.coralDeep
                                        .withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cta ?? l10n.tr('home_offer_cta'),
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.paper,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 15, color: AppColors.paper),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Espaço reservado pra ilustração (raposinha) — evita
                    // que o texto fique por cima da arte.
                    const SizedBox(width: 128),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
