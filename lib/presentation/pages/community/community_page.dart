import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/community.dart';
import '../../providers/platform_providers.dart';
import 'widgets/post_card.dart';

class _Filter {
  final String key;
  final String label;
  final String? category;
  final bool savedOnly;
  const _Filter(this.key, this.label, {this.category, this.savedOnly = false});
}

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  final _scroll = ScrollController();
  String _selected = 'all';

  static final _filters = <_Filter>[
    const _Filter('all', 'All'),
    for (final e in CommunityMeta.categories.entries)
      _Filter(e.key, e.value, category: e.key),
    const _Filter('saved', 'Saved', savedOnly: true),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
        ref.read(communityFeedProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _pick(_Filter f) {
    if (_selected == f.key) return;
    setState(() => _selected = f.key);
    ref
        .read(communityFeedProvider.notifier)
        .setFilter(category: f.category, savedOnly: f.savedOnly);
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(communityFeedProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Community',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                          color: AppColors.walnut)),
                ),
                _PublishButton(onTap: () => context.push('/community/publish')),
              ],
            ),
          ),
          _filterBar(),
          Expanded(
            child: feed.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                  onRetry: () => ref.read(communityFeedProvider.notifier).refresh()),
              data: (posts) {
                if (posts.isEmpty) return _EmptyState(savedTab: _selected == 'saved');
                return RefreshIndicator(
                  color: AppColors.coral,
                  onRefresh: () => ref.read(communityFeedProvider.notifier).refresh(),
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(top: 8, bottom: 110),
                    itemCount: posts.length,
                    itemBuilder: (_, i) => PostCard(post: posts[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _filters[i];
          final active = _selected == f.key;
          return GestureDetector(
            onTap: () => _pick(f),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? AppColors.coral : AppColors.paper,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                border: Border.all(
                    color: active ? AppColors.coral : AppColors.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (f.key == 'saved')
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.bookmark_rounded,
                          size: 15,
                          color: active ? AppColors.paper : AppColors.walnutSoft),
                    ),
                  Text(f.label,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: active ? AppColors.paper : AppColors.walnutSoft)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PublishButton extends StatelessWidget {
  const _PublishButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.coral,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_a_photo_rounded, color: AppColors.paper, size: 18),
            SizedBox(width: 6),
            Text('Share',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: AppColors.paper)),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.savedTab});
  final bool savedTab;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
      children: [
        Icon(savedTab ? Icons.bookmark_border_rounded : Icons.photo_camera_back_outlined,
            size: 64, color: AppColors.walnutMuted),
        const SizedBox(height: 16),
        Text(savedTab ? 'No saved posts yet' : 'Nothing here yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.walnut)),
        const SizedBox(height: 8),
        Text(
            savedTab
                ? 'Tap the bookmark on a post to save it here.'
                : 'Be the first to share your crochet with the community 🧶',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 14, color: AppColors.walnutSoft)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Couldn't load the feed.",
              style: TextStyle(fontFamily: 'Poppins', color: AppColors.walnutSoft)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
