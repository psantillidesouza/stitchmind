import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/markers_sheet.dart';

class CounterPage extends ConsumerStatefulWidget {
  const CounterPage({required this.projectId, super.key});
  final String projectId;

  @override
  ConsumerState<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends ConsumerState<CounterPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bumpCtrl;
  final List<int> _undoStack = [];

  @override
  void initState() {
    super.initState();
    _bumpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _bumpCtrl.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _bump(int delta) async {
    final project = ref.read(projectByIdProvider(widget.projectId));
    if (project == null) return;
    final previous = project.currentRow;
    final next = (previous + delta).clamp(0, 1 << 30);
    if (next == previous) return;

    _undoStack.add(previous);
    if (_undoStack.length > 30) _undoStack.removeAt(0);

    await ref
        .read(projectActionsProvider)
        .setRow(widget.projectId, next);

    if (delta > 0) {
      // Did we just hit a marker?
      final hitMarker = project.markers
          .where((m) => !m.done && m.row == next)
          .isNotEmpty;
      if (hitMarker) {
        HapticFeedback.heavyImpact();
        _bumpCtrl.forward(from: 0);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                backgroundColor: AppColors.walnut,
                content: Text(
                  project.markers
                      .firstWhere((m) => m.row == next)
                      .note
                      .ifEmpty('Marcador atingido'),
                  style: const TextStyle(color: AppColors.paper),
                ),
              ),
            );
        }
      } else {
        HapticFeedback.mediumImpact();
        _bumpCtrl.forward(from: 0);
      }
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    await ref
        .read(projectActionsProvider)
        .setRow(widget.projectId, previous);
    HapticFeedback.selectionClick();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectByIdProvider(widget.projectId));

    if (project == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Projeto não encontrado.')),
      );
    }

    final next = project.nextMarker;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(
          project.name,
          style: Theme.of(context).textTheme.titleLarge,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Desfazer',
            icon: Icon(
              Icons.undo,
              color: _undoStack.isEmpty
                  ? AppColors.walnutMuted
                  : AppColors.walnut,
            ),
            onPressed: _undoStack.isEmpty ? null : _undo,
          ),
          IconButton(
            tooltip: 'Marcadores',
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () => MarkersSheet.show(context, widget.projectId),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (v) async {
              if (v == 'reset') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Zerar carreira?'),
                    content: const Text(
                      'O contador voltará para 0. O projeto não é apagado.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(true),
                        child: const Text('Zerar'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  _undoStack.add(project.currentRow);
                  await ref
                      .read(projectActionsProvider)
                      .setRow(widget.projectId, 0);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('Zerar contador')),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _bump(1),
        onLongPress: () => _bump(-1),
        child: SafeArea(
          child: Column(
            children: [
              if (project.patternId != null)
                _PatternHint(
                  patternId: project.patternId!,
                  row: project.currentRow,
                ),
              const Spacer(),
              const Text(
                'CARREIRA ATUAL',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppColors.walnutMuted,
                ),
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _bumpCtrl,
                builder: (_, child) {
                  final scale = 1 +
                      (Curves.easeOutBack.transform(_bumpCtrl.value) - 1) *
                          0.06;
                  return Transform.scale(scale: scale, child: child);
                },
                child: Text(
                  '${project.currentRow}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 180,
                    fontWeight: FontWeight.w600,
                    color: AppColors.walnut,
                    height: 1,
                    letterSpacing: -4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (project.targetRow != null)
                Text(
                  'de ${project.targetRow}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    color: AppColors.walnutSoft,
                  ),
                ),
              const SizedBox(height: 24),
              if (next != null) _NextMarker(marker: next, current: project.currentRow),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(
                  'toque em qualquer lugar para somar  ·  segure para diminuir',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _bump(-1),
                        icon: const Icon(Icons.remove, size: 18),
                        label: const Text('−1'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => _bump(1),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Próxima carreira'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextMarker extends StatelessWidget {
  const _NextMarker({required this.marker, required this.current});
  final Marker marker;
  final int current;

  @override
  Widget build(BuildContext context) {
    final delta = marker.row - current;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.linen.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.bookmark, size: 16, color: AppColors.terracotta),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'em $delta '
              '${delta == 1 ? 'carreira' : 'carreiras'}: '
              '${marker.note.isEmpty ? 'marcador na carreira ${marker.row}' : marker.note}',
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternHint extends ConsumerWidget {
  const _PatternHint({required this.patternId, required this.row});
  final String patternId;
  final int row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(patternByIdProvider(patternId));
    return async.maybeWhen(
      data: (pattern) {
        if (pattern == null) return const SizedBox.shrink();
        final instr = _instructionFor(pattern, row);
        if (instr == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.linen),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                instr.$1.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.terracottaDeep,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                instr.$2,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  (String, String)? _instructionFor(Pattern p, int row) {
    if (row == 0) return null;
    for (final section in p.sections) {
      for (final r in section.rows) {
        if (r.row == row) return (section.title, r.instruction);
      }
    }
    return null;
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
