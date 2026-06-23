import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/community.dart';
import '../../providers/platform_providers.dart';
import 'widgets/post_card.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({required this.postId, this.post, super.key});

  final String postId;
  final Post? post;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(communityRepositoryProvider).addComment(widget.postId, text);
      _input.clear();
      if (mounted) FocusScope.of(context).unfocus(); // fecha o teclado
      ref.invalidate(postCommentsProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not comment: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String commentId) async {
    await ref.read(communityRepositoryProvider).deleteComment(commentId);
    ref.invalidate(postCommentsProvider(widget.postId));
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(postCommentsProvider(widget.postId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.walnut,
        title: const Text('Post',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              children: [
                if (widget.post != null) PostCard(post: widget.post!),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text('Comments',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.walnut)),
                ),
                comments.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text("Couldn't load comments.",
                          textAlign: TextAlign.center)),
                  data: (list) => list.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Be the first to comment 💬',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.walnutSoft)))
                      : Column(
                          children: [for (final cm in list) _commentTile(cm)],
                        ),
                ),
              ],
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _commentTile(Comment cm) {
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.coralSoft,
        backgroundImage: cm.authorPhoto != null ? NetworkImage(cm.authorPhoto!) : null,
        child: cm.authorPhoto == null
            ? const Icon(Icons.person_rounded, color: AppColors.coral, size: 20)
            : null,
      ),
      title: Text(cm.author,
          style: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13)),
      subtitle: Text(cm.body,
          style: const TextStyle(fontFamily: 'Poppins', color: AppColors.walnut)),
      trailing: cm.isMine
          ? IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.walnutMuted, size: 20),
              onPressed: () => _delete(cm.id),
            )
          : null,
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Add a comment…',
                  filled: true,
                  fillColor: AppColors.paper,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.hairline)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.hairline)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.coral,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _send,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
