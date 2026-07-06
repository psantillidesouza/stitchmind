import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/local/saved_lessons_store.dart';
import '../../providers/saved_lessons_provider.dart';
import '../../widgets/gradient_bg.dart';
import 'saved_lesson_view_page.dart';

/// Lista as aulas salvas no aparelho. Toque abre a aula.
class SavedLessonsPage extends ConsumerWidget {
  const SavedLessonsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(savedLessonsProvider);

    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(context.l10n.tr('saved_title')),
        ),
        body: SafeArea(
          top: false,
          child: lessons.isEmpty
              ? _Empty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: lessons.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _LessonCard(
                    lesson: lessons[i],
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SavedLessonViewPage(lesson: lessons[i]),
                      ),
                    ),
                    onDelete: () =>
                        ref.read(savedLessonsProvider.notifier).remove(lessons[i].id),
                  ),
                ),
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, required this.onOpen, required this.onDelete});
  final SavedLesson lesson;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  String _previewOf(BuildContext context) {
    // pega a primeira linha de texto que não seja título/lista
    for (final line in lesson.markdown.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#') || t.startsWith('-') || t.startsWith('*')) {
        continue;
      }
      return t.replaceAll(RegExp(r'[*_`]'), '');
    }
    return context.l10n.tr('saved_preview_fallback');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: lesson.imagePath != null
                      ? Image.file(
                          File(lesson.imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _BookIcon(),
                        )
                      : const _BookIcon(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 3),
                    Text(_previewOf(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.walnutMuted, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.peachSoft,
        title: Text(context.l10n.tr('saved_remove_title')),
        content: Text(context.l10n.tr('saved_remove_body', {'title': lesson.title})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.tr('saved_cancel'))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.coralDeep),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.tr('saved_remove'))),
        ],
      ),
    );
    if (ok == true) onDelete();
  }
}

class _BookIcon extends StatelessWidget {
  const _BookIcon();
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.coralSoft,
        alignment: Alignment.center,
        child: const Icon(Icons.menu_book_rounded,
            color: AppColors.coral, size: 24),
      );
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_rounded,
                size: 64, color: AppColors.walnutMuted),
            const SizedBox(height: 16),
            Text(context.l10n.tr('saved_empty_title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              context.l10n.tr('saved_empty_hint'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
