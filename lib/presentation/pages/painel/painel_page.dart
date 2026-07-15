import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/lesson.dart';
import '../../providers/platform_providers.dart';
import '../../widgets/fade_in.dart';

/// Primeira tela do app: painel de aulas vindas do backend.
class PainelPage extends ConsumerWidget {
  const PainelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(lessonsProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.refresh(lessonsProvider.future),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const FadeIn(child: _Header()),
            lessonsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: _ErrorCard(message: '$e'),
              ),
              data: (lessons) => lessons.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: _EmptyCard(),
                    )
                  : _LessonList(lessons: lessons),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suas aulas', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('Painel', style: Theme.of(context).textTheme.displayMedium),
        ],
      ),
    );
  }
}

class _LessonList extends StatelessWidget {
  const _LessonList({required this.lessons});
  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    // destaque "continuar" = primeira em progresso
    final inProgress = lessons.where((l) => l.progress?.started == true && !(l.progress?.completed ?? false)).toList();
    final continueLesson = inProgress.isEmpty ? null : inProgress.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (continueLesson != null) ...[
          FadeIn(
            delay: const Duration(milliseconds: 80),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: _ContinueCard(lesson: continueLesson),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text('Todas as aulas',
              style: Theme.of(context).textTheme.titleLarge),
        ),
        ...lessons.asMap().entries.map((e) {
          return FadeIn(
            delay: Duration(milliseconds: 120 + e.key * 50),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: _LessonCard(lesson: e.value),
            ),
          );
        }),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.lesson});
  final Lesson lesson;
  @override
  Widget build(BuildContext context) {
    final pct = (lesson.progress?.progressPct ?? 0) / 100;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: () => context.push('/lessons/${lesson.slug}'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.walnut, AppColors.terracottaDeep],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CONTINUAR DE ONDE PAROU',
                style: AppText.eyebrow.copyWith(color: AppColors.ochre)),
            const SizedBox(height: 8),
            Text(lesson.title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: AppColors.paper)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: AppColors.paper.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(AppColors.ochre),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final done = lesson.progress?.completed ?? false;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => context.push('/lessons/${lesson.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.linen.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  done ? Icons.check_circle : Icons.play_circle_outline,
                  color: done ? AppColors.sage : AppColors.terracotta,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (lesson.courseTitle != null) lesson.courseTitle!,
                        if (lesson.durationMin != null) '${lesson.durationMin} min',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.walnutMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.linen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nenhuma aula ainda',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Assim que as aulas forem publicadas no painel, elas aparecem aqui.',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.terracotta.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.terracotta.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Não consegui carregar as aulas',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.terracottaDeep)),
          const SizedBox(height: 6),
          Text(message,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('Verifique o servidor em Perfil → URL do servidor.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
