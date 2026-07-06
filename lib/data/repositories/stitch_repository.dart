import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/entities.dart';
import '../local/hive_init.dart';
import '../services/api_client.dart';

abstract class StitchRepository {
  Future<List<Stitch>> loadAll();
  Stream<Set<String>> watchFavorites();
  Set<String> currentFavorites();
  Future<void> toggleFavorite(String id);
}

/// Pontos servidos pelo backend (`GET /v1/stitches`) — fonte de verdade,
/// gerenciável pelo painel (inclui o vídeo da técnica). Favoritos ficam
/// locais (Hive). Cacheia a lista em memória por sessão.
class ApiStitchRepository implements StitchRepository {
  ApiStitchRepository(this._api);

  final ApiClient _api;
  List<Stitch>? _cache;

  Box<String> get _favs => Hive.box<String>(HiveBoxes.favorites);

  @override
  Future<List<Stitch>> loadAll() async {
    if (_cache != null) return _cache!;
    final json = await _api.get('/v1/stitches') as Map<String, dynamic>;
    final list = ((json['stitches'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    _cache = list.map(Stitch.fromJson).toList(growable: false);
    return _cache!;
  }

  @override
  Set<String> currentFavorites() => _favs.values.toSet();

  @override
  Stream<Set<String>> watchFavorites() async* {
    yield currentFavorites();
    await for (final _ in _favs.watch()) {
      yield currentFavorites();
    }
  }

  @override
  Future<void> toggleFavorite(String id) async {
    if (_favs.containsKey(id)) {
      await _favs.delete(id);
    } else {
      await _favs.put(id, id);
    }
  }
}

class AssetStitchRepository implements StitchRepository {
  List<Stitch>? _cache;

  Box<String> get _favs => Hive.box<String>(HiveBoxes.favorites);

  @override
  Future<List<Stitch>> loadAll() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/stitches.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _cache = list.map(Stitch.fromJson).toList(growable: false);
    return _cache!;
  }

  @override
  Set<String> currentFavorites() => _favs.values.toSet();

  @override
  Stream<Set<String>> watchFavorites() async* {
    yield currentFavorites();
    await for (final _ in _favs.watch()) {
      yield currentFavorites();
    }
  }

  @override
  Future<void> toggleFavorite(String id) async {
    if (_favs.containsKey(id)) {
      await _favs.delete(id);
    } else {
      await _favs.put(id, id);
    }
  }
}
