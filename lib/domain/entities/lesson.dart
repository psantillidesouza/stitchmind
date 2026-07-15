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
  // Vídeo da aula (nível lesson) com capítulos = passos com tempo.
  final String? lessonVideoUrl;
  final String? lessonVideoPoster;
  // Ficha técnica (meta preenchido no painel admin).
  final String? yarn;
  final String? mainColor;
  final String? crochetHook;
  final List<String> materials;

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
    this.lessonVideoUrl,
    this.lessonVideoPoster,
    this.yarn,
    this.mainColor,
    this.crochetHook,
    this.materials = const [],
  });

  factory Lesson.fromJson(Map<String, dynamic> j) {
    final meta = j['meta'] is Map ? j['meta'] as Map : const {};
    String? metaStr(String key) {
      final v = meta[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return Lesson(
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
      lessonVideoUrl: metaStr('video_url'),
      lessonVideoPoster: metaStr('video_poster_url'),
      // Fallback pras chaves legadas que o painel também exibe.
      yarn: metaStr('yarn') ?? metaStr('pattern_analysis'),
      mainColor: metaStr('main_color') ?? metaStr('color_sequence'),
      crochetHook: metaStr('crochet_hook'),
      materials: meta['materials'] is List
          ? (meta['materials'] as List)
              .whereType<String>()
              .where((m) => m.trim().isNotEmpty)
              .toList()
          : const [],
    );
  }
}

@immutable
class LessonBlock {
  final String id;
  final int position;
  final String type; // text | image | video | material | step
  final Map<String, dynamic> content;
  final String? url; // URL assinada da mídia (se houver)
  final String? posterUrl; // poster do vídeo (type == 'video')

  const LessonBlock({
    required this.id,
    required this.position,
    required this.type,
    required this.content,
    this.url,
    this.posterUrl,
  });

  String get text => (content['text'] as String?) ?? '';
  String get filename => (content['filename'] as String?) ?? '';

  // Título curto e descrição do vídeo (type == 'video', aba Vídeo do app).
  String get videoTitle => ((content['title'] as String?) ?? '').trim();
  String get videoDescription =>
      ((content['description'] as String?) ?? '').trim();

  // Campos de passo (type == 'step')
  int get stepNumber => (content['number'] as num?)?.toInt() ?? 0;
  String get stepTitle => (content['title'] as String?) ?? '';
  String get stepInstruction => (content['instruction'] as String?) ?? '';
  String? get stepImageUrl => (content['image_url'] as String?) ?? url;
  // Tempo do passo no vídeo da AULA (capítulo), em segundos.
  int? get stepTime => (content['time'] as num?)?.toInt();
  // Sub-passos numerados + dica + total (modelo rico do passo)
  String get stepTip => (content['tip'] as String?) ?? '';
  String get stepTotal => (content['total'] as String?) ?? '';
  // Modelo novo do passo: subtítulo + lista de instruções (máx. 10).
  String get stepSubtitle => ((content['subtitle'] as String?) ?? '').trim();

  /// Instruções numeradas do passo. Aulas antigas (sem o campo) caem nos
  /// mini-passos: o título (ou a descrição) de cada um vira uma instrução.
  List<String> get stepInstructions {
    final raw = content['instructions'];
    if (raw is List) {
      final list = raw
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    }
    return stepSubsteps
        .map((s) => s.title.isNotEmpty ? s.title : s.description)
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Sub-passos (mini-passos): cada um com [title], [description] e seu PRÓPRIO
  /// vídeo ([videoUrl]/[videoPoster], resolvidos pelo backend). Tolerante a
  /// formatos antigos {highlight, detail} e strings simples (legado).
  List<({String title, String description, String videoUrl, String? videoPoster})>
      get stepSubsteps {
    final raw = (content['substeps'] as List?) ?? const [];
    final out =
        <({String title, String description, String videoUrl, String? videoPoster})>[];
    for (final e in raw) {
      if (e is Map) {
        final t =
            (e['title'] as String?)?.trim() ?? (e['highlight'] as String?)?.trim() ?? '';
        final d =
            (e['description'] as String?)?.trim() ?? (e['detail'] as String?)?.trim() ?? '';
        final v = (e['video_url'] as String?)?.trim() ?? '';
        final vp = (e['video_poster_url'] as String?)?.trim();
        if (t.isNotEmpty || d.isNotEmpty || v.isNotEmpty) {
          out.add((title: t, description: d, videoUrl: v, videoPoster: vp));
        }
      } else if (e is String && e.trim().isNotEmpty) {
        out.add((title: e.trim(), description: '', videoUrl: '', videoPoster: null));
      }
    }
    return out;
  }

  factory LessonBlock.fromJson(Map<String, dynamic> j) => LessonBlock(
        id: (j['id'] ?? '').toString(),
        position: (j['position'] as num?)?.toInt() ?? 0,
        type: (j['type'] ?? 'text').toString(),
        content: _parseContent(j['content']),
        url: j['url'] as String?,
        posterUrl: j['poster_url'] as String?,
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
