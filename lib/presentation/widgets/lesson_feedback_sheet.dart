import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/lesson.dart';
import '../../l10n/app_localizations.dart';
import '../providers/platform_providers.dart';

/// Bottom sheet de feedback da aula: "Gostei disso" + "Mais sugestões".
/// Sobe de baixo pra cima até a metade da tela. O like e a sugestão são
/// gravados no servidor (tabela lesson_feedback) — 1 de cada por usuário.
class LessonFeedbackSheet extends ConsumerStatefulWidget {
  const LessonFeedbackSheet({required this.lesson, super.key});
  final Lesson lesson;

  @override
  ConsumerState<LessonFeedbackSheet> createState() =>
      _LessonFeedbackSheetState();
}

class _LessonFeedbackSheetState extends ConsumerState<LessonFeedbackSheet> {
  final _commentCtrl = TextEditingController();
  bool _showSuggestion = false;
  bool _sending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  // 1 like e 1 comentário por usuário (o servidor deduplica; comentário
  // novo substitui o anterior).
  Future<void> _send({required String kind, String? comment}) async {
    setState(() => _sending = true);
    await ref.read(apiClientProvider).postSilent(
      '/v1/lessons/${widget.lesson.id}/feedback',
      {
        'kind': kind,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.tr('lesson_feedback_thanks'))),
    );
  }

  // Botões brancos do sheet, com texto em peso normal (sem bold).
  static final _whiteBtnStyle = OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(54),
    backgroundColor: Colors.white,
    foregroundColor: AppColors.walnut,
    side: const BorderSide(color: AppColors.linen),
    textStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final half = MediaQuery.of(context).size.height * 0.5;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      // Sobe junto com o teclado quando o campo de sugestão está aberto.
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: half,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Alça do sheet
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.linen,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.lesson.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            // ── Gostei disso ──
            OutlinedButton.icon(
              onPressed: _sending ? null : () => _send(kind: 'like'),
              icon: const Icon(Icons.thumb_up_outlined, size: 20),
              label: Text(context.l10n.tr('lesson_like_button')),
              style: _whiteBtnStyle,
            ),
            const SizedBox(height: 12),
            // ── Mais sugestões ──
            if (!_showSuggestion)
              OutlinedButton.icon(
                onPressed: _sending
                    ? null
                    : () => setState(() => _showSuggestion = true),
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: Text(context.l10n.tr('lesson_suggest_button')),
                style: _whiteBtnStyle,
              )
            else ...[
              TextField(
                controller: _commentCtrl,
                autofocus: true,
                maxLength: 120,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.l10n.tr('lesson_suggest_hint'),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _sending
                    ? null
                    : () {
                        final text = _commentCtrl.text.trim();
                        if (text.isEmpty) return;
                        _send(kind: 'comment', comment: text);
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(
                    _sending ? '…' : context.l10n.tr('lesson_suggest_send')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
