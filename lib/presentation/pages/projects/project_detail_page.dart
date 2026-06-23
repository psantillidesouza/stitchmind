import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/yarn_swatch.dart';

class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({required this.projectId, super.key});
  final String projectId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir projeto?'),
        content: const Text(
          'Esta ação não pode ser desfeita. O contador e as notas serão perdidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.terracottaDeep,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(projectActionsProvider).delete(projectId);
      if (context.mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectByIdProvider(projectId));

    if (project == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Projeto não encontrado.')),
      );
    }

    final actions = ref.read(projectActionsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) async {
              switch (value) {
                case 'pause':
                  await actions.setStatus(projectId, ProjectStatus.paused);
                case 'resume':
                  await actions.setStatus(
                      projectId, ProjectStatus.inProgress);
                case 'finish':
                  await actions.setStatus(
                      projectId, ProjectStatus.finished);
                case 'delete':
                  if (context.mounted) await _confirmDelete(context, ref);
              }
            },
            itemBuilder: (_) => [
              if (project.status == ProjectStatus.inProgress)
                const PopupMenuItem(value: 'pause', child: Text('Pausar')),
              if (project.status == ProjectStatus.paused)
                const PopupMenuItem(value: 'resume', child: Text('Retomar')),
              if (project.status != ProjectStatus.finished)
                const PopupMenuItem(
                  value: 'finish',
                  child: Text('Marcar como concluído'),
                ),
              const PopupMenuItem(value: 'delete', child: Text('Excluir')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
          children: [
            Center(
              child: YarnSwatch(
                seed: project.id,
                technique: project.technique,
                size: 160,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              project.name,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  project.technique.labelPt,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: project.status),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.linen),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'progresso',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${(project.progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.walnut,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: project.progress,
                      minHeight: 6,
                      backgroundColor: AppColors.linen,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.terracotta,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Stat(
                        label: 'carreira',
                        value: '${project.currentRow}',
                      ),
                      const _StatDivider(),
                      _Stat(
                        label: 'meta',
                        value: '${project.targetRow ?? '—'}',
                      ),
                      const _StatDivider(),
                      _Stat(
                        label: 'dias',
                        value: '${DateTime.now().difference(project.startedAt).inDays}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: project.status == ProjectStatus.finished
                  ? null
                  : () => context.push('/counter/${project.id}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: const Text('Abrir contador'),
            ),
            if (project.patternId != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/follow/${project.patternId}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.playlist_play_rounded),
                label: const Text('Seguir receita'),
              ),
              const SizedBox(height: 24),
              _PatternLink(patternId: project.patternId!),
            ],
            const SizedBox(height: 32),
            Text(
              'Detalhes',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Linha',
              value: project.yarn.isEmpty ? '—' : project.yarn,
            ),
            _DetailRow(
              label: 'Agulha',
              value: project.needle.isEmpty ? '—' : project.needle,
            ),
            _DetailRow(
              label: 'Iniciado em',
              value: '${project.startedAt.day.toString().padLeft(2, '0')}/'
                  '${project.startedAt.month.toString().padLeft(2, '0')}/'
                  '${project.startedAt.year}',
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternLink extends ConsumerWidget {
  const _PatternLink({required this.patternId});
  final String patternId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(patternByIdProvider(patternId));
    return async.maybeWhen(
      data: (pattern) {
        if (pattern == null) return const SizedBox.shrink();
        return InkWell(
          onTap: () => context.push('/patterns/$patternId'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.linen),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book,
                  size: 18,
                  color: AppColors.terracotta,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SEGUINDO A RECEITA',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: AppColors.terracottaDeep,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pattern.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.walnutMuted,
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ProjectStatus.inProgress => AppColors.sage,
      ProjectStatus.paused => AppColors.ochre,
      ProjectStatus.finished => AppColors.walnutSoft,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.labelPt,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.walnut,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: AppColors.linen);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
