import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uma aula salva localmente no aparelho (gerada pelo Stitch ou semente).
class SavedLesson {
  const SavedLesson({
    required this.id,
    required this.title,
    required this.markdown,
    required this.createdAt,
    this.imagePath,
  });

  final String id;
  final String title;
  final String markdown;
  final int createdAt; // epoch ms
  final String? imagePath; // foto enviada (caminho persistente no aparelho)

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'markdown': markdown,
        'createdAt': createdAt,
        if (imagePath != null) 'imagePath': imagePath,
      };

  factory SavedLesson.fromJson(Map<String, dynamic> j) => SavedLesson(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? 'Lesson').toString(),
        markdown: (j['markdown'] ?? '').toString(),
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        imagePath: (j['imagePath'] as String?),
      );

  /// Extrai um título do Markdown (primeira linha `# ...`) ou usa um fallback.
  static String titleFromMarkdown(String md, {String fallback = 'Lesson'}) {
    for (final line in md.split('\n')) {
      final t = line.trim();
      if (t.startsWith('#')) {
        final clean = t.replaceAll(RegExp(r'^#+\s*'), '').trim();
        if (clean.isNotEmpty) return clean;
      }
    }
    final firstNonEmpty =
        md.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => fallback);
    return firstNonEmpty.length > 60 ? '${firstNonEmpty.substring(0, 57)}…' : firstNonEmpty;
  }
}

/// Persistência local das aulas salvas (SharedPreferences, lista JSON).
class SavedLessonsStore {
  static const _key = 'saved_lessons_v1';

  Future<List<SavedLesson>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).whereType<Map<String, dynamic>>();
      final lessons = list.map(SavedLesson.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return lessons;
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(List<SavedLesson> lessons) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(lessons.map((l) => l.toJson()).toList()),
    );
  }

  Future<List<SavedLesson>> add(SavedLesson lesson) async {
    final lessons = await all();
    lessons.removeWhere((x) => x.id == lesson.id);
    lessons.insert(0, lesson);
    await _persist(lessons);
    return lessons..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<SavedLesson>> remove(String id) async {
    final lessons = await all();
    final removed = lessons.where((x) => x.id == id).toList();
    lessons.removeWhere((x) => x.id == id);
    await _persist(lessons);
    // Limpa a foto associada (best-effort).
    for (final l in removed) {
      final p = l.imagePath;
      if (p != null) {
        try {
          final f = File(p);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
    return lessons;
  }

  /// Copia a foto para um diretório PERSISTENTE (o arquivo do image_picker é
  /// temporário e some). Devolve o caminho salvo, ou null se falhar.
  Future<String?> persistImage(String lessonId, String srcPath) async {
    try {
      final src = File(srcPath);
      if (!await src.exists()) return null;
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/saved_lessons');
      if (!await dir.exists()) await dir.create(recursive: true);
      final ext = srcPath.contains('.') ? srcPath.split('.').last : 'img';
      final dest = '${dir.path}/$lessonId.$ext';
      await src.copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }
}
