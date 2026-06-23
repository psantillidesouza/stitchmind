import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/imported_patterns_store.dart';
import '../../data/services/pattern_import_service.dart';
import '../../domain/entities/entities.dart';
import 'platform_providers.dart';
import 'providers.dart';

final importedPatternsStoreProvider =
    Provider<ImportedPatternsStore>((ref) => ImportedPatternsStore());

final patternImportServiceProvider = Provider<PatternImportService>(
  (ref) => PatternImportService(ref.watch(apiClientProvider)),
);

/// Receitas importadas (mais recentes primeiro). O box do Hive já está aberto
/// no boot, então a leitura é síncrona — sem corrida init/escrita.
class ImportedPatternsNotifier extends StateNotifier<List<Pattern>> {
  ImportedPatternsNotifier(this._store) : super(_store.all());
  final ImportedPatternsStore _store;

  Future<Pattern> save(Map<String, dynamic> patternJson) async {
    final p = await _store.add(patternJson);
    state = _store.all();
    return p;
  }

  Future<void> remove(String id) async {
    await _store.remove(id);
    state = _store.all();
  }
}

final importedPatternsProvider =
    StateNotifierProvider<ImportedPatternsNotifier, List<Pattern>>(
  (ref) => ImportedPatternsNotifier(ref.watch(importedPatternsStoreProvider)),
);

/// Resolve uma receita por id em ambas as fontes: importadas (local) primeiro,
/// senão o catálogo (asset). Usado pelo Modo Seguir Receita.
final resolvePatternProvider =
    FutureProvider.family<Pattern?, String>((ref, id) async {
  final imported = ref.watch(importedPatternsStoreProvider).getById(id);
  if (imported != null) return imported;
  return ref.watch(patternByIdProvider(id).future);
});
