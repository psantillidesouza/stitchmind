import '../../../domain/entities/entities.dart';

/// Uma carreira achatada da receita, com o nome da seção a que pertence.
typedef FlatRow = ({String section, PatternRow row});

/// View-model puro do Modo Seguir Receita: achata as seções numa lista única
/// de carreiras e resolve posição/progresso a partir do `currentRow` do
/// projeto. Sem dependência de UI → testável.
class FollowView {
  const FollowView({
    required this.flat,
    required this.total,
    required this.done,
    required this.isDone,
    required this.progress,
  });

  final List<FlatRow> flat;
  final int total;
  final int done; // carreiras concluídas (0..total)
  final bool isDone;
  final double progress;

  FlatRow? get active => isDone ? null : flat[done];
  FlatRow? get prev => done > 0 ? flat[done - 1] : null;
  FlatRow? get next => (done + 1) < total ? flat[done + 1] : null;
}

FollowView buildFollowView(Pattern pattern, int currentRow) {
  final flat = <FlatRow>[
    for (final s in pattern.sections)
      for (final r in s.rows) (section: s.title, row: r),
  ];
  final total = flat.length;
  final done = currentRow.clamp(0, total);
  final isDone = total == 0 || done >= total;
  final progress = total == 0 ? 0.0 : done / total;
  return FollowView(
    flat: flat,
    total: total,
    done: done,
    isDone: isDone,
    progress: progress,
  );
}
