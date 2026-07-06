import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/analysis_repository.dart';
import '../../data/repositories/pattern_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/stitch_repository.dart';
import '../../data/services/analysis_service.dart';
import '../../domain/entities/ai_analysis.dart';
import '../../domain/entities/entities.dart';
import 'platform_providers.dart';

// ─── Projects ─────────────────────────────────────────────────────────────

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return HiveProjectRepository();
});

final projectsStreamProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(projectRepositoryProvider).watchAll();
});

final projectByIdProvider = Provider.family<Project?, String>((ref, id) {
  final async = ref.watch(projectsStreamProvider);
  return async.maybeWhen(
    data: (list) {
      for (final p in list) {
        if (p.id == id) return p;
      }
      return null;
    },
    orElse: () => null,
  );
});

final projectsByStatusProvider =
    Provider.family<List<Project>, ProjectStatus>((ref, status) {
  final list = ref.watch(projectsStreamProvider).valueOrNull ?? const [];
  return list.where((p) => p.status == status).toList();
});

class ProjectActions {
  ProjectActions(this._repo);
  final ProjectRepository _repo;

  Future<void> save(Project p) => _repo.upsert(p);
  Future<void> delete(String id) => _repo.delete(id);

  Future<void> setRow(String id, int row) async {
    final current = _repo.getById(id);
    if (current == null) return;
    await _repo.upsert(current.copyWith(currentRow: row.clamp(0, 1 << 30)));
  }

  Future<void> setStatus(String id, ProjectStatus status) async {
    final current = _repo.getById(id);
    if (current == null) return;
    await _repo.upsert(current.copyWith(status: status));
  }

  Future<void> setMarkers(String id, List<Marker> markers) async {
    final current = _repo.getById(id);
    if (current == null) return;
    await _repo.upsert(current.copyWith(markers: markers));
  }
}

final projectActionsProvider = Provider<ProjectActions>((ref) {
  return ProjectActions(ref.watch(projectRepositoryProvider));
});

// ─── Stitches ─────────────────────────────────────────────────────────────

final stitchRepositoryProvider = Provider<StitchRepository>((ref) {
  return ApiStitchRepository(ref.watch(apiClientProvider));
});

final stitchesProvider = FutureProvider<List<Stitch>>((ref) {
  return ref.watch(stitchRepositoryProvider).loadAll();
});

final favoriteStitchesProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(stitchRepositoryProvider).watchFavorites();
});

final stitchByIdProvider =
    FutureProvider.family<Stitch?, String>((ref, id) async {
  final list = await ref.watch(stitchesProvider.future);
  for (final s in list) {
    if (s.id == id) return s;
  }
  return null;
});

// ─── Patterns ─────────────────────────────────────────────────────────────

final patternRepositoryProvider = Provider<PatternRepository>((ref) {
  // Receitas vêm do backend (editáveis no painel admin). O AssetPatternRepository
  // (assets/data/patterns.json) fica como fallback histórico, não mais usado.
  return ApiPatternRepository(ref.watch(apiClientProvider));
});

final patternsProvider = FutureProvider<List<Pattern>>((ref) {
  return ref.watch(patternRepositoryProvider).loadAll();
});

final patternByIdProvider =
    FutureProvider.family<Pattern?, String>((ref, id) async {
  return ref.watch(patternRepositoryProvider).getById(id);
});

// ─── AI Analysis ──────────────────────────────────────────────────────────

final analysisServiceProvider = Provider<AnalysisService>((ref) {
  return AnalysisService(ref.watch(authServiceProvider));
});

final analysisRepositoryProvider = Provider<AnalysisRepository>((_) {
  return HiveAnalysisRepository();
});

final recentAnalysesProvider = Provider<List<AiAnalysis>>((ref) {
  return ref.watch(analysisRepositoryProvider).recent();
});

final analysisByIdProvider = Provider.family<AiAnalysis?, String>((ref, id) {
  return ref.watch(analysisRepositoryProvider).getById(id);
});
