import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/entities/lesson.dart';
import '../../providers/platform_providers.dart';
import '../../providers/recent_lessons_provider.dart';
import '../../widgets/app_chips.dart';
import '../../widgets/cover_placeholder.dart';
import '../../widgets/gradient_bg.dart';
import '../../widgets/lesson_video.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/synced_video.dart';
import 'lesson_video_player.dart';

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
    // Vídeo da aula com capítulos = passos que têm tempo marcado.
    final hasLessonVideo =
        (l.lessonVideoUrl ?? '').isNotEmpty && steps.any((s) => s.stepTime != null);

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
                      style: AppText.eyebrow.copyWith(color: AppColors.coral)),
                const SizedBox(height: 6),
                Text(l.title, style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    AppMetaChip(icon: Icons.signal_cellular_alt_rounded, label: _difLabel(context, l.difficulty)),
                    AppMetaChip(icon: Icons.schedule_rounded, label: context.l10n.tr('lesson_chip_minutes', {'n': '${l.durationMin ?? 10}'})),
                    AppMetaChip(icon: Icons.format_list_numbered_rounded, label: context.l10n.tr('lesson_chip_steps', {'n': '${steps.length}'})),
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

        // ── Vídeo da aula: botão "Play full lesson" → player full-screen ──
        if (hasLessonVideo)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            sliver: SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LessonVideoPlayerPage(
                      url: l.lessonVideoUrl!,
                      posterUrl: l.lessonVideoPoster ?? l.coverUrl,
                      chapters: [
                        for (var i = 0; i < steps.length; i++)
                          if (steps[i].stepTime != null)
                            SyncedChapter(
                              title: steps[i].stepTitle.isNotEmpty
                                  ? steps[i].stepTitle
                                  : 'Step ${i + 1}',
                              timeSeconds: steps[i].stepTime ?? 0,
                            ),
                      ],
                    ),
                  ),
                ),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.coral.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 26),
                      SizedBox(width: 8),
                      Text(
                        'Play full lesson',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
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

// ─── Card de passo (foto + número + instrução) ──────────────────────
class _StepCard extends StatelessWidget {
  const _StepCard({required this.block, required this.index});
  final LessonBlock block;
  final int index;
  @override
  Widget build(BuildContext context) {
    final n = block.stepNumber > 0 ? block.stepNumber : index;
    final subs = block.stepSubsteps;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: softShadow(0.06),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topo: foto 16:9 do passo (o vídeo agora é por mini-passo).
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
                if (block.stepInstruction.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(block.stepInstruction,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
                ],
                if (block.stepTip.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _StepTip(text: block.stepTip),
                ],
                if (subs.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...subs.asMap().entries.map(
                        (e) => _Substep(
                          n: e.key + 1,
                          title: e.value.title,
                          description: e.value.description,
                          videoUrl: e.value.videoUrl,
                          videoPoster: e.value.videoPoster,
                        ),
                      ),
                ],
                if (block.stepTotal.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Total: ${block.stepTotal}',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.walnutMuted)),
                ],
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

// ─── Dica do passo (caixa 💡) ───────────────────────────────────────
class _StepTip extends StatelessWidget {
  const _StepTip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.peach.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.4, color: AppColors.walnut)),
          ),
        ],
      ),
    );
  }
}

// ─── Mini-passo: card com VÍDEO próprio + número + título + descrição ───
class _Substep extends StatelessWidget {
  const _Substep({
    required this.n,
    required this.title,
    required this.description,
    this.videoUrl = '',
    this.videoPoster,
  });
  final int n;
  final String title;
  final String description;
  final String videoUrl;
  final String? videoPoster;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.linen.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (videoUrl.isNotEmpty) ...[
            LessonVideo(url: videoUrl, posterUrl: videoPoster, borderRadius: 12),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppColors.peach, shape: BoxShape.circle),
                child: Text('$n',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.walnutSoft)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(title,
                          style: base?.copyWith(
                              height: 1.35, fontWeight: FontWeight.w700)),
                    if (description.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: title.isNotEmpty ? 2 : 0),
                        child: Text(description,
                            style: base?.copyWith(
                                height: 1.4, color: AppColors.walnutSoft)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
