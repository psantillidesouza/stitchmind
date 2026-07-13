import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/chat_service.dart';
import '../../providers/platform_providers.dart';
import '../../providers/saved_lessons_provider.dart';
import '../../widgets/gradient_bg.dart';
import '../../widgets/premium_gate.dart';
import '../../../l10n/app_localizations.dart';
import '../aulas_salvas/saved_lessons_page.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(context.l10n.tr('chat_appbar_title')),
          leading: const BackButton(),
          actions: [
            IconButton(
              tooltip: context.l10n.tr('chat_tooltip_saved_lessons'),
              icon: const Icon(Icons.bookmark_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SavedLessonsPage()),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: PremiumGate(
            title: context.l10n.tr('chat_gate_title'),
            subtitle: context.l10n.tr('chat_gate_subtitle'),
            image: 'assets/illustrations/chat.png',
            child: const ChatView(),
          ),
        ),
      ),
    );
  }
}

/// Conversa com a IA sem casca (Scaffold/AppBar/gate) — dá pra embutir em
/// qualquer tela, como a tab "Chat com IA" do guia da aula.
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key});
  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  int? _intent; // índice em _kIntents, ou null (conversa livre)
  final List<ChatMessage> _messages = [];
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.isEmpty) {
      _messages.add(ChatMessage('assistant', context.l10n.tr('chat_greeting')));
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();
    setState(() {
      _messages.add(ChatMessage('user', text));
      _loading = true;
    });
    _scrollDown();
    try {
      // O balão mostra o texto limpo; à IA enviamos a versão enquadrada
      // pelo modo escolhido (Aprender/Fazer/Corrigir/Ideias).
      final payload = List<ChatMessage>.from(_messages);
      if (_intent != null) {
        final framed = _kIntents(context)[_intent!].$4.replaceFirst('{m}', text);
        payload[payload.length - 1] = ChatMessage('user', framed);
      }
      final reply = await ref.read(chatServiceProvider).send(payload);
      setState(() => _messages.add(ChatMessage('assistant', reply)));
    } catch (e) {
      setState(() => _messages.add(ChatMessage('assistant',
          context.l10n.tr('chat_error_reply', {'error': '$e'}))));
    } finally {
      setState(() => _loading = false);
      _scrollDown();
    }
  }

  /// Seleciona/desmarca um modo (intenção). Não envia nada — só "converte"
  /// o chat para aquela intenção e foca o campo pra pessoa digitar.
  void _setIntent(int i) {
    setState(() => _intent = _intent == i ? null : i);
    _focus.requestFocus();
  }

  Future<void> _saveLesson(String markdown) async {
    final saved =
        await ref.read(savedLessonsProvider.notifier).saveMarkdown(markdown);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(saved
            ? context.l10n.tr('chat_snackbar_saved')
            : context.l10n.tr('chat_snackbar_already_saved')),
        backgroundColor: AppColors.walnut,
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_messages.length <= 1)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Image.asset(
              'assets/illustrations/chat.png',
              height: 128,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _messages.length + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _messages.length) return const _TypingBubble();
              final m = _messages[i];
              return _Bubble(
                message: m,
                onSave: () => _saveLesson(m.content),
              );
            },
          ),
        ),
        _IntentChips(selected: _intent, onSelect: _setIntent),
        _Composer(
          controller: _controller,
          focusNode: _focus,
          onSend: _send,
          enabled: !_loading,
          hint: _intent != null
              ? _kIntents(context)[_intent!].$3
              : context.l10n.tr('chat_composer_hint'),
        ),
      ],
    );
  }
}

// ─── Modos do chat (intenção) ───────────────────────────────────────
// (emoji, label, hint do campo, enquadramento enviado à IA com {m})
List<(String, String, String, String)> _kIntents(BuildContext context) => [
  ('🧶', context.l10n.tr('chat_intent_learn_label'),
      context.l10n.tr('chat_intent_learn_hint'),
      context.l10n.tr('chat_intent_learn_framing')),
  ('🧸', context.l10n.tr('chat_intent_make_label'),
      context.l10n.tr('chat_intent_make_hint'),
      context.l10n.tr('chat_intent_make_framing')),
  ('🛠️', context.l10n.tr('chat_intent_fix_label'),
      context.l10n.tr('chat_intent_fix_hint'),
      context.l10n.tr('chat_intent_fix_framing')),
  ('💡', context.l10n.tr('chat_intent_ideas_label'),
      context.l10n.tr('chat_intent_ideas_hint'),
      context.l10n.tr('chat_intent_ideas_framing')),
];

/// Barra de modos: tocar "converte" o chat para aquela intenção (não envia).
class _IntentChips extends StatelessWidget {
  const _IntentChips({required this.selected, required this.onSelect});
  final int? selected;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    final intents = _kIntents(context);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: intents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final intent = intents[i];
          final emoji = intent.$1;
          final label = intent.$2;
          final isSel = selected == i;
          return Material(
            color: isSel ? AppColors.coral : AppColors.card,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSel ? AppColors.coral : AppColors.linen),
                ),
                child: Text(
                  '$emoji  $label',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isSel ? AppColors.paper : AppColors.walnut,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onSave});
  final ChatMessage message;
  final VoidCallback? onSave;
  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isTutorial =
        !isUser && message.content.contains(RegExp(r'(^|\n)#'));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(radius: 16, backgroundColor: AppColors.peach,
                child: Icon(Icons.auto_awesome, size: 16, color: AppColors.coral)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.coral : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: softShadow(0.04),
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        height: 1.45,
                        color: AppColors.paper,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GptMarkdown(
                          message.content,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            height: 1.5,
                            color: AppColors.walnut,
                          ),
                        ),
                        if (isTutorial && onSave != null) ...[
                          const Divider(height: 18, color: AppColors.linen),
                          InkWell(
                            onTap: onSave,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bookmark_add_rounded,
                                      size: 19, color: AppColors.coral),
                                  const SizedBox(width: 6),
                                  Text(context.l10n.tr('chat_save_lesson'),
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.coral,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        const CircleAvatar(radius: 16, backgroundColor: AppColors.peach,
            child: Icon(Icons.auto_awesome, size: 16, color: AppColors.coral)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: softShadow(0.04),
          ),
          child: const SizedBox(
            width: 36,
            child: Text('•••', style: TextStyle(color: AppColors.walnutMuted, letterSpacing: 2)),
          ),
        ),
      ]),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.enabled, this.focusNode, this.hint = 'Ask about crochet…'});
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final bool enabled;
  final String hint;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.linen)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: softShadow(0.04),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: enabled ? onSend : null,
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                gradient: enabled
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.coral, AppColors.coralDeep],
                      )
                    : null,
                color: enabled ? null : AppColors.walnutMuted.withValues(alpha: 0.4),
                shape: BoxShape.circle,
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: AppColors.coral.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
