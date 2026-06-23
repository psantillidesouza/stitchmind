import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistência local dos slugs das últimas aulas ABERTAS pelo usuário.
///
/// Guarda só os slugs (a aula em si vem de `lessonsProvider`), ordenados do
/// mais recente para o mais antigo e limitados a [maxItems].
class RecentLessonsStore {
  static const _key = 'recent_lessons_v1';
  static const maxItems = 12;

  Future<List<String>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Registra a abertura de uma aula: move o slug pro topo, sem duplicar,
  /// e mantém no máximo [maxItems]. Devolve a lista atualizada.
  Future<List<String>> record(String slug) async {
    if (slug.isEmpty) return all();
    final slugs = await all();
    slugs.removeWhere((s) => s == slug);
    slugs.insert(0, slug);
    final capped =
        slugs.length > maxItems ? slugs.sublist(0, maxItems) : slugs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(capped));
    return capped;
  }
}
