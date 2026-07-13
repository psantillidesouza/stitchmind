import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_state.dart';
import '../core/feature_flags.dart';
import '../core/rating_service.dart';
import '../core/theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'providers/platform_providers.dart';
import 'widgets/gradient_bg.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  // A aba Comunidade só entra quando a feature flag está ligada (ver
  // core/feature_flags.dart). Desligada = comunidade indisponível no menu.
  static final List<_Tab> _tabs = [
    const _Tab('/', 'nav_tab_home', Icons.home_rounded),
    const _Tab('/aulas', 'nav_tab_tools', Icons.auto_awesome_rounded),
    if (kCommunityEnabled)
      const _Tab('/community', 'nav_tab_community', Icons.groups_rounded),
    const _Tab('/perfil', 'nav_tab_profile', Icons.person_rounded),
  ];

  Timer? _ratingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPaywall());
    // Avaliação nativa: só depois de ~5 min de sessão (e as demais regras —
    // pós-onboarding, 1x/dia — ficam no RatingService/AppState).
    _ratingTimer = Timer(RatingService.sessionDelay, RatingService.maybeRequest);
  }

  @override
  void dispose() {
    _ratingTimer?.cancel();
    super.dispose();
  }

  /// Mostra a paywall a cada abertura do app enquanto o usuário não for
  /// premium — uma vez por launch (o X dispensa até a próxima abertura).
  void _maybeShowPaywall() {
    if (!mounted || AppState.paywallShownThisLaunch) return;
    final sub = ref.read(subscriptionServiceProvider);
    // Espera a assinatura ficar pronta (RevenueCat + servidor) para não
    // mostrar a paywall para quem, na verdade, já é assinante.
    if (!sub.ready) {
      void onReady() {
        if (sub.ready) {
          sub.removeListener(onReady);
          _maybeShowPaywall();
        }
      }
      sub.addListener(onReady);
      return;
    }
    if (sub.isReallyPremium) return;
    AppState.paywallShownThisLaunch = true;
    // De vez em quando (cooldown de 2 dias + sorteio 50/50), a abertura mostra
    // a oferta anual com 3 dias grátis no lugar do paywall padrão — só para
    // quem não tem NENHUM plano ativo (isReallyPremium já filtrou acima).
    final showAnnualOffer =
        AppState.annualOfferCooldownOver() && Random().nextBool();
    if (mounted) {
      context.push(
          showAnnualOffer ? '/paywall-annual?src=periodic' : '/paywall');
    }
  }

  int _indexFor(String location) {
    for (var i = _tabs.length - 1; i >= 0; i--) {
      if (location.startsWith(_tabs[i].path) &&
          (_tabs[i].path != '/' || location == '/')) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);

    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: widget.child,
        bottomNavigationBar: _FloatingNav(
          tabs: _tabs,
          index: index,
          onTap: (i) => context.go(_tabs[i].path),
        ),
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.tabs, required this.index, required this.onTap});
  final List<_Tab> tabs;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: AppColors.linen.withValues(alpha: 0.6)),
            boxShadow: elevatedShadow(0.14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: tabs.asMap().entries.map((e) {
              final i = e.key, t = e.value;
              final active = i == index;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AppColors.coral.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon,
                            size: 24,
                            color: active ? AppColors.coral : AppColors.walnutMuted),
                        const SizedBox(height: 3),
                        Text(context.l10n.tr(t.label),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active ? AppColors.coral : AppColors.walnutMuted,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final String path;
  final String label;
  final IconData icon;
  const _Tab(this.path, this.label, this.icon);
}
