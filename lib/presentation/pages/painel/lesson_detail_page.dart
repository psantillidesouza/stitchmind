import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/entities/lesson.dart';
import '../../providers/platform_providers.dart';
import '../../providers/recent_lessons_provider.dart';
import '../../widgets/cover_placeholder.dart';
import '../../widgets/gradient_bg.dart';
import '../../widgets/premium_gate.dart';

class LessonDetailPage extends ConsumerStatefulWidget {
  const LessonDetailPage({required this.slug, super.key});
  final String slug;

  @override
  ConsumerState<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends ConsumerState<LessonDetailPage> {
  @override
  void initState() {
    super.initState();
    // Registra a abertura pra alimentar o carrossel "aberturas recentes".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentLessonsProvider.notifier).record(widget.slug);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lessonDetailProvider(widget.slug));

    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: async.when(
          loading: () => const _StateScaffold(
            child: Center(
                child: CircularProgressIndicator(color: AppColors.coral)),
          ),
          error: (e, _) => _StateScaffold(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppColors.coral),
                    const SizedBox(height: 16),
                    Text(context.l10n.tr('lesson_open_error'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('$e',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => context.pop(),
                      child: Text(context.l10n.tr('lesson_back')),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (detail) => _GatedLesson(detail: detail),
        ),
      ),
    );
  }
}

/// Aulas marcadas como premium só mostram o conteúdo para assinantes. Para os
/// demais, exibe o estado bloqueado (selo + cadeado + CTA da paywall) com botão
/// de voltar. Reativo: ao assinar e voltar, desbloqueia sozinho.
class _GatedLesson extends ConsumerWidget {
  const _GatedLesson({required this.detail});
  final LessonDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!detail.lesson.isPremium) return _LessonBody(detail: detail);
    final sub = ref.watch(subscriptionServiceProvider);
    return ListenableBuilder(
      listenable: sub,
      builder: (context, _) => sub.isSubscribed
          ? _LessonBody(detail: detail)
          : _StateScaffold(
              child: PremiumGate(
                title: detail.lesson.title,
                subtitle: context.l10n.tr('premium_lesson_locked_sub'),
                child: const SizedBox.shrink(),
              ),
            ),
    );
  }
}

/// Envolve os estados de carregando/erro com um botão de voltar fixo,
/// para o usuário nunca ficar preso sem navegação.
class _StateScaffold extends StatelessWidget {
  const _StateScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            top: 8,
            left: 16,
            child: _RoundBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonBody extends ConsumerStatefulWidget {
  const _LessonBody({required this.detail});
  final LessonDetail detail;
  @override
  ConsumerState<_LessonBody> createState() => _LessonBodyState();
}

class _LessonBodyState extends ConsumerState<_LessonBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lessonRepositoryProvider).saveProgress(
            widget.detail.lesson.id,
            status: 'in_progress',
          );
      ref.read(analyticsServiceProvider).logLessonOpen(
            widget.detail.lesson.slug,
            premium: widget.detail.lesson.isPremium,
          );
    });
  }

  void _markCompleted() {
    ref.read(lessonRepositoryProvider).saveProgress(
          widget.detail.lesson.id,
          status: 'completed',
          progressPct: 100,
        );
    ref.invalidate(lessonsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tr('lesson_completed_snack'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.detail.lesson;
    final steps = widget.detail.blocks.where((b) => b.type == 'step').toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final otherBlocks = widget.detail.blocks.where((b) => b.type != 'step').toList();

    return CustomScrollView(
      slivers: [
        // ── Capa ──
        SliverToBoxAdapter(child: _Cover(lesson: l)),

        // ── Título + chips ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (l.courseTitle != null)
                  Text(l.courseTitle!.toUpperCase(),
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 11, letterSpacing: 1.2,
                          fontWeight: FontWeight.w700, color: AppColors.coral)),
                const SizedBox(height: 6),
                Text(l.title, style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Chip(icon: Icons.signal_cellular_alt_rounded, label: _difLabel(context, l.difficulty)),
                    _Chip(icon: Icons.schedule_rounded, label: context.l10n.tr('lesson_chip_minutes', {'n': '${l.durationMin ?? 10}'})),
                    _Chip(icon: Icons.format_list_numbered_rounded, label: context.l10n.tr('lesson_chip_steps', {'n': '${steps.length}'})),
                  ],
                ),
                if (l.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(l.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
                ],
                const SizedBox(height: 24),
                Text(context.l10n.tr('lesson_step_by_step'), style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),

        // ── Passos ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          sliver: SliverList.separated(
            itemCount: steps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, i) => _StepCard(block: steps[i], index: i + 1),
          ),
        ),

        // blocos de texto soltos (se houver)
        if (otherBlocks.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            sliver: SliverList.separated(
              itemCount: otherBlocks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => Text(otherBlocks[i].text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
            ),
          ),

        // ── Botão concluir ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _markCompleted,
                icon: const Icon(Icons.check_rounded),
                label: Text(context.l10n.tr('lesson_mark_completed')),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _difLabel(BuildContext context, String? d) {
    switch (d) {
      case 'intermediate':
        return context.l10n.tr('lesson_difficulty_intermediate');
      case 'advanced':
        return context.l10n.tr('lesson_difficulty_advanced');
      default:
        return context.l10n.tr('lesson_difficulty_beginner');
    }
  }
}

// ─── Capa ───────────────────────────────────────────────────────────
class _Cover extends StatelessWidget {
  const _Cover({required this.lesson});
  final Lesson lesson;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 248,
          width: double.infinity,
          child: lesson.coverUrl != null
              ? Image.network(lesson.coverUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const CoverPlaceholder(iconSize: 56))
              : const CoverPlaceholder(iconSize: 56),
        ),
        // Scrim de topo p/ legibilidade do botão voltar sobre fotos claras.
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.28), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          child: _RoundBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => context.pop(),
          ),
        ),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 18, color: AppColors.walnut),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: softShadow(0.04),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.coral),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.walnut)),
      ]),
    );
  }
}

// ─── Card de passo (foto + número + instrução) ──────────────────────
class _StepCard extends StatelessWidget {
  const _StepCard({required this.block, required this.index});
  final LessonBlock block;
  final int index;
  @override
  Widget build(BuildContext context) {
    final n = block.stepNumber > 0 ? block.stepNumber : index;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: softShadow(0.06),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto do passo (horizontal 16:9)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: block.stepImageUrl != null
                ? Image.network(block.stepImageUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imgPh())
                : _imgPh(),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30, height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: AppColors.coral, shape: BoxShape.circle),
                      child: Text('$n',
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 14,
                              fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        block.stepTitle.isNotEmpty ? block.stepTitle : 'Passo $n',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(block.stepInstruction,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPh() => Container(
        color: AppColors.peach,
        child: const Center(
            child: Icon(Icons.image_outlined, size: 40, color: AppColors.walnutMuted)),
      );
}
