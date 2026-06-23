import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class Course {
  final String id;
  final String title;
  final String slug;
  final String description;
  final String? technique;
  final String? level;
  final String? coverUrl;

  const Course({
    required this.id,
    required this.title,
    required this.slug,
    this.description = '',
    this.technique,
    this.level,
    this.coverUrl,
  });

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String,
        title: j['title'] as String,
        slug: j['slug'] as String,
        description: (j['description'] as String?) ?? '',
        technique: j['technique'] as String?,
        level: j['level'] as String?,
        coverUrl: j['cover_url'] as String?,
      );
}

@immutable
class LessonProgress {
  final String status; // not_started | in_progress | completed
  final int progressPct;
  final int lastPositionS;

  const LessonProgress({
    required this.status,
    this.progressPct = 0,
    this.lastPositionS = 0,
  });

  bool get completed => status == 'completed';
  bool get started => status != 'not_started';

  factory LessonProgress.fromJson(Map<String, dynamic> j) => LessonProgress(
        status: (j['status'] as String?) ?? 'not_started',
        progressPct: (j['progress_pct'] as num?)?.toInt() ?? 0,
        lastPositionS: (j['last_position_s'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class Lesson {
  final String id;
  final String title;
  final String slug;
  final String description;
  final String? technique;
  final String? difficulty;
  final int? durationMin;
  final String? courseTitle;
  final String? coverUrl;
  final bool isPremium;
  final String? category;
  final String? categorySlug;
  final DateTime? createdAt;
  final LessonProgress? progress;

  const Lesson({
    required this.id,
    required this.title,
    required this.slug,
    this.description = '',
    this.technique,
    this.difficulty,
    this.durationMin,
    this.courseTitle,
    this.coverUrl,
    this.isPremium = false,
    this.category,
    this.categorySlug,
    this.createdAt,
    this.progress,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String,
        title: j['title'] as String,
        slug: j['slug'] as String,
        description: (j['description'] as String?) ?? '',
        technique: j['technique'] as String?,
        difficulty: j['difficulty'] as String?,
        durationMin: (j['duration_min'] as num?)?.toInt(),
        courseTitle: j['course_title'] as String?,
        coverUrl: j['cover_url'] as String?,
        isPremium: (j['is_premium'] as bool?) ?? false,
        category: j['category'] as String?,
        categorySlug: j['category_slug'] as String?,
        createdAt: DateTime.tryParse((j['created_at'] as String?) ?? ''),
        progress: j['progress'] == null
            ? null
            : LessonProgress.fromJson(j['progress'] as Map<String, dynamic>),
      );
}

@immutable
class LessonBlock {
  final String id;
  final int position;
  final String type; // text | image | video | material
  final Map<String, dynamic> content;
  final String? url; // URL assinada da mídia (se houver)

  const LessonBlock({
    required this.id,
    required this.position,
    required this.type,
    required this.content,
    this.url,
  });

  String get text => (content['text'] as String?) ?? '';
  String get filename => (content['filename'] as String?) ?? '';

  // Campos de passo (type == 'step')
  int get stepNumber => (content['number'] as num?)?.toInt() ?? 0;
  String get stepTitle => (content['title'] as String?) ?? '';
  String get stepInstruction => (content['instruction'] as String?) ?? '';
  String? get stepImageUrl => (content['image_url'] as String?) ?? url;

  factory LessonBlock.fromJson(Map<String, dynamic> j) => LessonBlock(
        id: (j['id'] ?? '').toString(),
        position: (j['position'] as num?)?.toInt() ?? 0,
        type: (j['type'] ?? 'text').toString(),
        content: _parseContent(j['content']),
        url: j['url'] as String?,
      );

  /// `content` pode chegar como objeto OU como string JSON (ou texto puro).
  /// Decodifica com tolerância para nunca quebrar a tela da aula.
  static Map<String, dynamic> _parseContent(dynamic raw) {
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
      return {'text': raw}; // texto puro vira um bloco de texto
    }
    return const {};
  }
}

@immutable
class LessonDetail {
  final Lesson lesson;
  final List<LessonBlock> blocks;
  const LessonDetail({required this.lesson, required this.blocks});
}
