import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/app_chips.dart';
import '../../widgets/lesson_video.dart';

class StitchDetailPage extends ConsumerWidget {
  const StitchDetailPage({required this.stitchId, super.key});
  final String stitchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stitchAsync = ref.watch(stitchByIdProvider(stitchId));
    final favs =
        ref.watch(favoriteStitchesProvider).valueOrNull ?? const <String>{};
    final isFavorite = favs.contains(stitchId);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.bookmark : Icons.bookmark_border,
              color:
                  isFavorite ? AppColors.terracotta : AppColors.walnut,
            ),
            onPressed: () =>
                ref.read(stitchRepositoryProvider).toggleFavorite(stitchId),
          ),
        ],
      ),
      body: stitchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (stitch) {
          if (stitch == null) {
            return const Center(child: Text('Ponto não encontrado.'));
          }
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              children: [
                if (stitch.videoUrl != null && stitch.videoUrl!.isNotEmpty)
                  LessonVideo(
                    url: stitch.videoUrl!,
                    posterUrl: stitch.videoPoster,
                  )
                else
                  Container(
                    height: 240,
                    decoration: BoxDecoration(
                      color: AppColors.linen.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          stitch.abbrev,
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w600,
                            color: AppColors.walnut,
                            height: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(AppRadii.chip),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_circle_outline,
                                size: 14,
                                color: AppColors.walnutSoft,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'vídeo em breve',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.walnutSoft,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  stitch.namePt,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  stitch.nameEn,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppPill(label: stitch.technique.labelPt),
                    AppPill(label: stitch.difficulty.labelPt),
                    ...stitch.categories.map((c) => AppPill(label: c)),
                  ],
                ),
                const SizedBox(height: 28),
                const _SectionTitle('Sobre o ponto'),
                const SizedBox(height: 8),
                Text(
                  stitch.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (stitch.steps.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const _SectionTitle('Passo a passo'),
                  const SizedBox(height: 4),
                  ...List.generate(
                    stitch.steps.length,
                    (i) => _Step(index: i + 1, text: stitch.steps[i]),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppText.eyebrow.copyWith(color: AppColors.terracottaDeep),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.text});
  final int index;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.walnut,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.paper,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
