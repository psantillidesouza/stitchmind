import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/entities.dart';
import '../mock/mock_data.dart';
import 'adapters.dart';

class HiveBoxes {
  static const projects = 'projects';
  static const favorites = 'favorites_stitches';
  static const analyses = 'ai_analyses';
  static const importedPatterns = 'imported_patterns_v1';
}

class HiveInit {
  HiveInit._();

  static const _seedFlag = 'seeded_v1';

  static Future<void> bootstrap() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(StitchTechniqueAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ProjectStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ProjectAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(MarkerAdapter());
    }

    await Hive.openBox<Project>(HiveBoxes.projects);
    await Hive.openBox<String>(HiveBoxes.favorites);
    await Hive.openBox<String>(HiveBoxes.analyses);
    await Hive.openBox<String>(HiveBoxes.importedPatterns);

    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_seedFlag) ?? false)) {
      final box = Hive.box<Project>(HiveBoxes.projects);
      for (final p in MockData.projects) {
        await box.put(p.id, p);
      }
      await prefs.setBool(_seedFlag, true);
    }
  }
}
