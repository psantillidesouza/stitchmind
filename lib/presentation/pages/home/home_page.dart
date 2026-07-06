import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';
import '../../widgets/fade_in.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stitch_mind_logo.dart';
import '../../widgets/yarn_swatch.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(projectsByStatusProvider(ProjectStatus.inProgress));

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const FadeIn(child: _Greeting()),
          const SizedBox(height: 8),
          const FadeIn(
            delay: Duration(milliseconds: 80),
            child: _QuickActions(),
          ),
          const FadeIn(
            delay: Duration(milliseconds: 140),
            child: _AnalyzeBanner(),
          ),
          FadeIn(
            delay: const Duration(milliseconds: 160),
            child: SectionHeader(
              title: 'Em andamento',
              action: active.isEmpty ? null : 'ver tudo',
              onActionTap: () => context.go('/projects'),
            ),
          ),
          if (active.isEmpty)
            const FadeIn(
              delay: Duration(milliseconds: 220),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: _EmptyInline(),
              ),
            )
          else
            ...active.take(3).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return FadeIn(
                delay: Duration(milliseconds: 220 + i * 60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: _ActiveProjectCard(project: p),
                ),
              );
            }),
          const FadeIn(
            delay: Duration(milliseconds: 360),
            child: SectionHeader(title: 'Dica do dia'),
          ),
          const FadeIn(
            delay: Duration(milliseconds: 420),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _TipCard(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  String _hourGreeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Boa madrugada,';
    if (h < 12) return 'Bom dia,';
    if (h < 18) return 'Boa tarde,';
    return 'Boa noite,';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_hourGreeting(), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'pronta para tricotar?',
            style: Theme.of(context).textTheme.displayMedium,
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active =
        ref.watch(projectsByStatusProvider(ProjectStatus.inProgress));
    final firstId = active.isEmpty ? null : active.first.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.add,
              label: 'Novo projeto',
              primary: true,
              onTap: () => context.push('/projects/new'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickAction(
              icon: Icons.bolt_outlined,
              label: 'Contador rápido',
              onTap: firstId == null
                  ? null
                  : () => context.push('/counter/$firstId'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg = primary ? AppColors.terracotta : AppColors.paper;
    final fg = primary
        ? AppColors.paper
        : (disabled ? AppColors.walnutMuted : AppColors.walnut);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.linen),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: fg,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyzeBanner extends StatelessWidget {
  const _AnalyzeBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: InkWell(
        onTap: () => context.push('/analyze'),
        borderRadius: BorderRadius.circular(AppRadii.card),
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
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.paper.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.paper,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANÁLISE POR IA',
                      style: AppText.eyebrow.copyWith(color: AppColors.ochre),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Identifique pontos por foto.',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: AppColors.paper),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.paper,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveProjectCard extends StatelessWidget {
  const _ActiveProjectCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => context.push('/projects/${project.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              YarnSwatch(
                seed: project.id,
                technique: project.technique,
                size: 64,
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
                      '${project.technique.labelPt} · ${project.yarn}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
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
                        ),
                        const SizedBox(width: 10),
                        Text(
                          project.targetRow == null
                              ? '${project.currentRow}'
                              : '${project.currentRow}/${project.targetRow}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.walnut,
                          ),
                        ),
                      ],
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

class _EmptyInline extends StatelessWidget {
  const _EmptyInline();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.linen),
      ),
      child: Row(
        children: [
          const StitchMindLogo(size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tudo pronto.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  'Crie seu primeiro projeto pra começar.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.linen.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tensão do fio',
            style: AppText.eyebrow.copyWith(color: AppColors.terracottaDeep),
          ),
          const SizedBox(height: 8),
          Text(
            'Antes de iniciar um projeto novo, faça sempre uma amostra de '
            '10×10 cm para conferir se seu ponto está com a tensão correta.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
