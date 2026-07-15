import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/ai_analysis.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/providers.dart';

class NewProjectPage extends ConsumerStatefulWidget {
  const NewProjectPage({this.patternId, this.analysisId, super.key});
  final String? patternId;
  final String? analysisId;

  @override
  ConsumerState<NewProjectPage> createState() => _NewProjectPageState();
}

class _NewProjectPageState extends ConsumerState<NewProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _yarn = TextEditingController();
  final _needle = TextEditingController();
  final _target = TextEditingController();
  StitchTechnique _technique = StitchTechnique.crochet;
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    _yarn.dispose();
    _needle.dispose();
    _target.dispose();
    super.dispose();
  }

  void _applyPattern(Pattern p) {
    if (_prefilled) return;
    _prefilled = true;
    _name.text = p.name;
    _yarn.text = p.yarnRequirement;
    if (p.suggestedNeedle != null) _needle.text = p.suggestedNeedle!;
    _target.text = '${p.totalRows}';
    setState(() => _technique = p.technique);
  }

  void _applyAnalysis(AiAnalysis a) {
    if (_prefilled) return;
    _prefilled = true;
    _name.text = a.tier1.pieceType;
    _yarn.text = a.tier1.estimatedYarn;
    if (a.tier2.suggestedNeedleMm != null) {
      _needle.text = '${a.tier2.suggestedNeedleMm} mm';
    }
    final rows = a.tier3.totalRows;
    if (rows > 0) _target.text = '$rows';
    setState(() {
      _technique = a.tier1.technique == 'knit'
          ? StitchTechnique.knit
          : StitchTechnique.crochet;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final target = int.tryParse(_target.text.trim());
    final project = Project(
      id: const Uuid().v4(),
      name: _name.text.trim(),
      technique: _technique,
      yarn: _yarn.text.trim(),
      needle: _needle.text.trim(),
      status: ProjectStatus.inProgress,
      currentRow: 0,
      targetRow: target,
      startedAt: DateTime.now(),
      patternId: widget.patternId,
    );
    await ref.read(projectActionsProvider).save(project);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.patternId != null) {
      ref.listen(patternByIdProvider(widget.patternId!), (_, next) {
        next.whenData((p) {
          if (p != null) _applyPattern(p);
        });
      });
      ref.watch(patternByIdProvider(widget.patternId!)).whenData((p) {
        if (p != null) _applyPattern(p);
      });
    }
    if (widget.analysisId != null && !_prefilled) {
      final analysis = ref.read(analysisByIdProvider(widget.analysisId!));
      if (analysis != null) _applyAnalysis(analysis);
    }

    final fromAi = widget.analysisId != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.patternId != null
              ? 'Novo projeto · receita'
              : fromAi
                  ? 'Novo projeto · análise IA'
                  : 'Novo projeto',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
            children: [
              if (widget.patternId != null || fromAi)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.linen.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        fromAi ? Icons.auto_awesome : Icons.menu_book,
                        size: 18,
                        color: AppColors.walnutSoft,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          fromAi
                              ? 'Campos pré-preenchidos a partir da análise por IA. '
                                  'A análise é uma estimativa — ajuste antes de criar.'
                              : 'Campos pré-preenchidos com a receita. '
                                  'Ajuste o que quiser antes de criar.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              const _Label('Técnica'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TechCard(
                      label: 'Crochê',
                      selected: _technique == StitchTechnique.crochet,
                      onTap: () => setState(
                          () => _technique = StitchTechnique.crochet),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TechCard(
                      label: 'Tricô',
                      selected: _technique == StitchTechnique.knit,
                      onTap: () => setState(
                          () => _technique = StitchTechnique.knit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _Label('Nome do projeto'),
              const SizedBox(height: 8),
              _Input(
                controller: _name,
                hint: 'ex: Cardigã ocre',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Dê um nome' : null,
                autofocus: widget.patternId == null,
              ),
              const SizedBox(height: 20),
              const _Label('Linha'),
              const SizedBox(height: 8),
              _Input(
                controller: _yarn,
                hint: 'marca, composição, cor',
              ),
              const SizedBox(height: 20),
              const _Label('Agulha'),
              const SizedBox(height: 8),
              _Input(controller: _needle, hint: 'ex: 4,5 mm'),
              const SizedBox(height: 20),
              const _Label('Meta de carreiras (opcional)'),
              const SizedBox(height: 8),
              _Input(
                controller: _target,
                hint: 'ex: 120',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: const Text('Criar projeto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppText.eyebrow.copyWith(color: AppColors.terracottaDeep),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    this.validator,
    this.autofocus = false,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final bool autofocus;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      autofocus: autofocus,
      keyboardType: keyboardType,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.walnutMuted,
        ),
        filled: true,
        fillColor: AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.linen),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.walnut, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.terracottaDeep),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.terracottaDeep,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TechCard extends StatelessWidget {
  const _TechCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.walnut : AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: selected ? AppColors.walnut : AppColors.linen,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.paper : AppColors.walnut,
          ),
        ),
      ),
    );
  }
}
