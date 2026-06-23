import 'package:hive/hive.dart';

import '../../domain/entities/entities.dart';
import '../local/hive_init.dart';

abstract class ProjectRepository {
  List<Project> getAll();
  Project? getById(String id);
  Future<void> upsert(Project project);
  Future<void> delete(String id);
  Stream<List<Project>> watchAll();
}

class HiveProjectRepository implements ProjectRepository {
  Box<Project> get _box => Hive.box<Project>(HiveBoxes.projects);

  @override
  List<Project> getAll() {
    final all = _box.values.toList();
    all.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return all;
  }

  @override
  Project? getById(String id) => _box.get(id);

  @override
  Future<void> upsert(Project project) => _box.put(project.id, project);

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Stream<List<Project>> watchAll() async* {
    yield getAll();
    await for (final _ in _box.watch()) {
      yield getAll();
    }
  }
}
