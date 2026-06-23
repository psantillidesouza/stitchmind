import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/entities/entities.dart';
import 'hive_init.dart';

/// Persistência local das receitas importadas pelo usuário (PDF/link/texto →
/// IA → estrutura). Guarda o JSON normalizado do servidor (mesmo contrato de
/// [Pattern.fromJson]), com um carimbo `_importedAt` para ordenar.
class ImportedPatternsStore {
  Box<String> get _box => Hive.box<String>(HiveBoxes.importedPatterns);

  List<Map<String, dynamic>> _decoded() {
    return _box.values
        .map((s) {
          try {
            return jsonDecode(s) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => ((b['_importedAt'] as num?) ?? 0)
          .compareTo((a['_importedAt'] as num?) ?? 0));
  }

  /// Receitas importadas, mais recentes primeiro.
  List<Pattern> all() => _decoded().map(Pattern.fromJson).toList();

  Pattern? getById(String id) {
    final s = _box.get(id);
    if (s == null) return null;
    try {
      return Pattern.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Salva o JSON da receita (vindo do `/patterns/import`). Devolve o [Pattern].
  Future<Pattern> add(Map<String, dynamic> patternJson) async {
    final id = (patternJson['id'] ??
            'imp_${DateTime.now().millisecondsSinceEpoch}')
        .toString();
    final withMeta = <String, dynamic>{
      ...patternJson,
      'id': id,
      '_importedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _box.put(id, jsonEncode(withMeta));
    return Pattern.fromJson(withMeta);
  }

  Future<void> remove(String id) => _box.delete(id);
}
