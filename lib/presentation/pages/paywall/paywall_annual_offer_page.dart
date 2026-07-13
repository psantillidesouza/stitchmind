import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/lesson.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/platform_providers.dart';
import '../../widgets/stitch_mind_logo.dart';
import 'paywall_page.dart' show PaywallCelebration;

const _bg = AppColors.paywallBg;
const _card = AppColors.paywallCard;
const _cardLine = AppColors.paywallCardLine;

const _termsUrl = 'https://stitchmindapp.com/termos';
const _privacyUrl = 'https://stitchmindapp.com/privacidade';

/// Oferta de saída: plano ANUAL com 3 dias de teste grátis, mostrada quando o
/// usuário fecha o paywall principal (mensal/semanal) sem assinar.
///
/// Usa o offering `annual_trial` do RevenueCat (iOS: produto dedicado
/// `com.stitchmind.anualtrial`; Android: `com.stitchmind.anual` com a oferta
/// de trial selecionada explicitamente). Enquanto o produto não carrega (sem
/// rede / offering ausente), mostra os preços oficiais como fallback visual:
/// R$ 69,99/ano no Brasil e US$ 49.99/ano no resto do mundo.
class PaywallAnnualOfferPage extends ConsumerStatefulWidget {
  const PaywallAnnualOfferPage({this.source = 'paywall_close', super.key});

  /// Origem da exibição, para o analytics: `paywall_close` (X do paywall
  /// pós-onboarding) ou `periodic` (reexibição espontânea na abertura).
  final String source;

  @override
  ConsumerState<PaywallAnnualOfferPage> createState() =>
      _PaywallAnnualOfferPageState();
}

class _PaywallAnnualOfferPageState
    extends ConsumerState<PaywallAnnualOfferPage> {
  Package? _pkg;
  bool _busy = false;
  bool _celebrating = false;

  @override
  void initState() {
    super.initState();
    AppState.markAnnualOfferShown(); // inicia o cooldown de reexibição
    ref
        .read(analyticsServiceProvider)
        .logPaywallView(variant: 'annual_offer', source: widget.source);
    _load();
  }

  Future<void> _load() async {
    final pkg =
        await ref.read(subscriptionServiceProvider).annualTrialPackage();
    if (mounted && pkg != null) setState(() => _pkg = pkg);
  }

  String get _price =>
      _pkg?.storeProduct.priceString ??
      (context.l10n.isPt ? r'R$ 69,99' : r'US$ 49.99');

  String get _monthly {
    final p = _pkg?.storeProduct;
    if (p == null) return context.l10n.isPt ? r'R$ 5,83' : r'US$ 4.17';
    try {
      return NumberFormat.simpleCurrency(
        name: p.currencyCode,
        locale: Localizations.localeOf(context).toString(),
      ).format(p.price / 12);
    } catch (_) {
      return p.priceString;
    }
  }

  void _close() => context.canPop() ? context.pop() : context.go('/');

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _celebrate() async {
    if (!mounted) return;
    setState(() => _celebrating = true);
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) context.go('/');
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final ok = await ref.read(subscriptionServiceProvider).restore();
      if (!ok && mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.tr('pay_no_active_subscription')),
          behavior: SnackBarBehavior.floating,
        ));
      } else if (ok && mounted) {
        context.canPop() ? context.pop() : context.go('/');
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.tr('pay_restore_failed')),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startTrial() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final analytics = ref.read(analyticsServiceProvider);

    var pkg = _pkg;
    if (pkg == null) {
      await _load();
      pkg = _pkg;
    }
    if (pkg == null) {
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.tr('pay_plans_unavailable')),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _busy = true);
    final product = pkg.storeProduct;
    analytics.logPaywallPurchaseTap(product.identifier,
        variant: 'annual_offer');
    try {
      final ok =
          await ref.read(subscriptionServiceProvider).purchaseAnnualTrial(pkg);
      if (ok && mounted) {
        analytics.logPurchaseSuccess(product.identifier,
            value: product.price,
            currency: product.currencyCode,
            variant: 'annual_offer');
        await _celebrate();
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.tr('pay_purchase_failed')),
          backgroundColor: AppColors.coralDeep,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final topInset = MediaQuery.of(context).padding.top;

    final lessons = ref.watch(lessonsProvider).asData?.value ?? const <Lesson>[];
    final covers = [
      for (final l in lessons)
        if (l.coverUrl != null) l.coverUrl!,
    ];

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Collage(covers: covers),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          const _OfferBadge(),
                          const SizedBox(height: 10),
                          Text(
                            l10n.tr('pay_offer_headline'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 24,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.tr('pay_offer_subheadline',
                                {'price': _price, 'monthly': _monthly}),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.3,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                      _TrialTimeline(price: _price),
                      _AnnualPlanCard(price: _price),
                    ],
                  ),
                ),
              ),
              _bottomBar(context),
            ],
          ),
          Positioned(
            top: topInset + 8,
            right: 12,
            child: _CircleX(onTap: _close),
          ),
          if (_celebrating)
            const Positioned.fill(child: PaywallCelebration()),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _cardLine)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              l10n.tr('pay_renew_disclosure'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  color: Colors.white.withValues(alpha: 0.62)),
            ),
          ),
          _CtaButton(
              busy: _busy,
              label: l10n.tr('pay_offer_cta'),
              onTap: _busy ? null : _startTrial),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_rounded,
                  size: 14, color: AppColors.sage),
              const SizedBox(width: 5),
              Text(
                l10n.tr('pay_offer_no_charge'),
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FootLink(
                  label: l10n.tr('pay_terms'),
                  onTap: () => _openUrl(_termsUrl)),
              _dot(),
              _FootLink(
                  label: l10n.tr('pay_privacy'),
                  onTap: () => _openUrl(_privacyUrl)),
              _dot(),
              _FootLink(
                  label: l10n.tr('pay_restore_purchases'),
                  onTap: _busy ? null : _restore),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('·',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      );
}

// ─── Selo "OFERTA EXCLUSIVA" ────────────────────────────────────────
class _OfferBadge extends StatelessWidget {
  const _OfferBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [AppColors.ochre, AppColors.gold]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.card_giftcard_rounded,
              size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            context.l10n.tr('pay_offer_badge'),
            style: AppText.badge.copyWith(fontSize: 10, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ─── Linha do tempo do teste grátis (hoje / dia 2 / dia 3) ──────────
class _TrialTimeline extends StatelessWidget {
  const _TrialTimeline({required this.price});
  final String price;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = [
      (
        Icons.lock_open_rounded,
        l10n.tr('pay_offer_today_title'),
        l10n.tr('pay_offer_today_sub'),
        AppColors.coral,
      ),
      (
        Icons.notifications_active_rounded,
        l10n.tr('pay_offer_day2_title'),
        l10n.tr('pay_offer_day2_sub'),
        AppColors.gold,
      ),
      (
        Icons.star_rounded,
        l10n.tr('pay_offer_day3_title'),
        l10n.tr('pay_offer_day3_sub'),
        AppColors.sage,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: steps[i].$4.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: steps[i].$4.withValues(alpha: 0.55)),
                      ),
                      child: Icon(steps[i].$1, size: 17, color: steps[i].$4),
                    ),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        bottom: i < steps.length - 1 ? 14 : 0, top: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$2,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          steps[i].$3,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Cartão único do plano anual ────────────────────────────────────
class _AnnualPlanCard extends StatelessWidget {
  const _AnnualPlanCard({required this.price});
  final String price;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.coral, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.coral, size: 24),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.tr('pay_offer_plan_title'),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RibbonBadge(text: l10n.tr('pay_best_value')),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.tr('pay_offer_plan_sub', {'price': price}),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.event_available_rounded,
                        size: 14, color: AppColors.sage),
                    const SizedBox(width: 4),
                    Text(
                      l10n.tr('premium_cancel_anytime'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.sage,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RibbonBadge extends StatelessWidget {
  const _RibbonBadge({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [AppColors.ochre, AppColors.gold]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: AppText.badge.copyWith(fontSize: 9.5, color: Colors.white)),
    );
  }
}

// ─── Colagem de capas no topo (igual ao paywall principal) ──────────
class _Collage extends StatelessWidget {
  const _Collage({required this.covers});
  final List<String> covers;

  @override
  Widget build(BuildContext context) {
    const h = 172.0;
    final imgs = covers.take(9).toList();
    return SizedBox(
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imgs.isEmpty)
            Container(
              color: _card,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Image.asset('assets/illustrations/premium.png',
                    height: 130,
                    errorBuilder: (_, __, ___) =>
                        const StitchMindLogo(size: 72)),
              ),
            )
          else
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
              ),
              itemCount: imgs.length,
              itemBuilder: (_, i) => Image.network(
                imgs[i],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: _card),
              ),
            ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.45, 1.0],
                  colors: [
                    Color(0x550E0B0A),
                    Color(0x110E0B0A),
                    _bg,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── X redondo translúcido ──────────────────────────────────────────
class _CircleX extends StatelessWidget {
  const _CircleX({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.38),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.close_rounded, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

// ─── Link do rodapé ─────────────────────────────────────────────────
class _FootLink extends StatelessWidget {
  const _FootLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.55),
              decoration: TextDecoration.underline,
              decorationColor: Colors.white24)),
    );
  }
}

// ─── Botão CTA coral ────────────────────────────────────────────────
class _CtaButton extends StatelessWidget {
  const _CtaButton(
      {required this.label, required this.onTap, this.busy = false});
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.coral, AppColors.coralDeep]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.coral.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: busy
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white))
            : Text(label,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
      ),
    );
  }
}
