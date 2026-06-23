import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../core/lesson_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/local/saved_lessons_store.dart';
import '../../widgets/gradient_bg.dart';

/// Abre uma aula salva e renderiza em CARDS de passo (estilo das aulas do app):
/// capa/título + chips, materiais, um card por passo (número + título +
/// instrução) e dicas. Se não der pra estruturar, cai no Markdown.
class SavedLessonViewPage extends StatelessWidget {
  const SavedLessonViewPage({required this.lesson, super.key});
  final SavedLesson lesson;

  @override
  Widget build(BuildContext context) {
    final p = parseLesson(lesson.markdown);

    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(context.l10n.tr('savedview_title')),
        ),
        body: SafeArea(
          top: false,
          child: p.isStructured
              ? _StructuredView(lesson: p, imagePath: lesson.imagePath)
              : _MarkdownFallback(
                  markdown: lesson.markdown, imagePath: lesson.imagePath),
        ),
      ),
    );
  }
}

class _StructuredView extends StatelessWidget {
  const _StructuredView({required this.lesson, this.imagePath});
  final ParsedLesson lesson;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _LessonPhoto(path: imagePath),
        // ── Cabeçalho: título + chips + intro ──
        Text(lesson.title, style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Chip(icon: Icons.auto_awesome_rounded, label: context.l10n.tr('savedview_chip_stitch')),
            _Chip(
                icon: Icons.format_list_numbered_rounded,
                label: context.l10n.tr('savedview_chip_steps', {'n': '${lesson.steps.length}'})),
          ],
        ),
        if (lesson.intro.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(lesson.intro,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(height: 1.5, color: AppColors.walnutSoft)),
        ],

        // ── Materiais ──
        if (lesson.materials.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionCard(
            icon: Icons.shopping_basket_rounded,
            title: context.l10n.tr('savedview_materials'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lesson.materials
                  .map((m) => _Bullet(text: m))
                  .toList(),
            ),
          ),
        ],

        // ── Passo a passo ──
        const SizedBox(height: 26),
        Text(context.l10n.tr('savedview_step_by_step'), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        ...List.generate(lesson.steps.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _StepCard(n: i + 1, step: lesson.steps[i]),
          );
        }),

        // ── Dicas ──
        if (lesson.tips.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionCard(
            icon: Icons.lightbulb_rounded,
            title: context.l10n.tr('savedview_tips'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  lesson.tips.map((t) => _Bullet(text: t)).toList(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Center(
          child: Text(context.l10n.tr('savedview_saved_on_device'),
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

// ── Card de um passo (número + título + instrução) ──────────────────
class _StepCard extends StatelessWidget {
  const _StepCard({required this.n, required this.step});
  final int n;
  final LessonStep step;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: softShadow(0.06),
      ),
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
                child: Text(step.title,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
          ),
          if (step.body.trim().isNotEmpty && step.body.trim() != step.title) ...[
            const SizedBox(height: 12),
            Text(step.body,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: softShadow(0.05),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.coral),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7, right: 10),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppColors.coral, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.45)),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(13),
        boxShadow: softShadow(0.04),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.coral),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.walnut)),
      ]),
    );
  }
}

class _LessonPhoto extends StatelessWidget {
  const _LessonPhoto({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.file(
          File(p),
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _MarkdownFallback extends StatelessWidget {
  const _MarkdownFallback({required this.markdown, this.imagePath});
  final String markdown;
  final String? imagePath;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _LessonPhoto(path: imagePath),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: softShadow(0.05),
          ),
          child: GptMarkdown(markdown,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15.5,
                  height: 1.55,
                  color: AppColors.walnut)),
        ),
      ],
    );
  }
}
