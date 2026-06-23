import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/community.dart';
import '../../providers/platform_providers.dart';

class UserProfilePage extends ConsumerWidget {
  const UserProfilePage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(userId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.walnut,
        title: const Text('Profile',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Profile unavailable.')),
        data: (p) => _content(context, ref, p),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, Profile p) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.coralSoft,
            backgroundImage: p.photoUrl != null ? NetworkImage(p.photoUrl!) : null,
            child: p.photoUrl == null
                ? const Icon(Icons.person_rounded, color: AppColors.coral, size: 44)
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(p.name,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.walnut)),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _stat('${p.postsCount}', 'posts'),
            _stat('${p.followers}', 'followers'),
            _stat('${p.following}', 'following'),
          ],
        ),
        const SizedBox(height: 16),
        if (!p.isMe) _buttons(context, ref, p),
        const SizedBox(height: 20),
        if (p.posts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Text('No posts yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.walnutSoft, fontFamily: 'Poppins')),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (final pp in p.posts)
                GestureDetector(
                  onTap: () => context.push('/community/post/${pp.id}'),
                  child: pp.imageUrl != null
                      ? Image.network(pp.imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: AppColors.linenSoft))
                      : Container(color: AppColors.linenSoft),
                ),
            ],
          ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.walnut)),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12, color: AppColors.walnutSoft)),
      ],
    );
  }

  Widget _buttons(BuildContext context, WidgetRef ref, Profile p) {
    final repo = ref.read(communityRepositoryProvider);
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.isFollowing ? AppColors.linen : AppColors.coral,
              foregroundColor: p.isFollowing ? AppColors.walnut : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              if (p.isFollowing) {
                await repo.unfollow(p.id);
              } else {
                await repo.follow(p.id);
              }
              ref.invalidate(userProfileProvider(userId));
            },
            child: Text(p.isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.coralDeep,
            side: const BorderSide(color: AppColors.hairline),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () async {
            if (p.isBlocked) {
              await repo.unblockUser(p.id);
            } else {
              await repo.blockUser(p.id);
              ref.read(communityFeedProvider.notifier).refresh();
            }
            ref.invalidate(userProfileProvider(userId));
          },
          child: Text(p.isBlocked ? 'Unblock' : 'Block',
              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
