import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/entities.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/imported_patterns_provider.dart';
import '../../providers/providers.dart';
import 'follow_model.dart';

/// Modo "Seguir Receita": instrução da carreira atual + contador integrado +
/// progresso, numa tela só, ligado a um [Project] (retoma de onde parou).
class FollowPatternPage extends ConsumerStatefulWidget {
  const FollowPatternPage({required this.patternId, super.key});
  final String patternId;

  @override
  ConsumerState<FollowPatternPage> createState() => _FollowPatternPageState();
}

class _FollowPatternPageState extends ConsumerState<FollowPatternPage> {
  String? _projectId;
  bool _ensuring = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // tela acordada enquanto segue a receita
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  /// Garante um projeto vinculado à receita (cria se for a primeira vez).
  Future<void> _ensureProject(Pattern p) async {
    if (_projectId != null || _ensuring) return;
    _ensuring = true;
    final repo = ref.read(projectRepositoryProvider);
    Project? existing;
    for (final pr in repo.getAll()) {
      if (pr.patternId == p.id) {
        existing = pr;
        break;
      }
    }
    existing ??= await _create(p);
    if (mounted) setState(() => _projectId = existing!.id);
  }

  Future<Project> _create(Pattern p) async {
    final proj = Project(
      id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
      name: p.name,
      technique: p.technique,
      yarn: p.yarnRequirement,
      needle: p.suggestedNeedle ?? '',
      status: ProjectStatus.inProgress,
      currentRow: 0,
      startedAt: DateTime.now(),
      targetRow: p.totalRows,
      patternId: p.id,
    );
    await ref.read(projectActionsProvider).save(proj);
    return proj;
  }

  void _bump(int delta, int total) {
    final id = _projectId;
    if (id == null) return;
    final project = ref.read(projectByIdProvider(id));
    if (project == null) return;
    final next = (project.currentRow + delta).clamp(0, total);
    if (next == project.currentRow) return;
    if (next >= total) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    ref.read(projectActionsProvider).setRow(id, next);
  }

  void _showGlossary(BuildContext context, Pattern pattern) {
    final entries = (pattern.abbrevGlossary ?? const {}).entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cream,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          children: [
            Text(context.l10n.tr('follow_glossary'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${e.key}  ',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, color: AppColors.coral),
                      ),
                      TextSpan(text: e.value),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(resolvePatternProvider(widget.patternId));
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(async.valueOrNull?.name ?? ''),
        actions: [
          if (async.valueOrNull?.abbrevGlossary?.isNotEmpty ?? false)
            IconButton(
              icon: const Icon(Icons.menu_book_rounded),
              tooltip: context.l10n.tr('follow_glossary'),
              onPressed: () => _showGlossary(context, async.value!),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.coral)),
        error: (e, _) => Center(child: Text('$e')),
        data: (pattern) {
          if (pattern == null) {
            return Center(child: Text(context.l10n.tr('follow_not_found')));
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureProject(pattern);
          });
          final id = _projectId;
          if (id == null) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.coral));
          }
          final project = ref.watch(projectByIdProvider(id));
          if (project == null) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.coral));
          }
          return _Follow(pattern: pattern, project: project, onBump: _bump);
        },
      ),
    );
  }
}

class _Follow extends StatelessWidget {
  const _Follow({
    required this.pattern,
    required this.project,
    required this.onBump,
  });
  final Pattern pattern;
  final Project project;
  final void Function(int delta, int total) onBump;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = buildFollowView(pattern, project.currentRow);
    final total = vm.total;
    final done = vm.done;
    final isDone = vm.isDone;
    final active = vm.active;
    final prev = vm.prev;
    final next = vm.next;
    final progress = vm.progress;

    return Column(
      children: [
        // Progresso
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.peach.withValues(alpha: 0.5),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.coral),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.tr('follow_row_label',
                    {'n': '${isDone ? total : done + 1}', 'total': '$total'}),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.walnutMuted),
              ),
            ],
          ),
        ),

        Expanded(
          child: isDone
              ? _DoneView(total: total)
              : _ActiveView(active: active!, prev: prev, next: next),
        ),

        // Contador integrado
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Row(
            children: [
              _CounterButton(
                icon: Icons.remove_rounded,
                onTap: () => onBump(-1, total),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('${isDone ? total : done + 1}',
                        style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                    Text(l10n.tr('follow_current_row'),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.walnutMuted)),
                  ],
                ),
              ),
              _CounterButton(
                icon: Icons.add_rounded,
                filled: true,
                onTap: isDone ? null : () => onBump(1, total),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveView extends StatelessWidget {
  const _ActiveView({required this.active, this.prev, this.next});
  final FlatRow active;
  final FlatRow? prev;
  final FlatRow? next;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      children: [
        if (prev != null) _Ghost(row: prev!),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(active.section.toUpperCase(),
                  style: AppText.eyebrow.copyWith(color: AppColors.coral)),
              const SizedBox(height: 10),
              Text(
                active.row.stitchCount != null
                    ? '${active.row.instruction}  (${active.row.stitchCount})'
                    : active.row.instruction,
                style: const TextStyle(
                    fontSize: 22, height: 1.35, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (next != null) _Ghost(row: next!),
      ],
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost({required this.row});
  final FlatRow row;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Text(
        '${row.row.row}. ${row.row.instruction}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 14, color: AppColors.walnutMuted.withValues(alpha: 0.8)),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.total});
  final int total;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(l10n.tr('follow_done_title'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l10n.tr('follow_done_subtitle', {'n': '$total'}),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: filled
              ? (disabled ? AppColors.peach : AppColors.coral)
              : AppColors.card,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 32, color: filled ? Colors.white : AppColors.walnutSoft),
      ),
    );
  }
}
