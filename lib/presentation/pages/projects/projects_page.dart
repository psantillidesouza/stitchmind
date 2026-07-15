import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_mind_logo.dart';
import '../../widgets/yarn_swatch.dart';

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  ProjectStatus _tab = ProjectStatus.inProgress;

  @override
  Widget build(BuildContext context) {
    final filtered = ref.watch(projectsByStatusProvider(_tab));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Projetos',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.terracotta,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: AppColors.paper),
                    onPressed: () => context.push('/projects/new'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: ProjectStatus.values.map((s) {
                final selected = s == _tab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _tab = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            selected ? AppColors.walnut : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              selected ? AppColors.walnut : AppColors.linen,
                        ),
                      ),
                      child: Text(
                        s.labelPt,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: selected
                              ? AppColors.paper
                              : AppColors.walnut,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(status: _tab)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _ProjectCard(project: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/projects/${project.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              YarnSwatch(
                seed: project.id,
                technique: project.technique,
                size: 72,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.yarn.isEmpty ? '—' : project.yarn,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${project.technique.labelPt}'
                      '${project.needle.isEmpty ? '' : ' · agulha ${project.needle}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (project.status != ProjectStatus.finished) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: project.progress,
                          minHeight: 4,
                          backgroundColor: AppColors.linen,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.terracotta,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'carreira ${project.currentRow}'
                        '${project.targetRow == null ? '' : ' de ${project.targetRow}'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.status});
  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final msg = switch (status) {
      ProjectStatus.inProgress => 'Nada em andamento ainda.',
      ProjectStatus.paused => 'Nenhum projeto pausado.',
      ProjectStatus.finished => 'Nenhum projeto concluído.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StitchMindLogo(size: 72),
            const SizedBox(height: 20),
            Text(msg, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              status == ProjectStatus.inProgress
                  ? 'Crie um projeto pra começar a tricotar.'
                  : 'Nada por aqui — ainda.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (status == ProjectStatus.inProgress)
              FilledButton.icon(
                onPressed: () => GoRouter.of(context).push('/projects/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Criar primeiro projeto'),
              ),
          ],
        ),
      ),
    );
  }
}
