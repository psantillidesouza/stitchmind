import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_state.dart';
import '../../../core/rating_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/entities/store_reviews.dart';
import '../../providers/platform_providers.dart';
import '../../widgets/gradient_bg.dart';
import '../../widgets/stitch_mind_logo.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  // 0 welcome · 1 nome · 2 técnica · 3 objetivos · 4 nível · 5 desafios ·
  // 6 projetos · 7 frequência · 8 notificações · 9 plano · 10 carregando ·
  // 11 avaliação → paywall
  int _step = 0;
  final _nameCtrl = TextEditingController();
  int? _craft;
  final Set<int> _goals = {};
  int? _skill;
  final Set<int> _challenges = {};
  final Set<int> _projects = {};
  int? _frequency;

  // Passos com barra de progresso: nome, técnica, objetivos, nível, desafios,
  // projetos e frequência (7).
  static const _totalQuestions = 7;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step++);

  Future<void> _saveNameAndNext() async {
    await AppState.setPreferredName(_nameCtrl.text);
    _next();
  }

  // Soft-ask de notificação: pede a permissão nativa só quando a pessoa opta
  // por "ativar" (best-effort; nunca trava o fluxo).
  Future<void> _enableNotifsAndNext() async {
    try {
      await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {}
    _next();
  }

  Future<void> _finish() async {
    await AppState.setPreferredName(_nameCtrl.text);
    await AppState.markOnboardingSeen();
    // Mostra a paywall logo após o onboarding (antes do login, como no design
    // original). Ao fechar/comprar, a paywall segue para '/' → /login.
    if (mounted) context.go('/paywall');
  }

  @override
  Widget build(BuildContext context) {
    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _buildStep(),
          ),
        ),
      ),
    );
  }

  void _back() => setState(() => _step--);

  Widget _buildStep() {
    final l = context.l10n;
    switch (_step) {
      case 0:
        return _Welcome(key: const ValueKey(0), onStart: _next);
      case 1:
        return _NameStep(
          key: const ValueKey('name'),
          controller: _nameCtrl,
          total: _totalQuestions,
          onContinue: _saveNameAndNext,
          onBack: _back,
        );
      case 2: // Técnica
        return _Question(
          key: const ValueKey(2),
          progress: 2,
          total: _totalQuestions,
          title: l.tr('onb_craft_title'),
          subtitle: l.tr('onb_craft_subtitle'),
          multi: false,
          selectedSingle: _craft,
          options: [
            _Opt(Icons.gesture_rounded, l.tr('onb_craft_crochet')),
            _Opt(Icons.waves_rounded, l.tr('onb_craft_knitting')),
            _Opt(Icons.all_inclusive_rounded, l.tr('onb_craft_both')),
          ],
          onSelectSingle: (i) => setState(() => _craft = i),
          canContinue: _craft != null,
          onContinue: _next,
          onBack: _back,
        );
      case 3: // Objetivos
        return _Question(
          key: const ValueKey(3),
          progress: 3,
          total: _totalQuestions,
          heroAsset: 'goals.png',
          title: l.tr('onb_goals_title'),
          subtitle: l.tr('onb_goals_subtitle'),
          multi: true,
          selected: _goals,
          options: [
            _Opt(Icons.school_rounded, l.tr('onb_goal_learn_stitches')),
            _Opt(Icons.format_list_numbered_rounded, l.tr('onb_goal_follow_patterns')),
            _Opt(Icons.healing_rounded, l.tr('onb_goal_fix_mistakes')),
            _Opt(Icons.lightbulb_outline_rounded, l.tr('onb_goal_find_inspiration')),
            _Opt(Icons.checkroom_rounded, l.tr('onb_goal_customize_projects')),
          ],
          onToggle: (i) => setState(() {
            _goals.contains(i) ? _goals.remove(i) : _goals.add(i);
          }),
          canContinue: _goals.isNotEmpty,
          onContinue: _next,
          onBack: _back,
        );
      case 4: // Nível
        return _Question(
          key: const ValueKey(4),
          progress: 4,
          total: _totalQuestions,
          heroAsset: 'skill.png',
          title: l.tr('onb_skill_title'),
          multi: false,
          selectedSingle: _skill,
          options: [
            _Opt(Icons.spa_rounded, l.tr('onb_skill_absolute_beginner_title'), l.tr('onb_skill_absolute_beginner_subtitle')),
            _Opt(Icons.auto_awesome_rounded, l.tr('onb_skill_beginner_title'), l.tr('onb_skill_beginner_subtitle')),
            _Opt(Icons.workspace_premium_rounded, l.tr('onb_skill_intermediate_title'), l.tr('onb_skill_intermediate_subtitle')),
            _Opt(Icons.military_tech_rounded, l.tr('onb_skill_advanced_title'), l.tr('onb_skill_advanced_subtitle')),
          ],
          onSelectSingle: (i) => setState(() => _skill = i),
          canContinue: _skill != null,
          onContinue: _next,
          onBack: _back,
        );
      case 5: // Desafios
        return _Question(
          key: const ValueKey(5),
          progress: 5,
          total: _totalQuestions,
          title: l.tr('onb_challenge_title'),
          subtitle: l.tr('onb_challenge_subtitle'),
          multi: true,
          selected: _challenges,
          options: [
            _Opt(Icons.tag_rounded, l.tr('onb_challenge_counting')),
            _Opt(Icons.menu_book_rounded, l.tr('onb_challenge_reading')),
            _Opt(Icons.straighten_rounded, l.tr('onb_challenge_tension')),
            _Opt(Icons.flag_rounded, l.tr('onb_challenge_finishing')),
            _Opt(Icons.healing_rounded, l.tr('onb_challenge_fixing')),
          ],
          onToggle: (i) => setState(() {
            _challenges.contains(i) ? _challenges.remove(i) : _challenges.add(i);
          }),
          canContinue: _challenges.isNotEmpty,
          onContinue: _next,
          onBack: _back,
        );
      case 6: // Projetos
        return _Question(
          key: const ValueKey(6),
          progress: 6,
          total: _totalQuestions,
          title: l.tr('onb_projects_title'),
          subtitle: l.tr('onb_projects_subtitle'),
          multi: true,
          selected: _projects,
          options: [
            _Opt(Icons.toys_rounded, l.tr('onb_project_amigurumi')),
            _Opt(Icons.checkroom_rounded, l.tr('onb_project_clothes')),
            _Opt(Icons.bed_rounded, l.tr('onb_project_blankets')),
            _Opt(Icons.shopping_bag_rounded, l.tr('onb_project_accessories')),
            _Opt(Icons.home_rounded, l.tr('onb_project_home')),
          ],
          onToggle: (i) => setState(() {
            _projects.contains(i) ? _projects.remove(i) : _projects.add(i);
          }),
          canContinue: _projects.isNotEmpty,
          onContinue: _next,
          onBack: _back,
        );
      case 7: // Frequência
        return _Question(
          key: const ValueKey(7),
          progress: 7,
          total: _totalQuestions,
          title: l.tr('onb_frequency_title'),
          subtitle: l.tr('onb_frequency_subtitle'),
          multi: false,
          selectedSingle: _frequency,
          options: [
            _Opt(Icons.local_fire_department_rounded, l.tr('onb_freq_daily')),
            _Opt(Icons.calendar_today_rounded, l.tr('onb_freq_weekly')),
            _Opt(Icons.weekend_rounded, l.tr('onb_freq_weekends')),
            _Opt(Icons.coffee_rounded, l.tr('onb_freq_casually')),
          ],
          onSelectSingle: (i) => setState(() => _frequency = i),
          canContinue: _frequency != null,
          onContinue: _next,
          onBack: _back,
        );
      case 8: // Notificações (soft-ask)
        return _NotificationAsk(
          key: const ValueKey(8),
          onEnable: _enableNotifsAndNext,
          onSkip: _next,
        );
      case 9: // Seu plano (payoff personalizado)
        return _Plan(
          key: const ValueKey(9),
          name: _nameCtrl.text.trim(),
          skill: _skill,
          goalsCount: _goals.length,
          frequency: _frequency,
          onContinue: _next,
        );
      case 10: // Carregando
        return _Loading(key: const ValueKey(10), onDone: _next);
      default: // 11 — Avaliação (prova social), último passo antes da paywall
        return _Social(key: const ValueKey(11), onContinue: _finish);
    }
  }
}

// ─── Welcome ────────────────────────────────────────────────────────
class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart, super.key});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      child: Column(
        children: [
          const Spacer(flex: 3),
          _OnbImage(
            'welcome.png',
            height: 240,
            fallback: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: elevatedShadow(0.18),
              ),
              child: const StitchMindLogo(size: 96),
            ),
          ),
          const SizedBox(height: 28),
          Text(context.l10n.tr('onb_welcome_title'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (_) => const Icon(Icons.star_rounded, color: AppColors.gold, size: 26)),
              const SizedBox(width: 8),
              Text('4.8', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleMedium,
              children: [
                const TextSpan(text: '#1 ', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w800)),
                TextSpan(text: context.l10n.tr('onb_welcome_rank_label')),
              ],
            ),
          ),
          const Spacer(flex: 4),
          _PillButton(label: context.l10n.tr('onb_start_button'), onTap: onStart, dark: true),
        ],
      ),
    );
  }
}

// ─── Nome (como quer ser chamada) ───────────────────────────────────
class _NameStep extends StatefulWidget {
  const _NameStep({
    required this.controller,
    required this.total,
    required this.onContinue,
    required this.onBack,
    super.key,
  });
  final TextEditingController controller;
  final int total;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final canContinue = widget.controller.text.trim().isNotEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),
              Expanded(
                child: Row(
                  children: List.generate(widget.total, (i) {
                    return Expanded(
                      child: Container(
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i < 1 ? AppColors.coral : AppColors.linen,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Center(child: _OnbImage('welcome.png', height: 88)),
              const SizedBox(height: 14),
              Text(context.l10n.tr('onb_name_question'),
                  style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 6),
              Text(context.l10n.tr('onb_name_subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              TextField(
                controller: widget.controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                maxLength: 30,
                onSubmitted: (_) {
                  if (canContinue) widget.onContinue();
                },
                style: Theme.of(context).textTheme.titleLarge,
                decoration: InputDecoration(
                  hintText: context.l10n.tr('onb_name_hint'),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.peachSoft.withValues(alpha: 0.9),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.coral, width: 2),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: _PillButton(
            label: context.l10n.tr('onb_continue_button'),
            dark: true,
            onTap: canContinue ? widget.onContinue : null,
          ),
        ),
      ],
    );
  }
}

// ─── Question (multi/single) ────────────────────────────────────────
class _Opt {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _Opt(this.icon, this.title, [this.subtitle]);
}

class _Question extends StatelessWidget {
  const _Question({
    required this.progress,
    required this.total,
    required this.title,
    required this.options,
    required this.canContinue,
    required this.onContinue,
    this.onBack,
    this.subtitle,
    this.heroAsset,
    this.multi = false,
    this.selected,
    this.selectedSingle,
    this.onToggle,
    this.onSelectSingle,
    super.key,
  });

  final int progress, total;
  final String title;
  final String? subtitle;
  final String? heroAsset;
  final List<_Opt> options;
  final bool multi;
  final Set<int>? selected;
  final int? selectedSingle;
  final void Function(int)? onToggle;
  final void Function(int)? onSelectSingle;
  final bool canContinue;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new, size: 18))
              else
                const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: List.generate(total, (i) {
                    return Expanded(
                      child: Container(
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i < progress ? AppColors.coral : AppColors.linen,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (heroAsset != null) ...[
                  Center(child: _OnbImage(heroAsset!, height: 66)),
                  const SizedBox(height: 8),
                ],
                Text(title, style: Theme.of(context).textTheme.displayMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 12),
                ...options.asMap().entries.map((e) {
                  final i = e.key, o = e.value;
                  final isSel =
                      multi ? selected!.contains(i) : selectedSingle == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _OptionCard(
                      opt: o,
                      selected: isSel,
                      onTap: () => multi ? onToggle!(i) : onSelectSingle!(i),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: _PillButton(
            label: context.l10n.tr('onb_continue_button'),
            dark: true,
            onTap: canContinue ? onContinue : null,
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.opt, required this.selected, required this.onTap});
  final _Opt opt;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.peachSoft.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.coral : Colors.transparent,
            width: 2,
          ),
          boxShadow: softShadow(0.04),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(opt.icon, color: AppColors.coral, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opt.title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: AppColors.ink,
                      )),
                  if (opt.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(opt.subtitle!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Social proof (avaliações REAIS das lojas) ──────────────────────
class _Social extends ConsumerStatefulWidget {
  const _Social({required this.onContinue, super.key});
  final VoidCallback onContinue;

  @override
  ConsumerState<_Social> createState() => _SocialState();
}

class _SocialState extends ConsumerState<_Social> {
  @override
  void initState() {
    super.initState();
    // Pede a avaliação nativa assim que ESTA tela aparece — o pop-up fica
    // sobre a prova social (não sobre a paywall). Após o 1º frame pra garantir
    // que a tela já está visível. Best-effort e uma única vez (RatingService).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RatingService.maybeRequest();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(reviewsProvider).valueOrNull ?? StoreReviews.empty;
    final review = data.reviews.isNotEmpty ? data.reviews.first : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Text(
            review != null
                ? context.l10n.tr('onb_social_title_with_review')
                : context.l10n.tr('onb_social_title_no_review'),
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 28),
          if (review != null)
            _ReviewCard(review: review)
          else
            _RatingCard(data: data),
          const Spacer(flex: 2),
          Text(
            data.count > 1
                ? context.l10n.tr('onb_social_caption_with_count')
                : context.l10n.tr('onb_social_caption_no_count'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.4),
          ),
          const Spacer(flex: 1),
          _PillButton(
              label: context.l10n.tr('onb_continue_button'),
              dark: true,
              onTap: widget.onContinue),
        ],
      ),
    );
  }
}

Widget _stars(int n, {double size = 20}) => Row(
      children: List.generate(
        5,
        (i) => Icon(
          i < n ? Icons.star_rounded : Icons.star_outline_rounded,
          color: AppColors.gold,
          size: size,
        ),
      ),
    );

String _storeLabel(String store) =>
    store == 'googleplay' ? 'Google Play' : 'App Store';

/// Card de um review real escrito (texto vindo das lojas).
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final StoreReview review;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: softShadow(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (review.title != null && review.title!.isNotEmpty)
                    Text(review.title!,
                        style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  _stars(review.rating),
                ],
              ),
              const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.peach,
                  child: Icon(Icons.person_rounded,
                      size: 24, color: AppColors.coral)),
            ],
          ),
          const SizedBox(height: 14),
          Text(review.text, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Text('${review.author} · ${_storeLabel(review.store)}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Card de nota agregada (quando ainda não há review escrita).
class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.data});
  final StoreReviews data;
  @override
  Widget build(BuildContext context) {
    final rating = data.hasRating ? data.rating : 5.0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: softShadow(0.06),
      ),
      child: Row(
        children: [
          Text(
            rating.toStringAsFixed(1).replaceAll('.', ','),
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(color: AppColors.coral),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stars(rating.round(), size: 22),
                const SizedBox(height: 8),
                Text(
                  data.count > 0
                      ? context.l10n.tr(
                          data.count == 1
                              ? 'onb_rating_count_singular'
                              : 'onb_rating_count_plural',
                          {'count': '${data.count}'},
                        )
                      : context.l10n.tr('onb_rating_stores'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Soft-ask de notificação ────────────────────────────────────────
class _NotificationAsk extends StatelessWidget {
  const _NotificationAsk({
    required this.onEnable,
    required this.onSkip,
    super.key,
  });
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.coral, AppColors.coralDeep],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: elevatedShadow(0.20),
              ),
              child: const Icon(Icons.notifications_active_rounded,
                  color: AppColors.paper, size: 46),
            ),
          ),
          const SizedBox(height: 26),
          Text(l.tr('onb_notif_title'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 12),
          Text(l.tr('onb_notif_subtitle'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(height: 1.4)),
          const SizedBox(height: 22),
          _NotifBullet(text: l.tr('onb_notif_bullet1')),
          _NotifBullet(text: l.tr('onb_notif_bullet2')),
          _NotifBullet(text: l.tr('onb_notif_bullet3')),
          const Spacer(flex: 3),
          _PillButton(
              label: l.tr('onb_notif_enable'), dark: true, onTap: onEnable),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: onSkip,
              child: Text(l.tr('onb_notif_skip'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.walnutMuted)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifBullet extends StatelessWidget {
  const _NotifBullet({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
                color: AppColors.coralSoft, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 16, color: AppColors.coral),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
        ],
      ),
    );
  }
}

// ─── Seu plano (payoff personalizado) ───────────────────────────────
class _Plan extends StatelessWidget {
  const _Plan({
    required this.name,
    required this.skill,
    required this.goalsCount,
    required this.frequency,
    required this.onContinue,
    super.key,
  });
  final String name;
  final int? skill;
  final int goalsCount;
  final int? frequency;
  final VoidCallback onContinue;

  static const _skillKeys = [
    'onb_skill_absolute_beginner_title',
    'onb_skill_beginner_title',
    'onb_skill_intermediate_title',
    'onb_skill_advanced_title',
  ];
  static const _freqKeys = [
    'onb_freq_daily',
    'onb_freq_weekly',
    'onb_freq_weekends',
    'onb_freq_casually',
  ];

  String _at(List<String> keys, int? i, AppLocalizations l) =>
      (i != null && i >= 0 && i < keys.length) ? l.tr(keys[i]) : '—';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = name.isNotEmpty
        ? l.tr('onb_plan_title', {'name': name})
        : l.tr('onb_plan_title_noname');

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.coral, AppColors.ochre]),
                shape: BoxShape.circle,
                boxShadow: elevatedShadow(0.18),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.paper, size: 40),
            ),
          ),
          const SizedBox(height: 22),
          Text(l.tr('onb_plan_eyebrow'),
              textAlign: TextAlign.center,
              style: AppText.eyebrow.copyWith(color: AppColors.coral)),
          const SizedBox(height: 8),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                boxShadow: softShadow(0.06)),
            child: Column(
              children: [
                _PlanRow(
                    icon: Icons.workspace_premium_rounded,
                    label: l.tr('onb_plan_level'),
                    value: _at(_skillKeys, skill, l)),
                _PlanRow(
                    icon: Icons.flag_rounded,
                    label: l.tr('onb_plan_focus'),
                    value: l.tr('onb_plan_focus_value', {'n': '$goalsCount'})),
                _PlanRow(
                    icon: Icons.local_fire_department_rounded,
                    label: l.tr('onb_plan_pace'),
                    value: _at(_freqKeys, frequency, l),
                    last: true),
              ],
            ),
          ),
          const Spacer(flex: 3),
          _PillButton(label: l.tr('onb_plan_cta'), dark: true, onTap: onContinue),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });
  final IconData icon;
  final String label, value;
  final bool last;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.coralSoft,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: AppColors.coral),
          ),
          const SizedBox(width: 14),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge),
          ),
        ],
      ),
    );
  }
}

// ─── Loading ────────────────────────────────────────────────────────
class _Loading extends StatefulWidget {
  const _Loading({required this.onDone, super.key});
  final VoidCallback onDone;
  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading> {
  double _p = 0;
  int _fact = 0;
  Timer? _t;
  static const _factCount = 3;
  // (ícone fallback, asset da ilustração, texto)
  List<(IconData, String, String)> _factsFor(BuildContext context) => [
    (Icons.style_rounded, 'fact_scarf.png', context.l10n.tr('onb_fact_longest_scarf')),
    (Icons.self_improvement_rounded, 'fact_zen.png', context.l10n.tr('onb_fact_knitting_stress')),
    (Icons.back_hand_rounded, 'fact_hook.png', context.l10n.tr('onb_fact_crochet_origin')),
  ];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 90), (t) {
      setState(() {
        _p += 0.012;
        _fact = ((_p * _factCount).floor()).clamp(0, _factCount - 1);
      });
      if (_p >= 1) {
        t.cancel();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _factsFor(context)[_fact];
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(context.l10n.tr('onb_did_you_know'), style: Theme.of(context).textTheme.headlineLarge),
          ),
          const Spacer(flex: 1),
          SizedBox(
            height: 168,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Image.asset(
                'assets/onboarding/${f.$2}',
                key: ValueKey(f.$2),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(f.$1, size: 72, color: AppColors.coral),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(f.$3, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.4)),
          const Spacer(flex: 2),
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 96, height: 96,
                  child: CircularProgressIndicator(
                    value: _p.clamp(0, 1),
                    strokeWidth: 7,
                    backgroundColor: AppColors.linen,
                    valueColor: const AlwaysStoppedAnimation(AppColors.coral),
                  ),
                ),
                Text('${(_p * 100).clamp(0, 100).toInt()}%',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(context.l10n.tr('onb_preparing'), style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

// ─── Imagem ilustrativa (com fallback gracioso) ─────────────────────
/// Mostra uma ilustração de assets/onboarding/. Se o arquivo ainda não foi
/// adicionado, cai no [fallback] (ou nada) — o app nunca quebra.
class _OnbImage extends StatelessWidget {
  const _OnbImage(this.name, {this.height, this.fallback});
  final String name;
  final double? height;
  final Widget? fallback;
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/onboarding/$name',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback ?? const SizedBox.shrink(),
    );
  }
}

// ─── Botão pílula ───────────────────────────────────────────────────
class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap, this.dark = false});
  final String label;
  final VoidCallback? onTap;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: dark
            ? (enabled ? AppColors.ink : AppColors.ink.withValues(alpha: 0.35))
            : AppColors.coral,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(label,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.paper)),
            ),
          ),
        ),
      ),
    );
  }
}
