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
import '../../widgets/lesson_video.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/synced_video.dart';
import '../ferramentas/chat_page.dart';
import 'lesson_video_player.dart';
import 'lesson_videos_page.dart';

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

  void _openFeedbackSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LessonFeedbackSheet(lesson: widget.detail.lesson),
    );
  }

  void _openGuide() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LessonGuidePage(
          detail: widget.detail,
          onMarkCompleted: _markCompleted,
        ),
      ),
    );
  }

  void _openVideo(List<LessonBlock> steps) {
    final l = widget.detail.lesson;
    // Vídeos da aula (blocos type=video do painel), na ordem definida lá.
    final videos = widget.detail.blocks
        .where((b) => b.type == 'video' && (b.url ?? '').isNotEmpty)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    if (videos.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonVideosPage(
            lessonTitle: l.title,
            videos: videos,
          ),
        ),
      );
      return;
    }

    // Legado: aula sem blocos de vídeo, mas com o vídeo único (meta).
    if ((l.lessonVideoUrl ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tr('lesson_no_video_snack'))),
      );
      return;
    }
    Navigator.of(context).push(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.detail.lesson;
    final steps = widget.detail.blocks.where((b) => b.type == 'step').toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return Stack(
      children: [
        Positioned.fill(
          child: CustomScrollView(
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
                            style: AppText.eyebrow
                                .copyWith(color: AppColors.coral)),
                      const SizedBox(height: 6),
                      Text(l.title,
                          style: Theme.of(context).textTheme.displayMedium),
                      // Dificuldade e tempo estimado lado a lado — cada card
                      // só aparece se o dado estiver preenchido no painel.
                      if (l.difficulty != null || l.durationMin != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (l.difficulty != null)
                              Expanded(
                                child: _InfoCard(
                                  icon: Icons.signal_cellular_alt_rounded,
                                  label:
                                      context.l10n.tr('lesson_card_difficulty'),
                                  value: _difLabel(context, l.difficulty),
                                ),
                              ),
                            if (l.difficulty != null && l.durationMin != null)
                              const SizedBox(width: 12),
                            if (l.durationMin != null)
                              Expanded(
                                child: _InfoCard(
                                  icon: Icons.schedule_rounded,
                                  label: context.l10n.tr('lesson_card_time'),
                                  value: context.l10n.tr('lesson_chip_minutes',
                                      {'n': '${l.durationMin}'}),
                                ),
                              ),
                          ],
                        ),
                      ],
                      // Título da ficha de preparação + menu (⋯) de feedback.
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(context.l10n.tr('lesson_prep_title'),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium),
                          ),
                          // Grudado no canto direito da tela (compensa o
                          // padding de 24 da coluna).
                          Transform.translate(
                            offset: const Offset(12, 0),
                            child: IconButton(
                              onPressed: _openFeedbackSheet,
                              icon: const Icon(Icons.more_horiz_rounded,
                                  color: AppColors.walnut),
                            ),
                          ),
                        ],
                      ),
                      // Ficha técnica (fio, cor, agulha, materiais) — só o
                      // que estiver preenchido no painel.
                      if (_hasMeta(l)) ...[
                        const SizedBox(height: 6),
                        _LessonMetaCard(lesson: l),
                      ],
                      if (l.description.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(l.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(height: 1.5)),
                      ],
                    ],
                  ),
                ),
              ),

              // Espaço pra barra fixa de baixo não cobrir o conteúdo.
              SliverToBoxAdapter(
                child: SizedBox(
                    height: 120 + MediaQuery.of(context).padding.bottom),
              ),
            ],
          ),
        ),

        // ── Barra fixa: Guia + Vídeo ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomActions(
            onGuide: _openGuide,
            onVideo: () => _openVideo(steps),
          ),
        ),
      ],
    );
  }

  bool _hasMeta(Lesson l) =>
      l.yarn != null ||
      l.mainColor != null ||
      l.crochetHook != null ||
      l.materials.isNotEmpty;

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

// ─── Bottom sheet de feedback: "Gostei disso" + "Mais sugestões" ────
// Sobe de baixo pra cima até a metade da tela. O like e a sugestão são
// gravados no servidor (tabela feedback, via POST /v1/feedback).
class _LessonFeedbackSheet extends ConsumerStatefulWidget {
  const _LessonFeedbackSheet({required this.lesson});
  final Lesson lesson;

  @override
  ConsumerState<_LessonFeedbackSheet> createState() =>
      _LessonFeedbackSheetState();
}

class _LessonFeedbackSheetState extends ConsumerState<_LessonFeedbackSheet> {
  final _commentCtrl = TextEditingController();
  bool _showSuggestion = false;
  bool _sending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  // 1 like e 1 comentário por usuário (o servidor deduplica; comentário
  // novo substitui o anterior).
  Future<void> _send({required String kind, String? comment}) async {
    setState(() => _sending = true);
    await ref.read(apiClientProvider).postSilent(
      '/v1/lessons/${widget.lesson.id}/feedback',
      {
        'kind': kind,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.tr('lesson_feedback_thanks'))),
    );
  }

  // Botões brancos do sheet, com texto em peso normal (sem bold).
  static final _whiteBtnStyle = OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(54),
    backgroundColor: Colors.white,
    foregroundColor: AppColors.walnut,
    side: const BorderSide(color: AppColors.linen),
    textStyle: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final half = MediaQuery.of(context).size.height * 0.5;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      // Sobe junto com o teclado quando o campo de sugestão está aberto.
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: half,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Alça do sheet
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.linen,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.lesson.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            // ── Gostei disso ──
            OutlinedButton.icon(
              onPressed: _sending ? null : () => _send(kind: 'like'),
              icon: const Icon(Icons.thumb_up_outlined, size: 20),
              label: Text(context.l10n.tr('lesson_like_button')),
              style: _whiteBtnStyle,
            ),
            const SizedBox(height: 12),
            // ── Mais sugestões ──
            if (!_showSuggestion)
              OutlinedButton.icon(
                onPressed: _sending
                    ? null
                    : () => setState(() => _showSuggestion = true),
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: Text(context.l10n.tr('lesson_suggest_button')),
                style: _whiteBtnStyle,
              )
            else ...[
              TextField(
                controller: _commentCtrl,
                autofocus: true,
                maxLength: 120,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.l10n.tr('lesson_suggest_hint'),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _sending
                    ? null
                    : () {
                        final text = _commentCtrl.text.trim();
                        if (text.isEmpty) return;
                        _send(kind: 'comment', comment: text);
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(_sending
                    ? '…'
                    : context.l10n.tr('lesson_suggest_send')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Ficha técnica: fio, cor principal, agulha e materiais ──────────
class _LessonMetaCard extends StatelessWidget {
  const _LessonMetaCard({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: softShadow(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lesson.yarn != null)
            _MetaRow(
              icon: Icons.gesture_rounded,
              label: context.l10n.tr('lesson_meta_yarn'),
              value: lesson.yarn!,
            ),
          if (lesson.mainColor != null)
            _MetaRow(
              icon: Icons.palette_outlined,
              label: context.l10n.tr('lesson_meta_color'),
              value: lesson.mainColor!,
              below: true,
            ),
          if (lesson.crochetHook != null)
            _MetaRow(
              icon: Icons.straighten_rounded,
              label: context.l10n.tr('lesson_meta_hook'),
              value: lesson.crochetHook!,
            ),
          if (lesson.materials.isNotEmpty) ...[
            _MetaRow(
              icon: Icons.shopping_basket_outlined,
              label: context.l10n.tr('lesson_meta_materials'),
              value: '',
            ),
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final mat in lesson.materials)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•',
                              style: TextStyle(
                                  color: AppColors.coral,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(mat,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.4,
                                    color: AppColors.walnut)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.below = false,
  });
  final IconData icon;
  final String label;
  final String value;
  // Força o valor embaixo do rótulo (ex.: Cor principal).
  final bool below;

  @override
  Widget build(BuildContext context) {
    // Valores curtos ficam na mesma linha do rótulo; textos longos (campos
    // legados podem ser frases inteiras) quebram pra baixo, em largura cheia.
    final stacked = below || value.length > 40;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.coral),
          const SizedBox(width: 10),
          Expanded(
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: _labelStyle),
                      const SizedBox(height: 2),
                      Text(value,
                          style: _valueStyle.copyWith(height: 1.4)),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: _labelStyle),
                      if (value.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(value,
                              textAlign: TextAlign.right, style: _valueStyle),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static const _labelStyle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.walnutMuted,
  );
  static const _valueStyle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: AppColors.walnut,
  );
}

// ─── Card informativo (dificuldade / tempo estimado) ────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: softShadow(0.05),
      ),
      child: Stack(
        clipBehavior: Clip.none, // deixa o ícone invadir a área do padding
        children: [
          // Ícone decorativo: sem fundo, grande, cinza e translúcido,
          // colado no canto superior direito do card (passa do padding).
          Positioned(
            top: -12,
            right: -12,
            child: Opacity(
              opacity: 0.22,
              child: Icon(icon, size: 46, color: AppColors.walnutMuted),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.walnutMuted,
                ),
              ),
              const SizedBox(height: 6),
              // FittedBox encolhe o texto se faltar espaço, em vez de cortar
              // ("Intermediário" cabe inteiro).
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.walnut,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Barra fixa de baixo: botões Guia + Vídeo lado a lado ───────────
class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.onGuide, required this.onVideo});
  final VoidCallback onGuide;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _ActionBtn(
                icon: Icons.menu_book_rounded,
                label: context.l10n.tr('lesson_cta_guide'),
                color: AppColors.coral,
                onTap: onGuide,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionBtn(
                icon: Icons.play_arrow_rounded,
                label: context.l10n.tr('lesson_cta_video'),
                color: AppColors.walnut,
                onTap: onVideo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
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
    );
  }
}

// ─── Página do Guia: tabs "Aula" (1 passo por vez) e "Chat com IA" ──
class _LessonGuidePage extends ConsumerStatefulWidget {
  const _LessonGuidePage({required this.detail, required this.onMarkCompleted});
  final LessonDetail detail;
  final VoidCallback onMarkCompleted;

  @override
  ConsumerState<_LessonGuidePage> createState() => _LessonGuidePageState();
}

class _LessonGuidePageState extends ConsumerState<_LessonGuidePage> {
  int _tab = 0; // 0 = Aula, 1 = Chat com IA
  int _step = 0;

  // Bypass de teste do plano na tab "Chat com IA" (true = libera sem plano).
  static const _chatBypassForTesting = false;

  void _selectTab(int i) {
    if (i == 1 && !_chatBypassForTesting) {
      // Chat com IA é premium: sem plano ativo, vai direto pra paywall.
      final sub = ref.read(subscriptionServiceProvider);
      if (!sub.isSubscribed) {
        context.push('/paywall');
        return;
      }
    }
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.detail.blocks.where((b) => b.type == 'step').toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    // Só blocos de texto soltos: vídeos ficam na aba Vídeo, não no guia.
    final otherBlocks =
        widget.detail.blocks.where((b) => b.type == 'text').toList();

    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // O chat tem campo de texto: deixa o teclado empurrar o conteúdo.
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              // ── Cabeçalho: voltar + título ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 0),
                child: Row(
                  children: [
                    _RoundBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.tr('lesson_cta_guide'),
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          Text(widget.detail.lesson.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tabs: Aula | Chat com IA ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: _GuideTabs(selected: _tab, onSelect: _selectTab),
              ),

              Expanded(
                child: _tab == 0
                    ? _StepPager(
                        steps: steps,
                        otherBlocks: otherBlocks,
                        current: _step,
                        onChange: (i) => setState(() => _step = i),
                        onMarkCompleted: () {
                          widget.onMarkCompleted();
                          Navigator.of(context).pop();
                        },
                      )
                    : const ChatView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tabs do guia (segmented control) ────────────────────────────────
class _GuideTabs extends StatelessWidget {
  const _GuideTabs({required this.selected, required this.onSelect});
  final int selected;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    Widget tab(int i, IconData icon, String label) {
      final isSel = selected == i;
      return Expanded(
        child: Material(
          color: isSel ? AppColors.coral : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelect(i),
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 18,
                      color: isSel ? Colors.white : AppColors.walnutSoft),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : AppColors.walnutSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: softShadow(0.05),
      ),
      child: Row(
        children: [
          tab(0, Icons.menu_book_rounded, context.l10n.tr('lesson_tab_lesson')),
          tab(1, Icons.auto_awesome, context.l10n.tr('lesson_tab_chat')),
        ],
      ),
    );
  }
}

// ─── Tab "Aula": um passo por vez, com progresso e navegação ─────────
class _StepPager extends StatefulWidget {
  const _StepPager({
    required this.steps,
    required this.otherBlocks,
    required this.current,
    required this.onChange,
    required this.onMarkCompleted,
  });
  final List<LessonBlock> steps;
  final List<LessonBlock> otherBlocks;
  final int current;
  final void Function(int) onChange;
  final VoidCallback onMarkCompleted;

  @override
  State<_StepPager> createState() => _StepPagerState();
}

class _StepPagerState extends State<_StepPager> {
  // Direção da última troca (1 = próximo, -1 = anterior) pro slide
  // entrar/sair do lado certo.
  int _dir = 1;

  @override
  void didUpdateWidget(covariant _StepPager old) {
    super.didUpdateWidget(old);
    if (widget.current != old.current) {
      _dir = widget.current > old.current ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final current = widget.current;

    if (steps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.l10n.tr('lesson_no_steps'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
    }

    final total = steps.length;
    final isLast = current == total - 1;

    return Column(
      children: [
        // ── Indicador de progresso ("4/6" + barra animada) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (current + 1) / total),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: AppColors.linen,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.coral),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Número atual: maior, coral e com animação de troca.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: Text(
                      '${current + 1}',
                      key: ValueKey(current),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.coral,
                      ),
                    ),
                  ),
                  Text(
                    '/$total',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.walnutMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Passo atual (slide direcional + fade na troca) ──
        Expanded(
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topCenter,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              transitionBuilder: (child, anim) {
                // Entrando: vem do lado pra onde se navegou; saindo: vai pro
                // lado oposto (a animação do que sai roda em reverso).
                final incoming = child.key == ValueKey(current);
                final begin =
                    incoming ? Offset(0.25 * _dir, 0) : Offset(-0.25 * _dir, 0);
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: begin, end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                );
              },
              child: SingleChildScrollView(
                key: ValueKey(current),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StepCard(block: steps[current], index: current + 1),
                    // blocos de texto soltos aparecem junto do último passo
                    if (isLast && widget.otherBlocks.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      for (final b in widget.otherBlocks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(b.text,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(height: 1.5)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Navegação: seta de voltar + Próximo/Concluir ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Row(
            children: [
              AnimatedOpacity(
                opacity: current > 0 ? 1 : 0.35,
                duration: const Duration(milliseconds: 250),
                child: _RoundBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap:
                      current > 0 ? () => widget.onChange(current - 1) : () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isLast
                      ? widget.onMarkCompleted
                      : () => widget.onChange(current + 1),
                  icon: Icon(isLast
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded),
                  label: Text(isLast
                      ? context.l10n.tr('lesson_mark_completed')
                      : context.l10n.tr('lesson_next_step')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
              ? Image.network(lesson.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const CoverPlaceholder(iconSize: 56))
              : const CoverPlaceholder(iconSize: 56),
        ),
        // Scrim de topo p/ legibilidade do botão voltar sobre fotos claras.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.28),
                  Colors.transparent
                ],
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
                ? Image.network(
                    block.stepImageUrl!,
                    fit: BoxFit.cover,
                    // Fade-in quando a imagem termina de carregar (se já veio
                    // do cache, aparece direto, sem piscar).
                    frameBuilder: (_, child, frame, wasSyncLoaded) {
                      if (wasSyncLoaded) return child;
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        child: child,
                      );
                    },
                    errorBuilder: (_, __, ___) => _imgPh(),
                  )
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
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: AppColors.coral, shape: BoxShape.circle),
                      child: Text('$n',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        block.stepTitle.isNotEmpty
                            ? block.stepTitle
                            : 'Passo $n',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                if (block.stepInstruction.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(block.stepInstruction,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.5)),
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
            child: Icon(Icons.image_outlined,
                size: 40, color: AppColors.walnutMuted)),
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
            LessonVideo(
                url: videoUrl, posterUrl: videoPoster, borderRadius: 12),
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
