import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/entities.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/imported_patterns_provider.dart';
import '../../providers/platform_providers.dart';

enum _Mode { text, link, photo, pdf }

/// Importa uma receita (texto colado ou link) → IA estrutura → preview →
/// salvar. Fase 1 do recurso "Importar receita".
class ImportPatternPage extends ConsumerStatefulWidget {
  const ImportPatternPage({super.key});

  @override
  ConsumerState<ImportPatternPage> createState() => _ImportPatternPageState();
}

class _ImportPatternPageState extends ConsumerState<ImportPatternPage> {
  _Mode _mode = _Mode.text;
  final _input = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _previewJson;
  Pattern? _preview;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Bloqueia se não for assinante. Devolve `true` se pode prosseguir.
  bool _gate() {
    if (ref.read(subscriptionServiceProvider).isSubscribed) return true;
    context.push('/paywall');
    return false;
  }

  Future<void> _import() async {
    final raw = _input.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = context.l10n.tr('import_empty_input'));
      return;
    }
    if (!_gate()) return;
    FocusScope.of(context).unfocus();
    final service = ref.read(patternImportServiceProvider);
    await _run(() => _mode == _Mode.text
        ? service.importText(raw)
        : service.importUrl(raw));
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (!_gate()) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 88);
    if (picked == null) return;
    final service = ref.read(patternImportServiceProvider);
    await _run(() => service.importFile(picked.path));
  }

  Future<void> _pickPdf() async {
    if (!_gate()) return;
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    final path = res?.files.single.path;
    if (path == null) return;
    final service = ref.read(patternImportServiceProvider);
    await _run(() => service.importFile(path));
  }

  /// Executa uma importação, controlando loading/erro/preview.
  Future<void> _run(Future<Map<String, dynamic>> Function() task) async {
    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
      _previewJson = null;
    });
    try {
      final json = await task();
      if (!mounted) return;
      setState(() {
        _previewJson = json;
        _preview = Pattern.fromJson(json);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${context.l10n.tr('import_error')} $e';
      });
    }
  }

  Future<void> _save() async {
    final json = _previewJson;
    if (json == null) return;
    final saved = await ref.read(importedPatternsProvider.notifier).save(json);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.tr('import_saved'))),
    );
    // Salvou → já abre o Modo Seguir Receita (fecha o ciclo).
    context.pushReplacement('/follow/${saved.id}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.tr('import_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(l10n.tr('import_subtitle'),
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            _ModeToggle(
              mode: _mode,
              onChanged: (m) => setState(() {
                _mode = m;
                _error = null;
              }),
            ),
            const SizedBox(height: 14),
            // Entrada por fonte.
            if (_mode == _Mode.text || _mode == _Mode.link)
              TextField(
                controller: _input,
                minLines: _mode == _Mode.text ? 6 : 1,
                maxLines: _mode == _Mode.text ? 14 : 1,
                keyboardType: _mode == _Mode.text
                    ? TextInputType.multiline
                    : TextInputType.url,
                autocorrect: _mode == _Mode.text,
                textInputAction: _mode == _Mode.link
                    ? TextInputAction.go
                    : TextInputAction.newline,
                onSubmitted: (_) {
                  if (_mode == _Mode.link) _import();
                },
                decoration: InputDecoration(
                  hintText: l10n.tr(_mode == _Mode.text
                      ? 'import_text_hint'
                      : 'import_link_hint'),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              )
            else if (_mode == _Mode.photo)
              Column(
                children: [
                  _PickButton(
                    icon: Icons.camera_alt_rounded,
                    label: l10n.tr('import_photo_camera'),
                    onTap: _loading ? null : () => _pickPhoto(ImageSource.camera),
                  ),
                  const SizedBox(height: 10),
                  _PickButton(
                    icon: Icons.photo_library_rounded,
                    label: l10n.tr('import_photo_gallery'),
                    onTap:
                        _loading ? null : () => _pickPhoto(ImageSource.gallery),
                  ),
                ],
              )
            else
              _PickButton(
                icon: Icons.picture_as_pdf_rounded,
                label: l10n.tr('import_pick_pdf'),
                onTap: _loading ? null : _pickPdf,
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppColors.coral, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            // CTA: texto/link tem botão "Importar"; foto/PDF importam ao escolher.
            if (_mode == _Mode.text || _mode == _Mode.link)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _loading ? null : _import,
                child: _loading
                    ? _LoadingRow(label: l10n.tr('import_loading'))
                    : Text(l10n.tr('import_cta')),
              )
            else if (_loading)
              _LoadingRow(label: l10n.tr('import_loading'), dark: true),
            if (_preview != null) ...[
              const SizedBox(height: 28),
              _PatternPreview(pattern: _preview!),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sage,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.bookmark_added_rounded),
                label: Text(l10n.tr('import_save')),
                onPressed: _save,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _modeKeys = {
  _Mode.text: 'import_tab_text',
  _Mode.link: 'import_tab_link',
  _Mode.photo: 'import_tab_photo',
  _Mode.pdf: 'import_tab_pdf',
};

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final entry in _modeKeys.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: mode == entry.key
                        ? AppColors.coral
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    context.l10n.tr(entry.value),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: mode == entry.key
                          ? Colors.white
                          : AppColors.walnutSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Row(
            children: [
              Icon(icon, color: AppColors.coral),
              const SizedBox(width: 12),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.walnutSoft)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.label, this.dark = false});
  final String label;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColors.coral : Colors.white;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                color: dark ? AppColors.walnutSoft : Colors.white)),
      ],
    );
  }
}

class _PatternPreview extends StatelessWidget {
  const _PatternPreview({required this.pattern});
  final Pattern pattern;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pattern.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Chip(pattern.technique.labelPt),
              _Chip(pattern.difficulty.labelPt),
              _Chip(l10n.tr('import_rows_count',
                  {'n': '${pattern.totalRows}'})),
            ],
          ),
          if (pattern.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(pattern.description,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 14),
          for (final section in pattern.sections) ...[
            Text(section.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.coral)),
            const SizedBox(height: 6),
            for (final r in section.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text('${r.row}.',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.walnutMuted)),
                    ),
                    Expanded(
                      child: Text(
                        r.stitchCount != null
                            ? '${r.instruction}  (${r.stitchCount})'
                            : r.instruction,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.peach.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.walnutSoft)),
    );
  }
}
