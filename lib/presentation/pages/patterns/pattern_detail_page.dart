import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/entities.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/app_chips.dart';

class PatternDetailPage extends ConsumerWidget {
  const PatternDetailPage({required this.patternId, super.key});
  final String patternId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(patternByIdProvider(patternId));

    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: async.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.coral,
              onPressed: () => context.push('/follow/$patternId'),
              icon: const Icon(Icons.playlist_play_rounded, color: Colors.white),
              label: Text(
                context.l10n.tr('pattern_follow_cta'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (pattern) {
          if (pattern == null) {
            return const Center(child: Text('Pattern not found.'));
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.cream,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: pattern.technique == StitchTechnique.knit
                            ? const [AppColors.knitGradTop, AppColors.knitGradBottom]
                            : const [AppColors.crochetGradTop, AppColors.crochetGradBottom],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      pattern.name,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'por ${pattern.author}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppPill(label: pattern.technique.labelPt),
                        AppPill(label: pattern.difficulty.labelPt),
                        AppPill(
                          label: '${pattern.estimatedTime.inHours}h',
                        ),
                        AppPill(
                          label: '${pattern.totalRows} rows',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      pattern.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.linen),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Meta(label: 'Yarn', value: pattern.yarnRequirement),
                          if (pattern.suggestedNeedle != null) ...[
                            const SizedBox(height: 8),
                            _Meta(
                              label: 'Suggested hook / needle',
                              value: pattern.suggestedNeedle!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Sections',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    ...pattern.sections.map(
                      (s) => _SectionTile(section: s),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () => context.push(
                        '/projects/new?patternId=${pattern.id}',
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Start a project from this pattern'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTile extends StatefulWidget {
  const _SectionTile({required this.section});
  final PatternSection section;

  @override
  State<_SectionTile> createState() => _SectionTileState();
}

class _SectionTileState extends State<_SectionTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.linen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (s.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            s.subtitle!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${s.rows.length} rows',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: AppColors.walnutMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.walnutSoft,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: s.rows.map((r) => _RowLine(row: r)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RowLine extends StatelessWidget {
  const _RowLine({required this.row});
  final PatternRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${row.row}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.terracotta,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.instruction,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (row.stitchCount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '(${row.stitchCount} pontos)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
