import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../providers/platform_providers.dart';
import 'stitch_mind_logo.dart';

/// Envolve uma funcionalidade premium. Se a pessoa for assinante, mostra o
/// conteúdo; senão, mostra um estado bloqueado elegante com CTA para o paywall.
/// Reativo: ao assinar e voltar, desbloqueia sozinho.
class PremiumGate extends ConsumerWidget {
  const PremiumGate({
    required this.child,
    required this.title,
    required this.subtitle,
    this.image = 'assets/illustrations/premium.png',
    super.key,
  });

  final Widget child;
  final String title;
  final String subtitle;
  final String image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionServiceProvider);
    return ListenableBuilder(
      listenable: sub,
      builder: (context, _) => sub.isSubscribed
          ? child
          : _Locked(title: title, subtitle: subtitle, image: image),
    );
  }
}

class _Locked extends StatelessWidget {
  const _Locked({
    required this.title,
    required this.subtitle,
    required this.image,
  });
  final String title, subtitle, image;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Image.asset(
            image,
            height: 180,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const StitchMindLogo(size: 88),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.coralSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 14, color: AppColors.coral),
                const SizedBox(width: 6),
                Text(context.l10n.tr('premium_chip_label'),
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.coral)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 10),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.walnutSoft, height: 1.5)),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => context.push('/paywall'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: Text(context.l10n.tr('premium_unlock_button')),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(context.l10n.tr('premium_cancel_anytime'),
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
