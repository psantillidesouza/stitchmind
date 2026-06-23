import '../../domain/entities/lesson.dart';
import '../services/api_client.dart';

class LessonRepository {
  LessonRepository(this._api);
  final ApiClient _api;

  Future<List<Course>> courses() async {
    final json = await _api.get('/v1/courses') as Map<String, dynamic>;
    return (json['courses'] as List)
        .cast<Map<String, dynamic>>()
        .map(Course.fromJson)
        .toList();
  }

  Future<List<Lesson>> lessons({String? technique}) async {
    final q = technique != null ? '?technique=$technique' : '';
    final json = await _api.get('/v1/lessons$q') as Map<String, dynamic>;
    return (json['lessons'] as List)
        .cast<Map<String, dynamic>>()
        .map(Lesson.fromJson)
        .toList();
  }

  Future<LessonDetail> lesson(String slug) async {
    final json = await _api.get('/v1/lessons/$slug') as Map<String, dynamic>;
    final lesson = Lesson.fromJson(json['lesson'] as Map<String, dynamic>);
    final blocks = (json['blocks'] as List)
        .cast<Map<String, dynamic>>()
        .map(LessonBlock.fromJson)
        .toList();
    return LessonDetail(lesson: lesson, blocks: blocks);
  }

  Future<void> saveProgress(
    String lessonId, {
    String? status,
    int? progressPct,
    int? lastPositionS,
  }) async {
    await _api.postSilent('/v1/lessons/$lessonId/progress', {
      if (status != null) 'status': status,
      if (progressPct != null) 'progress_pct': progressPct,
      if (lastPositionS != null) 'last_position_s': lastPositionS,
    });
  }
}
