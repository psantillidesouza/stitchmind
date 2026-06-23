import 'package:flutter/foundation.dart';

@immutable
class Tip {
  final String id;
  final String emoji;
  final String title;
  final String body;
  const Tip({required this.id, required this.emoji, required this.title, required this.body});

  factory Tip.fromJson(Map<String, dynamic> j) => Tip(
        id: j['id'] as String,
        emoji: (j['emoji'] as String?) ?? '🧶',
        title: j['title'] as String,
        body: (j['body'] as String?) ?? '',
      );
}

@immutable
class Post {
  final String id;
  final String caption;
  final String? imageUrl;
  final int likes;
  final int comments;
  final bool liked;
  final bool saved;
  final String postType; // finished | wip | help
  final String? category; // amigurumi | garment | blanket | accessory | granny | home_decor | other
  final String? difficulty; // beginner | intermediate | advanced
  final String? yarn;
  final String? hook;
  final String? authorId;
  final String author;
  final String? authorPhoto;
  final bool isMine;
  final DateTime? createdAt;

  const Post({
    required this.id,
    required this.caption,
    this.imageUrl,
    this.likes = 0,
    this.comments = 0,
    this.liked = false,
    this.saved = false,
    this.postType = 'finished',
    this.category,
    this.difficulty,
    this.yarn,
    this.hook,
    this.authorId,
    this.author = 'Maker',
    this.authorPhoto,
    this.isMine = false,
    this.createdAt,
  });

  Post copyWith({int? likes, bool? liked, int? comments, bool? saved}) => Post(
        id: id,
        caption: caption,
        imageUrl: imageUrl,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        liked: liked ?? this.liked,
        saved: saved ?? this.saved,
        postType: postType,
        category: category,
        difficulty: difficulty,
        yarn: yarn,
        hook: hook,
        authorId: authorId,
        author: author,
        authorPhoto: authorPhoto,
        isMine: isMine,
        createdAt: createdAt,
      );

  /// Item do feed do backend Bun (`GET /v1/posts`).
  factory Post.fromFeed(Map<String, dynamic> j) => Post(
        id: j['id'] as String,
        caption: (j['caption'] as String?) ?? '',
        imageUrl: j['image_url'] as String?,
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        comments: (j['comments'] as num?)?.toInt() ?? 0,
        liked: j['liked'] as bool? ?? false,
        saved: j['saved'] as bool? ?? false,
        postType: (j['post_type'] as String?) ?? 'finished',
        category: j['category'] as String?,
        difficulty: j['difficulty'] as String?,
        yarn: j['yarn'] as String?,
        hook: j['hook'] as String?,
        authorId: j['author_id'] as String?,
        author: (j['author'] as String?) ?? 'Maker',
        authorPhoto: j['author_photo'] as String?,
        isMine: j['is_mine'] as bool? ?? false,
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      );
}

/// Rótulos e opções de metadados da comunidade (centralizados p/ a UI).
class CommunityMeta {
  CommunityMeta._();

  static const categories = <String, String>{
    'amigurumi': 'Amigurumi',
    'garment': 'Garments',
    'blanket': 'Blankets',
    'accessory': 'Accessories',
    'granny': 'Granny squares',
    'home_decor': 'Home decor',
    'other': 'Other',
  };

  static const types = <String, String>{
    'finished': 'Finished',
    'wip': 'In progress',
    'help': 'Help',
  };

  static const difficulties = <String, String>{
    'beginner': 'Beginner',
    'intermediate': 'Intermediate',
    'advanced': 'Advanced',
  };

  static String? categoryLabel(String? k) => k == null ? null : categories[k];
  static String? difficultyLabel(String? k) => k == null ? null : difficulties[k];
  static String typeLabel(String k) => types[k] ?? 'Finished';
}

/// Página do feed (posts + cursor para a próxima página).
@immutable
class Feed {
  final List<Post> posts;
  final String? nextCursor;
  const Feed(this.posts, this.nextCursor);
}

@immutable
class Comment {
  final String id;
  final String body;
  final String? authorId;
  final String author;
  final String? authorPhoto;
  final bool isMine;
  final DateTime? createdAt;

  const Comment({
    required this.id,
    required this.body,
    this.authorId,
    this.author = 'Maker',
    this.authorPhoto,
    this.isMine = false,
    this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as String,
        body: (j['body'] as String?) ?? '',
        authorId: j['author_id'] as String?,
        author: (j['author'] as String?) ?? 'Maker',
        authorPhoto: j['author_photo'] as String?,
        isMine: j['is_mine'] as bool? ?? false,
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      );
}

/// Miniatura de post numa grade de perfil.
@immutable
class ProfilePost {
  final String id;
  final String? imageUrl;
  final int likes;
  const ProfilePost({required this.id, this.imageUrl, this.likes = 0});

  factory ProfilePost.fromJson(Map<String, dynamic> j) => ProfilePost(
        id: j['id'] as String,
        imageUrl: j['image_url'] as String?,
        likes: (j['likes'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class Profile {
  final String id;
  final String name;
  final String? photoUrl;
  final int postsCount;
  final int followers;
  final int following;
  final bool isFollowing;
  final bool isBlocked;
  final bool isMe;
  final List<ProfilePost> posts;

  const Profile({
    required this.id,
    required this.name,
    this.photoUrl,
    this.postsCount = 0,
    this.followers = 0,
    this.following = 0,
    this.isFollowing = false,
    this.isBlocked = false,
    this.isMe = false,
    this.posts = const [],
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Maker',
        photoUrl: j['photo_url'] as String?,
        postsCount: (j['posts_count'] as num?)?.toInt() ?? 0,
        followers: (j['followers'] as num?)?.toInt() ?? 0,
        following: (j['following'] as num?)?.toInt() ?? 0,
        isFollowing: j['is_following'] as bool? ?? false,
        isBlocked: j['is_blocked'] as bool? ?? false,
        isMe: j['is_me'] as bool? ?? false,
        posts: ((j['posts'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ProfilePost.fromJson)
            .toList(),
      );
}
