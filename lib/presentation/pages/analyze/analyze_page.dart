import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/media/image_pipeline.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/entities/ai_analysis.dart';
import '../../providers/providers.dart';
import '../../providers/platform_providers.dart';
import '../../providers/saved_lessons_provider.dart';
import '../../widgets/gradient_bg.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/stitch_mind_logo.dart';

enum _Stage { idle, picking, loading, result, error }

class AnalyzePage extends ConsumerStatefulWidget {
  const AnalyzePage({super.key});

  @override
  ConsumerState<AnalyzePage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends ConsumerState<AnalyzePage> {
  _Stage _stage = _Stage.idle;
  File? _image;
  AiAnalysis? _analysis;
  String? _errorMsg;

  Future<void> _pickFromCamera() => _pick(ImageSource.camera);
  Future<void> _pickFromGallery() => _pick(ImageSource.gallery);

  Future<void> _pick(ImageSource source) async {
    setState(() => _stage = _Stage.picking);
    // Converte a foto para WebP no aparelho antes de enviar.
    final file = await ImagePipeline.pick(source, maxWidth: 1568, quality: 88);
    if (file == null) {
      setState(() => _stage = _Stage.idle);
      return;
    }
    setState(() {
      _image = file;
      _stage = _Stage.loading;
      _errorMsg = null;
    });
    await _analyze();
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    ref.read(analyticsServiceProvider).logAnalyzePhoto();
    try {
      final result =
          await ref.read(analysisServiceProvider).analyzeImage(_image!);
      await ref.read(analysisRepositoryProvider).save(result);
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _stage = _Stage.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString();
        _stage = _Stage.error;
      });
    }
  }

  void _reset() {
    setState(() {
      _stage = _Stage.idle;
      _image = null;
      _analysis = null;
      _errorMsg = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(context.l10n.tr('analyze_appbar_title')),
        ),
        body: SafeArea(
          child: PremiumGate(
            title: context.l10n.tr('analyze_gate_title'),
            subtitle: context.l10n.tr('analyze_gate_subtitle'),
            image: 'assets/illustrations/analyze.png',
            child: _buildStage(),
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _Stage.idle:
      case _Stage.picking:
        return _IdleView(
          onCamera: _pickFromCamera,
          onGallery: _pickFromGallery,
        );
      case _Stage.loading:
        return _LoadingView(image: _image!);
      case _Stage.error:
        return _ErrorView(
          message: _errorMsg ?? context.l10n.tr('analyze_error_unknown'),
          onRetry: _reset,
        );
      case _Stage.result:
        return _ResultView(
          analysis: _analysis!,
          image: _image!,
          onReset: _reset,
        );
    }
  }
}

// ─── Idle ─────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onCamera, required this.onGallery});
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Center(
          child: Image.asset(
            'assets/illustrations/analyze.png',
            height: 188,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const StitchMindLogo(size: 96),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.tr('analyze_idle_title'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.tr('analyze_idle_subtitle'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.walnutSoft,
                height: 1.55,
              ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.linen.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.walnutSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.tr('analyze_idle_info'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: onCamera,
          icon: const Icon(Icons.camera_alt_outlined),
          label: Text(context.l10n.tr('analyze_btn_take_photo')),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onGallery,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(context.l10n.tr('analyze_btn_gallery')),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
        ),
      ],
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.image});
  final File image;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(
              image,
              width: double.infinity,
              height: 260,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const Spacer(),
        const CircularProgressIndicator(
          color: AppColors.terracotta,
          strokeWidth: 2.5,
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.tr('analyze_loading_title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            context.l10n.tr('analyze_loading_subtitle'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.terracottaDeep,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.tr('analyze_error_title'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.tr('analyze_error_hint'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onRetry,
            child: Text(context.l10n.tr('analyze_btn_retry')),
          ),
        ],
      ),
    );
  }
}

// ─── Result ───────────────────────────────────────────────────────────────

class _ResultView extends ConsumerWidget {
  const _ResultView({
    required this.analysis,
    required this.image,
    required this.onReset,
  });

  final AiAnalysis analysis;
  final File image;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            image,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 20),
        // Resumo: técnica + tipo de peça
        Text(
          context.l10n.tr('analyze_result_summary', {
            'tech': _techLabel(context, analysis.tier1.technique),
            'piece': analysis.tier1.pieceType,
          }),
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 12),
        const _Disclaimer(),
        const SizedBox(height: 20),
        _Tier1Card(tier1: analysis.tier1, analysisId: analysis.id),
        const SizedBox(height: 12),
        _Tier2Card(tier2: analysis.tier2, analysisId: analysis.id),
        const SizedBox(height: 12),
        _Tier3Card(tier3: analysis.tier3, analysisId: analysis.id),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: () => _saveAsLesson(context, ref),
          icon: const Icon(Icons.bookmark_add_rounded),
          label: Text(context.l10n.tr('analyze_btn_save_lesson')),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.camera_alt_rounded),
          label: Text(context.l10n.tr('analyze_btn_analyze_another')),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
        ),
      ],
    );
  }

  String _techLabel(BuildContext context, String tech) => tech == 'knit'
      ? context.l10n.tr('analyze_tech_knit')
      : context.l10n.tr('analyze_tech_crochet');

  /// Gera uma aula (markdown) a partir da análise e salva — igual ao chat.
  Future<void> _saveAsLesson(BuildContext context, WidgetRef ref) async {
    final md = _toLessonMarkdown(context, analysis);
    final saved = await ref
        .read(savedLessonsProvider.notifier)
        .saveMarkdown(md, imagePath: image.path);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(saved
            ? context.l10n.tr('analyze_snack_saved')
            : context.l10n.tr('analyze_snack_already_saved')),
        backgroundColor: AppColors.walnut,
        behavior: SnackBarBehavior.floating,
      ));
  }

  String _toLessonMarkdown(BuildContext context, AiAnalysis a) {
    final l10n = context.l10n;
    final tech = _techLabel(context, a.tier1.technique);
    final b = StringBuffer()
      ..writeln('# $tech · ${a.tier1.pieceType}')
      ..writeln('${l10n.tr('analyze_md_intro')}\n')
      ..writeln(l10n.tr('analyze_md_materials_header'))
      ..writeln(l10n.tr('analyze_md_yarn', {'value': a.tier1.estimatedYarn}));
    if (a.tier1.colorPalette.isNotEmpty) {
      b.writeln(l10n.tr(
        'analyze_md_palette',
        {'value': a.tier1.colorPalette.join(' · ')},
      ));
    }
    if (a.tier2.suggestedNeedleMm != null) {
      b.writeln(l10n.tr(
        'analyze_md_needle',
        {'value': '${a.tier2.suggestedNeedleMm}'},
      ));
    }
    if (a.tier2.estimatedYarnGrams != null) {
      b.writeln(l10n.tr(
        'analyze_md_yarn_grams',
        {'value': '${a.tier2.estimatedYarnGrams}'},
      ));
    }
    if (a.tier2.estimatedDimensionsCm.length == 2) {
      b.writeln(l10n.tr('analyze_md_dimension', {
        'w': a.tier2.estimatedDimensionsCm[0].toStringAsFixed(0),
        'h': a.tier2.estimatedDimensionsCm[1].toStringAsFixed(0),
      }));
    }
    if (a.tier2.estimatedHours != null) {
      b.writeln(l10n.tr(
        'analyze_md_hours',
        {'value': '${a.tier2.estimatedHours}'},
      ));
    }
    b.writeln(l10n.tr(
      'analyze_md_difficulty',
      {'value': _difficultyLabelStatic(context, a.tier2.estimatedDifficulty)},
    ));
    if (a.tier1.mainStitches.isNotEmpty) {
      b.writeln('\n${l10n.tr('analyze_md_stitches_header')}');
      for (final s in a.tier1.mainStitches) {
        b.writeln('- **${s.abbrev}** — ${s.namePt}');
      }
    }
    if (a.tier2.structureNotes.trim().isNotEmpty) {
      b.writeln('\n${l10n.tr('analyze_md_structure_header')}');
      b.writeln(a.tier2.structureNotes.trim());
    }
    b.writeln('\n${l10n.tr('analyze_md_steps_header')}');
    if (a.tier3.warning.trim().isNotEmpty) {
      b.writeln('> ⚠️ ${a.tier3.warning.trim()}\n');
    }
    for (final sec in a.tier3.sections) {
      b.writeln('\n### ${sec.title}');
      for (final r in sec.rows) {
        final count = r.stitchCount != null
            ? ' ${l10n.tr('analyze_md_stitch_count', {'n': '${r.stitchCount}'})}'
            : '';
        b.writeln('${r.row}. ${r.instruction}$count');
      }
    }
    return b.toString().trim();
  }

  String _difficultyLabelStatic(BuildContext context, String d) => switch (d) {
        'beginner' => context.l10n.tr('analyze_difficulty_beginner'),
        'intermediate' => context.l10n.tr('analyze_difficulty_intermediate'),
        'advanced' => context.l10n.tr('analyze_difficulty_advanced'),
        _ => d,
      };
}

/// Aviso de que a IA pode errar dependendo da foto.
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.linen.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.walnutSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.tr('analyze_disclaimer'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tier cards ───────────────────────────────────────────────────────────

class _TierCard extends StatefulWidget {
  const _TierCard({
    required this.eyebrow,
    required this.title,
    required this.child,
    required this.analysisId,
    required this.section,
    this.initiallyOpen = true,
  });

  final String eyebrow;
  final String title;
  final Widget child;
  final String analysisId;
  final String section;
  final bool initiallyOpen;

  @override
  State<_TierCard> createState() => _TierCardState();
}

class _TierCardState extends State<_TierCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: softShadow(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.eyebrow.toUpperCase(),
                          style: AppText.eyebrow.copyWith(color: AppColors.terracottaDeep),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
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
              child: widget.child,
            ),
            _FeedbackRow(
              analysisId: widget.analysisId,
              section: widget.section,
            ),
          ],
        ],
      ),
    );
  }
}

class _Tier1Card extends StatelessWidget {
  const _Tier1Card({required this.tier1, required this.analysisId});
  final Tier1Identification tier1;
  final String analysisId;

  @override
  Widget build(BuildContext context) {
    return _TierCard(
      eyebrow: context.l10n.tr('analyze_tier1_eyebrow'),
      title: context.l10n.tr('analyze_tier1_title', {
        'tech': tier1.technique == 'knit'
            ? context.l10n.tr('analyze_tech_knit')
            : context.l10n.tr('analyze_tech_crochet'),
        'piece': tier1.pieceType,
      }),
      analysisId: analysisId,
      section: 'tier1',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabeledLine(
            label: context.l10n.tr('analyze_label_estimated_yarn'),
            value: tier1.estimatedYarn,
          ),
          if (tier1.colorPalette.isNotEmpty) ...[
            const SizedBox(height: 8),
            _LabeledLine(
              label: context.l10n.tr('analyze_label_palette'),
              value: tier1.colorPalette.join(' · '),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            context.l10n.tr('analyze_tier1_stitches_label'),
            style: AppText.eyebrow.copyWith(color: AppColors.walnutMuted),
          ),
          const SizedBox(height: 8),
          ...tier1.mainStitches.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.linen.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s.abbrev,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.walnut,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.namePt,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tier2Card extends StatelessWidget {
  const _Tier2Card({required this.tier2, required this.analysisId});
  final Tier2Analysis tier2;
  final String analysisId;

  @override
  Widget build(BuildContext context) {
    return _TierCard(
      eyebrow: context.l10n.tr('analyze_tier2_eyebrow'),
      title: context.l10n.tr('analyze_tier2_title'),
      analysisId: analysisId,
      section: 'tier2',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tier2.structureNotes.trim().isNotEmpty) ...[
            Text(
              tier2.structureNotes,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
          ],
          if (tier2.estimatedDimensionsCm.length == 2)
            _LabeledLine(
              label: context.l10n.tr('analyze_label_estimated_dimension'),
              value: context.l10n.tr('analyze_value_dimension', {
                'w': tier2.estimatedDimensionsCm[0].toStringAsFixed(0),
                'h': tier2.estimatedDimensionsCm[1].toStringAsFixed(0),
              }),
            ),
          if (tier2.estimatedYarnGrams != null)
            _LabeledLine(
              label: context.l10n.tr('analyze_label_estimated_yarn_grams'),
              value: context.l10n.tr(
                'analyze_value_grams',
                {'n': '${tier2.estimatedYarnGrams}'},
              ),
            ),
          if (tier2.suggestedNeedleMm != null)
            _LabeledLine(
              label: context.l10n.tr('analyze_label_suggested_needle'),
              value: context.l10n.tr(
                'analyze_value_needle_mm',
                {'n': '${tier2.suggestedNeedleMm}'},
              ),
            ),
          _LabeledLine(
            label: context.l10n.tr('analyze_label_difficulty'),
            value: _difficultyLabel(context, tier2.estimatedDifficulty),
          ),
          if (tier2.estimatedHours != null)
            _LabeledLine(
              label: context.l10n.tr('analyze_label_estimated_time'),
              value: context.l10n.tr(
                'analyze_value_hours',
                {'n': '${tier2.estimatedHours}'},
              ),
            ),
        ],
      ),
    );
  }

  String _difficultyLabel(BuildContext context, String d) {
    switch (d) {
      case 'beginner':
        return context.l10n.tr('analyze_difficulty_beginner');
      case 'intermediate':
        return context.l10n.tr('analyze_difficulty_intermediate');
      case 'advanced':
        return context.l10n.tr('analyze_difficulty_advanced');
      default:
        return d;
    }
  }
}

class _Tier3Card extends StatelessWidget {
  const _Tier3Card({required this.tier3, required this.analysisId});
  final Tier3DraftPattern tier3;
  final String analysisId;

  @override
  Widget build(BuildContext context) {
    return _TierCard(
      eyebrow: context.l10n.tr('analyze_tier3_eyebrow'),
      title: context.l10n.tr('analyze_tier3_title', {
        'sections': '${tier3.sections.length}',
        'rows': '${tier3.totalRows}',
      }),
      analysisId: analysisId,
      section: 'tier3',
      initiallyOpen: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tier3.warning.trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.terracotta.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.terracotta.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.terracottaDeep,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tier3.warning,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.terracottaDeep,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          ...tier3.sections.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _SectionView(section: s),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});
  final DraftSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title.trim().isNotEmpty) ...[
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
        ],
        ...section.rows.map(
          (r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${r.row}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
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
                        r.instruction,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (r.stitchCount != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.tr(
                            'analyze_stitch_count',
                            {'n': '${r.stitchCount}'},
                          ),
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
      ],
    );
  }
}

class _LabeledLine extends StatelessWidget {
  const _LabeledLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
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
      ),
    );
  }
}

// ─── Feedback ─────────────────────────────────────────────────────────────

class _FeedbackRow extends ConsumerStatefulWidget {
  const _FeedbackRow({required this.analysisId, required this.section});
  final String analysisId;
  final String section;

  @override
  ConsumerState<_FeedbackRow> createState() => _FeedbackRowState();
}

class _FeedbackRowState extends ConsumerState<_FeedbackRow> {
  String? _sent;

  Future<void> _send(String rating) async {
    setState(() => _sent = rating);
    try {
      await ref.read(analysisServiceProvider).sendFeedback(
            analysisId: widget.analysisId,
            section: widget.section,
            rating: rating,
          );
    } catch (_) {
      // Falha silenciosa — feedback é best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.linen)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check, size: 14, color: AppColors.sage),
            const SizedBox(width: 6),
            Text(
              context.l10n.tr('analyze_feedback_thanks'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.linen)),
      ),
      child: Row(
        children: [
          Text(
            context.l10n.tr('analyze_feedback_question'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          _FeedbackButton(
            label: context.l10n.tr('analyze_feedback_wrong'),
            icon: Icons.close,
            onTap: () => _send('wrong'),
          ),
          _FeedbackButton(
            label: context.l10n.tr('analyze_feedback_partial'),
            icon: Icons.remove,
            onTap: () => _send('partial'),
          ),
          _FeedbackButton(
            label: context.l10n.tr('analyze_feedback_correct'),
            icon: Icons.check,
            onTap: () => _send('correct'),
          ),

        ],
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.walnutSoft,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
      ),
    );
  }
}
