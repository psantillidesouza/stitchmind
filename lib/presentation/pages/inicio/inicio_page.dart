import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/entities/community.dart';
import '../../../domain/entities/lesson.dart';
import '../../providers/platform_providers.dart';
import '../../widgets/cover_placeholder.dart';
import '../../widgets/fade_in.dart';
import '../../widgets/gradient_bg.dart';
import '../../widgets/offer_banner.dart';
import '../../widgets/pager.dart';
import '../../widgets/premium_lock_badge.dart';

/// Filtro ativo da seção "Inspiração".
/// Valores: `'trending'` (Em alta — ordem padrão), `'new'` (Novo — adições
/// mais recentes primeiro) ou `'cat:<slug>'` (uma categoria específica).
final homeFilterProvider = StateProvider<String>((ref) => 'trending');

/// Paginação numerada da lista "Todas as aulas": página atual (base 0).
/// Cada página mostra [_kLessonsPageSize] aulas; volta à página 1 ao trocar
/// de filtro/categoria.
const _kLessonsPageSize = 6;
final lessonsPageProvider = StateProvider<int>((ref) => 0);

class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  String _greeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 5) return context.l10n.tr('home_greeting_dawn');
    if (h < 12) return context.l10n.tr('home_greeting_morning');
    if (h < 18) return context.l10n.tr('home_greeting_afternoon');
    return context.l10n.tr('home_greeting_evening');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tips = ref.watch(tipsProvider);
    final lessons = ref.watch(lessonsProvider);
    // Aulas premium aparecem com cadeado para quem ainda não assina.
    final notPremium = !ref.watch(subscriptionServiceProvider).isSubscribed;

    // Filtro ativo da seção "Inspiração" ('trending' | 'new' | 'cat:<slug>').
    final filter = ref.watch(homeFilterProvider);
    // Página atual da lista vertical "Todas as aulas" (base 0).
    final lessonsPage = ref.watch(lessonsPageProvider);
    // Categorias distintas presentes nas aulas carregadas (slug → nome).
    final allLessons = lessons.asData?.value ?? const <Lesson>[];
    final categories = <String, String>{};
    for (final l in allLessons) {
      if (l.categorySlug != null && l.category != null) {
        categories[l.categorySlug!] = l.category!;
      }
    }
    // Aplica o filtro: "Em alta" mantém a ordem do servidor, "Novo" ordena
    // pelas mais recentes (created_at desc), categoria filtra pelo slug.
    List<Lesson> filtered(List<Lesson> list) {
      if (filter == 'new') {
        final sorted = [...list];
        sorted.sort((a, b) {
          final da = a.createdAt, db = b.createdAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1; // sem data vai pro fim
          if (db == null) return -1;
          return db.compareTo(da); // mais novo primeiro
        });
        return sorted;
      }
      if (filter.startsWith('cat:')) {
        final slug = filter.substring(4);
        return list.where((l) => l.categorySlug == slug).toList();
      }
      return list; // 'trending'
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.coral,
        onRefresh: () async {
          ref.invalidate(tipsProvider);
          ref.invalidate(lessonsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            FadeIn(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(_greeting(context).toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: AppColors.walnutMuted,
                          )),
                      const SizedBox(width: 6),
                      const Icon(Icons.wb_sunny_rounded, size: 14, color: AppColors.ochre),
                    ]),
                    const SizedBox(height: 6),
                    Text(context.l10n.tr('home_lets_crochet'),
                        style: Theme.of(context).textTheme.displayLarge),
                  ],
                ),
              ),
            ),

            // Dicas
            _SectionTitle(context.l10n.tr('home_tip_of_the_day')),
            tips.when(
              loading: () => const _LoadingStrip(),
              error: (_, __) => const SizedBox.shrink(),
              // IntrinsicHeight + stretch: todos os cards ficam com a altura do
              // maior, e cada um mostra a dica inteira (sem cortar o texto).
              data: (list) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const SizedBox(width: 14),
                        _TipCard(tip: list[i], index: i),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Banner de oferta especial → paywall (só para quem ainda não assina).
            if (notPremium)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: OfferBanner(onTap: () => context.push('/paywall')),
              ),

            // Aulas prontas (destaque)
            _SectionTitle(context.l10n.tr('home_lessons_ready')),
            lessons.when(
              loading: () => const _LoadingStrip(),
              error: (e, __) => _InlineError(message: '$e'),
              data: (rawList) {
                // Destaque: lista completa. O filtro de categoria age só na
                // seção "Todas as aulas" abaixo.
                final list = rawList;
                return list.isEmpty
                    ? _EmptyInline(context.l10n.tr('home_published_lessons_appear_here'))
                    : SizedBox(
                        height: 252,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (_, i) => _LessonCard(
                              lesson: list[i],
                              locked: list[i].isPremium && notPremium),
                        ),
                      );
              },
            ),

            // Todas as aulas (lista vertical — no lugar da antiga comunidade)
            _SectionTitle(context.l10n.tr('home_all_lessons')),
            // Filtro de categorias — no topo de "Todas as aulas".
            _CategoryChips(
              categories: categories,
              selected: filter,
              onSelected: (value) {
                ref.read(homeFilterProvider.notifier).state = value;
                // Volta para a página 1 ao trocar de filtro.
                ref.read(lessonsPageProvider.notifier).state = 0;
              },
            ),
            lessons.when(
              loading: () => const _LoadingStrip(),
              error: (_, __) => const SizedBox.shrink(),
              data: (rawList) {
                final list = filtered(rawList);
                if (list.isEmpty) {
                  return _EmptyInline(
                      context.l10n.tr('home_published_lessons_appear_here'));
                }
                final totalPages = (list.length / _kLessonsPageSize).ceil();
                final page = lessonsPage.clamp(0, totalPages - 1);
                final start = page * _kLessonsPageSize;
                final visible =
                    list.skip(start).take(_kLessonsPageSize).toList();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      for (final l in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LessonTile(
                              lesson: l, locked: l.isPremium && notPremium),
                        ),
                      Pager(
                        total: totalPages,
                        current: page,
                        onSelect: (p) =>
                            ref.read(lessonsPageProvider.notifier).state = p,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section title ──────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
      child: Text(text, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}

// ─── Chips de "Inspiração" (Em alta / Novo / categorias) ────────────
class _ChipData {
  const _ChipData(this.value, this.label, this.icon);
  final String value; // 'trending' | 'new' | 'cat:<slug>'
  final String label;
  final IconData icon;
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  /// slug → nome de exibição.
  final Map<String, String> categories;
  final String selected; // valor do filtro ativo
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <_ChipData>[
      _ChipData('trending', context.l10n.tr('home_filter_trending'),
          Icons.local_fire_department_rounded),
      _ChipData('new', context.l10n.tr('home_filter_new'),
          Icons.auto_awesome_rounded),
      for (final e in categories.entries)
        _ChipData('cat:${e.key}', e.value, Icons.sell_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 14),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final it = items[i];
            return _Chip(
              label: it.label,
              icon: it.icon,
              active: selected == it.value,
              onTap: () => onSelected(it.value),
            );
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.coral : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border:
              active ? null : Border.all(color: AppColors.hairline, width: 1),
          boxShadow: active ? softShadow(0.12) : softShadow(0.04),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: active ? AppColors.paper : AppColors.coral),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.paper : AppColors.walnutSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Paginação numerada (1 2 3 … última) ────────────────────────────
// ─── Tip card ───────────────────────────────────────────────────────
// Cards pastel que alternam entre coral / sage / ochre — variedade suave
// no lugar de um bloco coral cheio. O coral saturado fica reservado para
// o que é acionável (CTA, chip ativo).
class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip, required this.index});
  final Tip tip;
  final int index;

  // [fundo lavado, cor de acento]
  static const _palettes = <List<Color>>[
    [AppColors.coralSoft, AppColors.coral],
    [AppColors.sageSoft, AppColors.sage],
    [Color(0xFFFDF1DD), AppColors.ochre],
  ];

  @override
  Widget build(BuildContext context) {
    final p = _palettes[index % _palettes.length];
    final bg = p[0];
    final accent = p[1];
    return Container(
      width: 264,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.20), width: 1),
        boxShadow: softShadow(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge do ícone na cor de acento.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.32),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.tips_and_updates_rounded,
                color: AppColors.paper, size: 21),
          ),
          const SizedBox(height: 13),
          Text(tip.title,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.walnut)),
          const SizedBox(height: 6),
          Text(tip.body,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.walnutSoft)),
        ],
      ),
    );
  }
}

// ─── Lesson card ────────────────────────────────────────────────────
class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, this.locked = false});
  final Lesson lesson;
  final bool locked;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/lessons/${lesson.slug}'),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: softShadow(0.06),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: SizedBox(
                height: 130, width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    lesson.coverUrl != null
                        ? Image.network(lesson.coverUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const CoverPlaceholder())
                        : const CoverPlaceholder(),
                    if (locked)
                      const Positioned(
                          top: 8, left: 8, child: PremiumLockBadge()),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(lesson.courseTitle ?? lesson.description,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.schedule, size: 14, color: AppColors.walnutMuted),
                    const SizedBox(width: 4),
                    Text(context.l10n.tr('home_duration_min', {'n': '${lesson.durationMin ?? 10}'}),
                        style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    const CircleAvatar(radius: 14, backgroundColor: AppColors.coral,
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Lesson tile (vertical, full-width) ─────────────────────────────
class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, this.locked = false});
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
                width: 96, height: 96,
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
                padding: const EdgeInsets.all(14),
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
                      Text(context.l10n.tr('home_duration_min', {'n': '${lesson.durationMin ?? 10}'}),
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

// ─── Helpers ────────────────────────────────────────────────────────
class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();
  @override
  Widget build(BuildContext context) => const SizedBox(
      height: 120, child: Center(child: CircularProgressIndicator(color: AppColors.coral)));
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.card, borderRadius: BorderRadius.circular(20)),
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18)),
          child: Text('${context.l10n.tr('home_load_failed')}\n$message',
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
}
