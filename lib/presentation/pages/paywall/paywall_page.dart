import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/lesson.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/platform_providers.dart';
import '../../widgets/stitch_mind_logo.dart';
import 'paywall_b_page.dart';

const _bg = AppColors.paywallBg; // fundo escuro da paywall
const _card = AppColors.paywallCard;
const _cardLine = AppColors.paywallCardLine;

const _termsUrl = 'https://stitchmindapp.com/termos';
const _privacyUrl = 'https://stitchmindapp.com/privacidade';

/// Paywall premium — estilo dark com colagem de projetos. Exibida após o
/// onboarding e a cada abertura do app enquanto o usuário não for assinante.
/// Porta de entrada do paywall: resolve a variante A/B (sorteio 50/50 fixo por
/// instalação — ver [AppState.currentPaywallVariant]) e mostra a tela certa.
/// TODOS os CTAs de premium apontam para a rota `/paywall`, que renderiza isto.
class PaywallGate extends StatelessWidget {
  const PaywallGate({super.key});

  @override
  Widget build(BuildContext context) {
    final variant = AppState.currentPaywallVariant();
    return variant == 'b'
        ? const PaywallProPage(variant: 'b')
        : const PaywallPage(variant: 'a');
  }
}

class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({this.variant = 'a', super.key});

  /// Variante A/B em exibição — apenas para rotulagem no analytics
  /// (`paywall_variant`). O layout desta classe é a variante A.
  final String variant;

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  List<StoreProduct> _products = const [];
  bool _loading = true;
  bool _busy = false;
  bool _celebrating = false;
  bool _remindMe = true;
  String? _selectedId;

  /// Este é o paywall pós-onboarding (1ª vez)? Se sim, o X leva à oferta de
  /// saída (anual + 3 dias grátis) em vez de fechar. Consumido no initState —
  /// paywalls futuros nunca mais disparam a oferta.
  bool _offerOnClose = false;

  List<String> _benefits(BuildContext c) => [
        c.l10n.tr('pay_benefit_lessons_no_ads'),
        c.l10n.tr('pay_benefit_unlimited_photo_chat'),
        c.l10n.tr('pay_benefit_save_track_projects'),
        c.l10n.tr('premium_cancel_anytime'),
      ];

  @override
  void initState() {
    super.initState();
    AppState.paywallShownThisLaunch = true;
    _offerOnClose = AppState.consumeAnnualOfferPending();
    ref.read(analyticsServiceProvider).logPaywallView(variant: widget.variant);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final products = await ref.read(subscriptionServiceProvider).products();
    if (!mounted) return;
    products.sort((a, b) =>
        (_isAnnual(a) ? 1 : 0).compareTo(_isAnnual(b) ? 1 : 0));
    StoreProduct? pick;
    for (final p in products) {
      if (_isAnnual(p)) {
        pick = p;
        break;
      }
    }
    pick ??= products.isNotEmpty ? products.first : null;
    setState(() {
      _products = products;
      _selectedId = pick?.identifier;
      _loading = false;
    });
  }

  static bool _isAnnual(StoreProduct p) {
    final id = p.identifier.toLowerCase();
    return id.contains('anual') || id.contains('annual') || id.contains('year');
  }

  static bool _isWeekly(StoreProduct p) {
    final id = p.identifier.toLowerCase();
    return id.contains('week') || id.contains('semanal');
  }

  StoreProduct? _selectedProduct() {
    for (final p in _products) {
      if (p.identifier == _selectedId) return p;
    }
    return null;
  }

  double? _weeklyRef() {
    for (final p in _products) {
      if (_isWeekly(p)) return p.price;
    }
    return null;
  }

  /// Dias de teste grátis do produto selecionado (null se não houver).
  int? _trialDays(StoreProduct? p) {
    final intro = p?.introductoryPrice;
    if (intro == null || intro.price > 0) return null;
    final n = intro.periodNumberOfUnits;
    switch (intro.periodUnit) {
      case PeriodUnit.week:
        return n * 7;
      case PeriodUnit.month:
        return n * 30;
      case PeriodUnit.year:
        return n * 365;
      default:
        return n;
    }
  }

  void _close() {
    // Oferta de saída: SÓ no paywall pós-onboarding (1ª vez), quem fecha sem
    // assinar vê o plano anual com 3 dias de teste grátis.
    if (_offerOnClose) {
      context.pushReplacement('/paywall-annual');
      return;
    }
    context.canPop() ? context.pop() : context.go('/');
  }

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

  Future<void> _buy() async {
    final pkg = _selectedProduct();
    if (pkg == null || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final analytics = ref.read(analyticsServiceProvider);
    analytics.logPaywallPurchaseTap(pkg.identifier, variant: widget.variant);
    try {
      final ok = await ref.read(subscriptionServiceProvider).purchase(pkg);
      if (ok && mounted) {
        analytics.logPurchaseSuccess(pkg.identifier,
            value: pkg.price, currency: pkg.currencyCode, variant: widget.variant);
        await _celebrate();
      }
    } catch (_) {
      if (kDebugMode && mounted) {
        await _celebrate();
      } else if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final pkgs = _products;
    final weeklyRef = _weeklyRef();
    final selected = _selectedProduct();
    final trial = _trialDays(selected);
    final topInset = MediaQuery.of(context).padding.top;

    // Colagem com as capas reais das aulas (cai para a ilustração se vazio).
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
              // Conteúdo FIXO (sem scroll) — distribuído no espaço disponível.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        context.l10n.tr('pay_headline'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const _StarsRow(),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _benefits(context)
                            .map((t) => _BenefitRow(text: t))
                            .toList(),
                      ),
                      if (_loading)
                        const CircularProgressIndicator(color: AppColors.coral)
                      else if (pkgs.isEmpty)
                        _unavailable()
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: pkgs
                              .map((p) => _PlanCard(
                                    product: p,
                                    annual: _isAnnual(p),
                                    weekly: _isWeekly(p),
                                    selected: p.identifier == _selectedId,
                                    weeklyRef: weeklyRef,
                                    trialDays: _trialDays(p),
                                    onTap: () => setState(
                                        () => _selectedId = p.identifier),
                                  ))
                              .toList(),
                        ),
                      // Só faz sentido quando o plano selecionado tem teste
                      // grátis — sem trial não há "fim do teste" pra lembrar.
                      if (trial != null)
                        _ReminderToggle(
                          value: _remindMe,
                          onChanged: (v) => setState(() => _remindMe = v),
                        ),
                    ],
                  ),
                ),
              ),
              _bottomBar(context, pkgs, selected, trial),
            ],
          ),
          // X sobre a colagem
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

  Widget _bottomBar(BuildContext context, List<StoreProduct> pkgs,
      StoreProduct? selected, int? trial) {
    final l10n = context.l10n;
    final priceLine = trial != null && selected != null
        ? l10n.tr('pay_trial_then', {'n': '$trial', 'price': selected.priceString})
        : l10n.tr('pay_renew_disclosure');
    final ctaLabel =
        trial != null ? l10n.tr('pay_start_trial') : l10n.tr('pay_continue');

    return Container(
      padding: EdgeInsets.fromLTRB(
          22, 10, 22, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _cardLine)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pkgs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                priceLine,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.62)),
              ),
            ),
          _CtaButton(
            busy: _busy,
            label: ctaLabel,
            onTap: (_busy || _selectedId == null || pkgs.isEmpty) ? null : _buy,
          ),
          const SizedBox(height: 8),
          // Links obrigatórios (App Store) + restaurar.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FootLink(label: l10n.tr('pay_terms'), onTap: () => _openUrl(_termsUrl)),
              _dot(),
              _FootLink(label: l10n.tr('pay_privacy'), onTap: () => _openUrl(_privacyUrl)),
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
        child: Text('·', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
      );

  Widget _unavailable() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardLine),
        ),
        child: Column(
          children: [
            Text(context.l10n.tr('pay_plans_unavailable'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextButton(
                onPressed: _load,
                child: Text(context.l10n.tr('pay_try_again'),
                    style: const TextStyle(color: AppColors.coral))),
          ],
        ),
      );
}

// ─── Colagem de projetos (capas das aulas) ──────────────────────────
class _Collage extends StatelessWidget {
  const _Collage({required this.covers});
  final List<String> covers;

  @override
  Widget build(BuildContext context) {
    const h = 196.0;
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
                padding: const EdgeInsets.only(bottom: 40),
                child: Image.asset('assets/illustrations/premium.png',
                    height: 150,
                    errorBuilder: (_, __, ___) =>
                        const StitchMindLogo(size: 80)),
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
          // Fade para o fundo escuro na base (e leve no topo).
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

// ─── Estrelas + nota ────────────────────────────────────────────────
class _StarsRow extends StatelessWidget {
  const _StarsRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(
            5,
            (_) => const Icon(Icons.star_rounded,
                color: AppColors.gold, size: 19)),
        const SizedBox(width: 8),
        const Text('4.8',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 14)),
      ],
    );
  }
}

// ─── Linha de benefício (check coral + texto branco) ────────────────
class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 21,
            height: 21,
            decoration: const BoxDecoration(
                color: AppColors.coral, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 14, height: 1.25, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Cartão de plano (dark) ─────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.annual,
    required this.weekly,
    required this.selected,
    required this.weeklyRef,
    required this.trialDays,
    required this.onTap,
  });
  final StoreProduct product;
  final bool annual;
  final bool weekly;
  final bool selected;
  final double? weeklyRef;
  final int? trialDays;
  final VoidCallback onTap;

  String _title(BuildContext c) {
    if (trialDays != null) return c.l10n.tr('pay_trial_days', {'n': '$trialDays'});
    if (annual) return c.l10n.tr('pay_plan_annual');
    if (weekly) return c.l10n.tr('pay_plan_weekly');
    final id = product.identifier.toLowerCase();
    if (id.contains('mensal') || id.contains('month')) {
      return c.l10n.tr('pay_plan_monthly');
    }
    return product.title;
  }

  String _sub(BuildContext c) {
    if (trialDays != null) {
      final period = annual
          ? c.l10n.tr('pay_plan_annual')
          : weekly
              ? c.l10n.tr('pay_plan_weekly')
              : c.l10n.tr('pay_plan_monthly');
      return '$period · ${product.priceString}';
    }
    return product.priceString;
  }

  int? _savings() {
    if (!annual || weeklyRef == null || weeklyRef! <= 0) return null;
    final yearCost = weeklyRef! * 52;
    if (product.price <= 0 || product.price >= yearCost) return null;
    return ((1 - product.price / yearCost) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final savings = _savings();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.coral.withValues(alpha: 0.16)
                : _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.coral : _cardLine,
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected ? AppColors.coral : Colors.white24,
                size: 24,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _title(context),
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                        if (annual && trialDays == null) ...[
                          const SizedBox(width: 8),
                          _RibbonBadge(text: context.l10n.tr('pay_best_value')),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _sub(context),
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (savings != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('-$savings%',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.sage)),
                ),
            ],
          ),
        ),
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
        gradient: const LinearGradient(colors: [AppColors.ochre, AppColors.gold]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: AppText.badge.copyWith(fontSize: 9.5, color: Colors.white)),
    );
  }
}

// ─── Toggle "lembre-me antes do fim do teste" ───────────────────────
class _ReminderToggle extends StatelessWidget {
  const _ReminderToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _cardLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(context.l10n.tr('pay_reminder'),
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.coral,
            inactiveTrackColor: Colors.white12,
          ),
        ],
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
  const _CtaButton({
    required this.label,
    required this.onTap,
    required this.busy,
  });
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
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
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
        ),
      ),
    );
  }
}

// ─── Overlay de celebração: confetes + selo "Premium" ───────────────
// Público: usado também pela oferta de saída (paywall_annual_offer_page.dart).
class PaywallCelebration extends StatelessWidget {
  const PaywallCelebration({super.key});
  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(child: _ConfettiOverlay()),
          Center(child: _PremiumUnlockedBadge()),
        ],
      ),
    );
  }
}

class _PremiumUnlockedBadge extends StatelessWidget {
  const _PremiumUnlockedBadge();
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 750),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(
        scale: (0.4 + 0.6 * v).clamp(0.0, 1.12),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [AppColors.ochre, AppColors.gold]),
              boxShadow: [
                BoxShadow(
                  color: AppColors.coralDeep.withValues(alpha: 0.45),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, size: 54, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.tr('pay_brand_premium'),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay();
  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;
  final _rnd = Random();

  static const _colors = [
    AppColors.coral,
    AppColors.coralDeep,
    AppColors.gold,
    AppColors.ochre,
    AppColors.sage,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..forward();
    _particles = _spawn();
  }

  List<_Particle> _spawn() {
    final list = <_Particle>[];
    for (final fromLeft in [true, false]) {
      for (var i = 0; i < 70; i++) {
        final vx = (fromLeft ? 1 : -1) * (0.25 + _rnd.nextDouble() * 0.85);
        final vy = -(1.0 + _rnd.nextDouble() * 0.8);
        list.add(_Particle(
          origin: Offset(fromLeft ? 0.06 : 0.94, 1.08),
          vx: vx,
          vy: vy,
          color: _colors[_rnd.nextInt(_colors.length)],
          size: 6 + _rnd.nextDouble() * 8,
          rot: _rnd.nextDouble() * pi * 2,
          rotSpeed: (_rnd.nextDouble() - 0.5) * 14,
          rect: _rnd.nextBool(),
        ));
      }
    }
    return list;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_particles, _c.value),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.origin,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rot,
    required this.rotSpeed,
    required this.rect,
  });
  final Offset origin;
  final double vx, vy;
  final Color color;
  final double size;
  final double rot, rotSpeed;
  final bool rect;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 2.2;
    final fade = t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
    for (final p in particles) {
      final dx = p.origin.dx + p.vx * t;
      final dy = p.origin.dy + p.vy * t + 0.5 * gravity * t * t;
      final pos = Offset(dx * size.width, dy * size.height);
      if (pos.dy > size.height + 40 || pos.dy < -40) continue;
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rot + p.rotSpeed * t);
      if (p.rect) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.55),
            const Radius.circular(1.5),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
