import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/entities/ai_analysis.dart';
import '../local/hive_init.dart';

abstract class AnalysisRepository {
  Future<void> save(AiAnalysis analysis);
  AiAnalysis? getById(String id);
  List<AiAnalysis> recent({int limit = 20});
  Future<void> delete(String id);
}

class HiveAnalysisRepository implements AnalysisRepository {
  Box<String> get _box => Hive.box<String>(HiveBoxes.analyses);

  @override
  Future<void> save(AiAnalysis analysis) async {
    await _box.put(analysis.id, jsonEncode(analysis.toJson()));
  }

  @override
  AiAnalysis? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return AiAnalysis.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  List<AiAnalysis> recent({int limit = 20}) {
    final all = _box.values
        .map((raw) =>
            AiAnalysis.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(limit).toList();
  }

  @override
  Future<void> delete(String id) => _box.delete(id);
}
