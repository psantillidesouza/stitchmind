import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/community.dart';
import '../../../providers/platform_providers.dart';
import '../../../widgets/gradient_bg.dart';

/// Cartão de uma publicação no feed da comunidade.
class PostCard extends ConsumerWidget {
  const PostCard({required this.post, super.key});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
        boxShadow: elevatedShadow(0.06),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, ref),
          if (post.imageUrl != null)
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                post.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.linenSoft,
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: AppColors.walnutMuted),
                ),
                loadingBuilder: (_, child, p) => p == null
                    ? child
                    : Container(
                        color: AppColors.linenSoft,
                        alignment: Alignment.center,
                        child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
              ),
            ),
          _tags(),
          _actions(context, ref),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(post.caption,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 14, color: AppColors.walnut)),
            ),
          if (post.yarn != null || post.hook != null) _materials(),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _openProfile(context),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.coralSoft,
              backgroundImage:
                  post.authorPhoto != null ? NetworkImage(post.authorPhoto!) : null,
              child: post.authorPhoto == null
                  ? const Icon(Icons.person_rounded, color: AppColors.coral, size: 20)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _openProfile(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.author,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.walnut)),
                  if (_ago(post.createdAt).isNotEmpty)
                    Text(_ago(post.createdAt),
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            color: AppColors.walnutMuted)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: AppColors.walnutMuted),
            onPressed: () => _menu(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _tags() {
    final cat = CommunityMeta.categoryLabel(post.category);
    final diff = CommunityMeta.difficultyLabel(post.difficulty);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _TypeBadge(type: post.postType),
          if (cat != null) _Chip(label: cat),
          if (diff != null) _Chip(label: diff, icon: Icons.signal_cellular_alt_rounded),
        ],
      ),
    );
  }

  Widget _materials() {
    final parts = <String>[
      if (post.yarn != null) '🧶 ${post.yarn}',
      if (post.hook != null) '🪝 ${post.hook}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Text(parts.join('   '),
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.walnutSoft)),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      child: Row(
        children: [
          _PillButton(
            icon: post.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: post.liked ? AppColors.coral : AppColors.walnutSoft,
            label: '${post.likes}',
            onTap: () => ref.read(communityFeedProvider.notifier).toggleLike(post.id),
          ),
          _PillButton(
            icon: Icons.mode_comment_outlined,
            color: AppColors.walnutSoft,
            label: '${post.comments}',
            onTap: () => context.push('/community/post/${post.id}', extra: post),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              post.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: post.saved ? AppColors.coral : AppColors.walnutSoft,
            ),
            tooltip: post.saved ? 'Saved' : 'Save',
            onPressed: () => ref.read(communityFeedProvider.notifier).toggleSave(post.id),
          ),
        ],
      ),
    );
  }

  void _openProfile(BuildContext context) {
    if (post.authorId != null) context.push('/community/user/${post.authorId}');
  }

  static String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(communityRepositoryProvider);
    final feed = ref.read(communityFeedProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.coralDeep),
                title: const Text('Delete post'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(sheet);
                  await repo.deletePost(post.id);
                  feed.removePost(post.id);
                  messenger.showSnackBar(const SnackBar(content: Text('Post deleted.')));
                },
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.coralDeep),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(sheet);
                  _reportSheet(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: AppColors.walnut),
                title: const Text('Block this person'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(sheet);
                  if (post.authorId != null) {
                    await repo.blockUser(post.authorId!);
                    feed.removePost(post.id);
                    messenger.showSnackBar(const SnackBar(
                        content: Text("Blocked. You won't see their posts anymore.")));
                  }
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.close_rounded, color: AppColors.walnutMuted),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(sheet),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportSheet(BuildContext context, WidgetRef ref) async {
    const reasons = {
      'spam': 'Spam or advertising',
      'offensive': 'Offensive content',
      'nudity': 'Nudity or sexual content',
      'harassment': 'Harassment or bullying',
      'other': 'Other',
    };
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Why are you reporting?',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.walnut)),
              ),
            ),
            for (final e in reasons.entries)
              ListTile(
                title: Text(e.value),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(sheet);
                  await ref.read(communityRepositoryProvider).report(post.id, e.key);
                  ref.read(communityFeedProvider.notifier).removePost(post.id);
                  messenger.showSnackBar(
                      const SnackBar(content: Text('Report sent. Thanks for letting us know.')));
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Badge colorido do tipo de post (Finished / In progress / Help).
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (type) {
      'wip' => (const Color(0xFFFDF1DD), AppColors.ochre, Icons.timelapse_rounded),
      'help' => (AppColors.coralSoft, AppColors.coralDeep, Icons.help_outline_rounded),
      _ => (AppColors.sageSoft, AppColors.sage, Icons.check_circle_outline_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(CommunityMeta.typeLabel(type),
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.linenSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: AppColors.walnutSoft),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.walnutSoft)),
      ]),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton(
      {required this.icon, required this.color, required this.label, required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}
