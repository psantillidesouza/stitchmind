import '../../domain/entities/entities.dart';

/// Seed de projetos usado na primeira execução do app (via Hive).
/// Pontos e receitas vivem em `assets/data/*.json` carregados pelos
/// respectivos repositórios.
class MockData {
  MockData._();

  static final projects = <Project>[
    Project(
      id: 'pr-001',
      name: 'Cardigã ocre',
      technique: StitchTechnique.knit,
      yarn: 'Lã merino 4 — mostarda',
      needle: '4,5 mm',
      status: ProjectStatus.inProgress,
      currentRow: 42,
      targetRow: 120,
      startedAt: DateTime.now().subtract(const Duration(days: 12)),
    ),
    Project(
      id: 'pr-002',
      name: 'Amigurumi raposa',
      technique: StitchTechnique.crochet,
      yarn: 'Algodão Anne — caramelo',
      needle: '2,5 mm',
      status: ProjectStatus.inProgress,
      currentRow: 18,
      targetRow: 60,
      startedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Project(
      id: 'pr-003',
      name: 'Manta de berço',
      technique: StitchTechnique.crochet,
      yarn: 'Bebê Soft — off-white',
      needle: '4 mm',
      status: ProjectStatus.paused,
      currentRow: 64,
      targetRow: 200,
      startedAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
    Project(
      id: 'pr-004',
      name: 'Echarpe linho',
      technique: StitchTechnique.knit,
      yarn: 'Linho natural — cru',
      needle: '5 mm',
      status: ProjectStatus.finished,
      currentRow: 180,
      targetRow: 180,
      startedAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
  ];
}
