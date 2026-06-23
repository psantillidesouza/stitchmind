import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/recent_lessons_store.dart';

/// Slugs das últimas aulas abertas (mais recente primeiro).
class RecentLessonsNotifier extends StateNotifier<List<String>> {
  RecentLessonsNotifier(this._store) : super(const []) {
    _init();
  }
  final RecentLessonsStore _store;

  Future<void> _init() async {
    final slugs = await _store.all();
    // Só hidrata se ainda não houver nada em memória. Se um `record()`
    // concorrente já preencheu o estado (abrir aula logo na inicialização),
    // não sobrescreve com a leitura antiga — senão o slug recém-gravado
    // some (condição de corrida).
    if (mounted && state.isEmpty) state = slugs;
  }

  /// Marca uma aula como recém-aberta.
  Future<void> record(String slug) async {
    final slugs = await _store.record(slug);
    if (mounted) state = slugs;
  }
}

final recentLessonsProvider =
    StateNotifierProvider<RecentLessonsNotifier, List<String>>(
  (ref) => RecentLessonsNotifier(RecentLessonsStore()),
);
