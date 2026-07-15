import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/repositories/community_repository.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../data/services/analytics_service.dart';
import '../../data/services/api_client.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/firebase_auth_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/realtime_service.dart';
import '../../data/services/subscription_service.dart';
import '../../data/services/tap_tracker.dart';
import '../../data/services/telemetry_service.dart';
import '../../domain/entities/community.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/store_reviews.dart';

/// Serviços de plataforma são injetados no boot (main.dart) via overrides.
final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('authServiceProvider deve ser sobrescrito no boot');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(authServiceProvider));
});

/// Edição de perfil (nome + foto). Requer Firebase Auth real.
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(
    ref.watch(apiClientProvider),
    ref.watch(authServiceProvider) as FirebaseAuthService,
  );
});

final telemetryProvider = Provider<TelemetryService>((ref) {
  throw UnimplementedError('telemetryProvider deve ser sobrescrito no boot');
});

final realtimeProvider = Provider<RealtimeService>((ref) {
  throw UnimplementedError('realtimeProvider deve ser sobrescrito no boot');
});

final tapTrackerProvider = Provider<TapTracker>((ref) {
  throw UnimplementedError('tapTrackerProvider deve ser sobrescrito no boot');
});

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  throw UnimplementedError('subscriptionServiceProvider deve ser sobrescrito no boot');
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  throw UnimplementedError('analyticsServiceProvider deve ser sobrescrito no boot');
});

/// Versão do app (ex.: "1.0.2"), lida do bundle nativo em vez de hardcoded.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return LessonRepository(ref.watch(apiClientProvider));
});

// ─── Aulas ──────────────────────────────────────────────────────────

final lessonsProvider = FutureProvider<List<Lesson>>((ref) {
  return ref.watch(lessonRepositoryProvider).lessons();
});

final coursesProvider = FutureProvider<List<Course>>((ref) {
  return ref.watch(lessonRepositoryProvider).courses();
});

/// autoDispose: o detalhe é descartado ao sair da aula e rebuscado na API a
/// cada abertura — sem isso, edições feitas no painel só apareciam depois de
/// fechar e reabrir o app (o cache durava a sessão inteira).
final lessonDetailProvider =
    FutureProvider.autoDispose.family<LessonDetail, String>((ref, slug) {
  return ref.watch(lessonRepositoryProvider).lesson(slug);
});

// ─── Comunidade (dicas + feed + social) ─────────────────────────────

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(ref.watch(apiClientProvider)); // backend único (Bun)
});

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.watch(apiClientProvider));
});

/// Avaliações reais das lojas (App Store + Google Play), via backend.
final reviewsProvider = FutureProvider<StoreReviews>((ref) async {
  final json = await ref.watch(apiClientProvider).get('/v1/reviews');
  if (json is Map<String, dynamic>) return StoreReviews.fromJson(json);
  return StoreReviews.empty;
});

final tipsProvider = FutureProvider<List<Tip>>((ref) {
  return ref.watch(communityRepositoryProvider).tips();
});

/// Feed da comunidade: paginação por cursor, curtida otimista e remoção local
/// (ao apagar/bloquear) sem recarregar tudo.
class CommunityFeedNotifier extends AsyncNotifier<List<Post>> {
  String? _cursor;
  bool hasMore = true;

  /// Filtro atual: categoria selecionada e/ou só salvos.
  String? category;
  bool savedOnly = false;

  Future<List<Post>> _fetch({String? cursor}) async {
    final feed = await ref.read(communityRepositoryProvider).feed(
          cursor: cursor,
          category: category,
          saved: savedOnly,
        );
    _cursor = feed.nextCursor;
    hasMore = feed.nextCursor != null;
    return feed.posts;
  }

  @override
  Future<List<Post>> build() => _fetch();

  /// Troca o filtro e recarrega do começo.
  Future<void> setFilter({String? category, bool savedOnly = false}) async {
    this.category = category;
    this.savedOnly = savedOnly;
    await refresh();
  }

  Future<void> loadMore() async {
    if (!hasMore) return;
    final current = state.valueOrNull ?? const [];
    final more = await _fetch(cursor: _cursor);
    state = AsyncData([...current, ...more]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }

  Future<void> toggleLike(String postId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    // otimista
    state = AsyncData([
      for (final p in current)
        p.id == postId
            ? p.copyWith(liked: !p.liked, likes: p.likes + (p.liked ? -1 : 1))
            : p,
    ]);
    try {
      final r = await ref.read(communityRepositoryProvider).toggleLike(postId);
      final base = state.valueOrNull ?? current;
      state = AsyncData([
        for (final p in base)
          p.id == postId ? p.copyWith(liked: r.liked, likes: r.likes) : p,
      ]);
    } catch (_) {
      state = AsyncData(current); // rollback
    }
  }

  Future<void> toggleSave(String postId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final p in current)
        p.id == postId ? p.copyWith(saved: !p.saved) : p,
    ]);
    try {
      final saved = await ref.read(communityRepositoryProvider).toggleSave(postId);
      final base = state.valueOrNull ?? current;
      var next = [
        for (final p in base) p.id == postId ? p.copyWith(saved: saved) : p,
      ];
      // Na aba "Saved", remove o que foi dessalvo.
      if (savedOnly && !saved) next = next.where((p) => p.id != postId).toList();
      state = AsyncData(next);
    } catch (_) {
      state = AsyncData(current); // rollback
    }
  }

  void removePost(String postId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.where((p) => p.id != postId).toList());
  }
}

final communityFeedProvider =
    AsyncNotifierProvider<CommunityFeedNotifier, List<Post>>(
        CommunityFeedNotifier.new);

final postCommentsProvider =
    FutureProvider.family<List<Comment>, String>((ref, postId) {
  return ref.watch(communityRepositoryProvider).comments(postId);
});

final userProfileProvider =
    FutureProvider.family<Profile, String>((ref, userId) {
  return ref.watch(communityRepositoryProvider).profile(userId);
});
