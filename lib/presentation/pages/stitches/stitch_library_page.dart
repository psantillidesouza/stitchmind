import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/gradient_bg.dart';

class StitchLibraryPage extends ConsumerStatefulWidget {
  const StitchLibraryPage({super.key});

  @override
  ConsumerState<StitchLibraryPage> createState() => _StitchLibraryPageState();
}

class _StitchLibraryPageState extends ConsumerState<StitchLibraryPage> {
  StitchTechnique? _tech;
  bool _favoritesOnly = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Stitch s, Set<String> favs) {
    if (_tech != null && s.technique != _tech) return false;
    if (_favoritesOnly && !favs.contains(s.id)) return false;
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return s.namePt.toLowerCase().contains(q) ||
        s.nameEn.toLowerCase().contains(q) ||
        s.abbrev.toLowerCase().contains(q) ||
        s.categories.any((c) => c.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final stitchesAsync = ref.watch(stitchesProvider);
    final favsAsync = ref.watch(favoriteStitchesProvider);
    final favs = favsAsync.valueOrNull ?? const <String>{};

    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop()),
        ),
        body: SafeArea(
          child: stitchesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (stitches) {
          final filtered =
              stitches.where((s) => _matches(s, favs)).toList();

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Pontos',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'buscar ponto, abreviação, categoria…',
                      hintStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.walnutMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.walnutMuted,
                        size: 20,
                      ),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                            ),
                      filled: true,
                      fillColor: AppColors.paper,
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.linen),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.walnut,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'Todos',
                        selected: _tech == null && !_favoritesOnly,
                        onTap: () => setState(() {
                          _tech = null;
                          _favoritesOnly = false;
                        }),
                      ),
                      _FilterChip(
                        label: 'Crochê',
                        selected: _tech == StitchTechnique.crochet,
                        onTap: () => setState(
                            () => _tech = StitchTechnique.crochet),
                      ),
                      _FilterChip(
                        label: 'Tricô',
                        selected: _tech == StitchTechnique.knit,
                        onTap: () =>
                            setState(() => _tech = StitchTechnique.knit),
                      ),
                      _FilterChip(
                        label: 'Favoritos',
                        icon: Icons.bookmark,
                        selected: _favoritesOnly,
                        onTap: () =>
                            setState(() => _favoritesOnly = !_favoritesOnly),
                      ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Nenhum ponto encontrado.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _StitchTile(
                        stitch: filtered[i],
                        favorite: favs.contains(filtered[i].id),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.walnut : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(
            color: selected ? AppColors.walnut : AppColors.linen,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? AppColors.paper : AppColors.walnut,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? AppColors.paper : AppColors.walnut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StitchTile extends ConsumerWidget {
  const _StitchTile({required this.stitch, required this.favorite});
  final Stitch stitch;
  final bool favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.card),
      onTap: () => context.push('/stitches/${stitch.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.linen),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 96,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.linen.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    stitch.abbrev,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.walnut,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (favorite)
                  const Positioned(
                    right: 6,
                    top: 6,
                    child: Icon(
                      Icons.bookmark,
                      size: 18,
                      color: AppColors.terracotta,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              stitch.namePt,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${stitch.technique.labelPt} · ${stitch.difficulty.labelPt}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
