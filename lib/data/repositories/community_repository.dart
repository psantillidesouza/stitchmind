import 'dart:io';

import '../../domain/entities/community.dart';
import '../services/api_client.dart';

/// Comunidade — backend único **Bun** (`/v1/...`), autenticado com Firebase.
class CommunityRepository {
  CommunityRepository(this._api);

  final ApiClient _api;

  // ─── Dicas ────────────────────────────────────────────────────────
  Future<List<Tip>> tips() async {
    final json = await _api.get('/v1/tips') as Map<String, dynamic>;
    return (json['tips'] as List)
        .cast<Map<String, dynamic>>()
        .map(Tip.fromJson)
        .toList();
  }

  // ─── Feed (paginado por cursor + filtros) ───────────────────────────
  Future<Feed> feed({String? cursor, String? category, String? type, bool saved = false}) async {
    final q = StringBuffer('/v1/posts?limit=20');
    if (cursor != null) q.write('&cursor=${Uri.encodeQueryComponent(cursor)}');
    if (category != null) q.write('&category=$category');
    if (type != null) q.write('&type=$type');
    if (saved) q.write('&saved=1');
    final json = await _api.get(q.toString()) as Map<String, dynamic>;
    final items = ((json['posts'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Post.fromFeed)
        .toList();
    return Feed(items, json['next_cursor'] as String?);
  }

  /// Publica um crochê (imagem + metadados) em um único multipart.
  Future<void> publish(
    File image,
    String caption, {
    String postType = 'finished',
    String? category,
    String? difficulty,
    String? yarn,
    String? hook,
  }) async {
    await _api.postFile(
      '/v1/posts',
      image.path,
      field: 'image',
      fields: {
        if (caption.trim().isNotEmpty) 'caption': caption.trim(),
        'post_type': postType,
        if (category != null) 'category': category,
        if (difficulty != null) 'difficulty': difficulty,
        if (yarn != null && yarn.trim().isNotEmpty) 'yarn': yarn.trim(),
        if (hook != null && hook.trim().isNotEmpty) 'hook': hook.trim(),
      },
    );
  }

  /// Curte/descurte (toggle). Devolve o estado e a contagem do servidor.
  Future<({bool liked, int likes})> toggleLike(String postId) async {
    final res = await _api.post('/v1/posts/$postId/like') as Map<String, dynamic>;
    return (
      liked: res['liked'] as bool? ?? false,
      likes: (res['likes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Salva/remove dos salvos (toggle). Devolve o estado do servidor.
  Future<bool> toggleSave(String postId) async {
    final res = await _api.post('/v1/posts/$postId/save') as Map<String, dynamic>;
    return res['saved'] as bool? ?? false;
  }

  Future<void> report(String postId, String reason, {String? note}) =>
      _api.post('/v1/posts/$postId/report', {
        'reason': reason,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  Future<void> deletePost(String postId) => _api.delete('/v1/posts/$postId');

  // ─── Comentários ────────────────────────────────────────────────────
  Future<List<Comment>> comments(String postId) async {
    final json = await _api.get('/v1/posts/$postId/comments') as Map<String, dynamic>;
    return ((json['comments'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Comment.fromJson)
        .toList();
  }

  Future<Comment> addComment(String postId, String body) async {
    final res = await _api.post('/v1/posts/$postId/comments', {'body': body})
        as Map<String, dynamic>;
    return Comment.fromJson(res);
  }

  Future<void> deleteComment(String commentId) =>
      _api.delete('/v1/comments/$commentId');

  // ─── Bloquear / seguir / perfil ─────────────────────────────────────
  Future<void> blockUser(String userId) => _api.post('/v1/users/$userId/block');
  Future<void> unblockUser(String userId) => _api.delete('/v1/users/$userId/block');
  Future<void> follow(String userId) => _api.post('/v1/users/$userId/follow');
  Future<void> unfollow(String userId) => _api.delete('/v1/users/$userId/follow');

  Future<Profile> profile(String userId) async {
    final json = await _api.get('/v1/users/$userId/profile') as Map<String, dynamic>;
    return Profile.fromJson(json);
  }
}
