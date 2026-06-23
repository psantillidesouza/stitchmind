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
import '../../widgets/pager.dart';
import '../../widgets/premium_lock_badge.dart';
import '../aulas_salvas/saved_lessons_page.dart';

/// Paginação da lista de aulas em "Tools" (mesmo pager numerado da home).
const _kAulasPageSize = 6;
final aulasPageProvider = StateProvider<int>((ref) => 0);

class AulasPage extends ConsumerWidget {
  const AulasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonsProvider);
    final notPremium = !ref.watch(subscriptionServiceProvider).isSubscribed;
    final pageRaw = ref.watch(aulasPageProvider);
    final recentSlugs = ref.watch(recentLessonsProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.coral,
        onRefresh: () async => ref.invalidate(lessonsProvider),
        child: lessons.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.coral)),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 200),
            Center(child: Text('${context.l10n.tr('aulas_error')}$e', style: Theme.of(context).textTheme.bodyMedium)),
          ]),
          data: (list) {
            final totalPages =
                list.isEmpty ? 0 : (list.length / _kAulasPageSize).ceil();
            final page =
                totalPages == 0 ? 0 : pageRaw.clamp(0, totalPages - 1);
            final visible = list
                .skip(page * _kAulasPageSize)
                .take(_kAulasPageSize)
                .toList();
            // Últimas aulas abertas, na ordem (mais recente primeiro),
            // resolvidas contra a lista carregada.
            final bySlug = {for (final l in list) l.slug: l};
            final recent = [
              for (final s in recentSlugs)
                if (bySlug[s] != null) bySlug[s]!
            ];
            return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.tr('aulas_eyebrow'),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: AppColors.walnutMuted,
                        )),
                    const SizedBox(height: 6),
                    Text(context.l10n.tr('aulas_tools'), style: Theme.of(context).textTheme.displayLarge),
                  ],
                ),
              ),

              // Últimas aulas abertas — carrossel horizontal.
              if (recent.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                  child: Text(context.l10n.tr('aulas_recent_title'),
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                SizedBox(
                  height: 188,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: recent.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, i) {
                      final l = recent[i];
                      return _RecentLessonCard(
                          lesson: l, locked: l.isPremium && notPremium);
                    },
                  ),
                ),
              ],

              // Ferramentas inteligentes (IA)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
                child: Text(context.l10n.tr('aulas_smart_tools'),
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _SmartTool(
                  icon: Icons.camera_alt_rounded,
                  iconBg: AppColors.coral,
                  title: context.l10n.tr('aulas_analyze_title'),
                  subtitle: context.l10n.tr('aulas_analyze_subtitle'),
                  onTap: () => context.push('/analyze'),
                  locked: notPremium,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _SmartTool(
                  icon: Icons.chat_bubble_rounded,
                  iconBg: AppColors.sage,
                  title: context.l10n.tr('aulas_chat_title'),
                  subtitle: context.l10n.tr('aulas_chat_subtitle'),
                  onTap: () => context.push('/chat'),
                  locked: notPremium,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _SmartTool(
                  icon: Icons.bookmark_rounded,
                  iconBg: AppColors.ochre,
                  title: context.l10n.tr('aulas_saved_title'),
                  subtitle: context.l10n.tr('aulas_saved_subtitle'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SavedLessonsPage()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _SmartTool(
                  icon: Icons.file_download_rounded,
                  iconBg: AppColors.walnutSoft,
                  title: context.l10n.tr('aulas_import_title'),
                  subtitle: context.l10n.tr('aulas_import_subtitle'),
                  onTap: () => context.push('/import'),
                  locked: notPremium,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _SmartTool(
                  icon: Icons.menu_book_rounded,
                  iconBg: AppColors.sage,
                  title: context.l10n.tr('aulas_patterns_title'),
                  subtitle: context.l10n.tr('aulas_patterns_subtitle'),
                  onTap: () => context.push('/patterns'),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text(context.l10n.tr('aulas_learn_stitches'),
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
              const SizedBox(height: 4),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: AppColors.card, borderRadius: BorderRadius.circular(20)),
                    child: Text(context.l10n.tr('aulas_empty'),
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                )
              else ...[
                ...visible.map((l) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                      child: _LessonRow(
                          lesson: l, locked: l.isPremium && notPremium),
                    )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Pager(
                    total: totalPages,
                    current: page,
                    onSelect: (p) =>
                        ref.read(aulasPageProvider.notifier).state = p,
                  ),
                ),
              ],
            ],
          );
          },
        ),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson, this.locked = false});
  final Lesson lesson;
  final bool locked;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/lessons/${lesson.slug}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: softShadow(0.05),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
              child: SizedBox(
                width: 110, height: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    lesson.coverUrl != null
                        ? Image.network(lesson.coverUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const CoverPlaceholder())
                        : const CoverPlaceholder(),
                    if (locked)
                      const Positioned(
                          top: 6, left: 6, child: PremiumLockBadge(compact: true)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (lesson.courseTitle != null)
                      Text(lesson.courseTitle!.toUpperCase(),
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 10, letterSpacing: 1,
                              fontWeight: FontWeight.w700, color: AppColors.coral)),
                    const SizedBox(height: 4),
                    Text(lesson.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.schedule, size: 13, color: AppColors.walnutMuted),
                      const SizedBox(width: 4),
                      Text('${context.l10n.tr('aulas_duration_min', {'n': '${lesson.durationMin ?? 10}'})} · ${lesson.difficulty ?? context.l10n.tr('aulas_difficulty_beginner')}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.chevron_right, color: AppColors.walnutMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card compacto do carrossel "aberturas recentes" (~150px de largura).
class _RecentLessonCard extends StatelessWidget {
  const _RecentLessonCard({required this.lesson, this.locked = false});
  final Lesson lesson;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/lessons/${lesson.slug}'),
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 150,
                height: 110,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    lesson.coverUrl != null
                        ? Image.network(lesson.coverUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const CoverPlaceholder())
                        : const CoverPlaceholder(),
                    if (locked)
                      const Positioned(
                          top: 6, left: 6, child: PremiumLockBadge(compact: true)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (lesson.courseTitle != null)
              Text(lesson.courseTitle!.toUpperCase(),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 10, letterSpacing: 1,
                      fontWeight: FontWeight.w700, color: AppColors.coral)),
            const SizedBox(height: 2),
            Text(lesson.title,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _SmartTool extends StatelessWidget {
  const _SmartTool({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
  });
  final IconData icon;
  final Color iconBg;
  final String title, subtitle;
  final VoidCallback onTap;

  /// Quando true, mostra um cadeado e abre a paywall em vez do destino.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: locked ? () => context.push('/paywall') : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [iconBg, Color.lerp(iconBg, AppColors.ink, 0.18)!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: iconBg.withValues(alpha: 0.32),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                        child: Icon(icon, size: 25, color: Colors.white)),
                  ),
                  if (locked)
                    Positioned(
                      right: -4, top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.ochre,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_rounded,
                            size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppColors.peach.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    locked ? Icons.lock_rounded : Icons.arrow_forward_rounded,
                    size: 16, color: AppColors.walnutSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
