import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/entities.dart';
import '../services/api_client.dart';

abstract class PatternRepository {
  Future<List<Pattern>> loadAll();
  Future<Pattern?> getById(String id);
}

/// Receitas servidas pelo backend (`GET /v1/patterns`) — fonte de verdade,
/// editável pelo painel admin sem republicar o app. Cacheia em memória.
class ApiPatternRepository implements PatternRepository {
  ApiPatternRepository(this._api);

  final ApiClient _api;
  List<Pattern>? _cache;

  @override
  Future<List<Pattern>> loadAll() async {
    if (_cache != null) return _cache!;
    final json = await _api.get('/v1/patterns') as Map<String, dynamic>;
    final list = ((json['patterns'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    _cache = list.map(Pattern.fromJson).toList(growable: false);
    return _cache!;
  }

  @override
  Future<Pattern?> getById(String id) async {
    for (final p in await loadAll()) {
      if (p.id == id) return p;
    }
    return null;
  }
}

class AssetPatternRepository implements PatternRepository {
  List<Pattern>? _cache;

  @override
  Future<List<Pattern>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/patterns.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _cache = list.map(Pattern.fromJson).toList(growable: false);
    return _cache!;
  }

  @override
  Future<Pattern?> getById(String id) async {
    final all = await loadAll();
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
