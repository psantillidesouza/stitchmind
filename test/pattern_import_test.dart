import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:stitchmind/data/local/hive_init.dart';
import 'package:stitchmind/data/local/imported_patterns_store.dart';
import 'package:stitchmind/domain/entities/entities.dart';

/// JSON exatamente no formato que o servidor (`normalize` em
/// patternExtractor.ts) devolve em `/v1/patterns/import`.
Map<String, dynamic> serverPattern() => {
      'id': 'imp_abc',
      'name': 'Test flower',
      'author': 'Imported',
      'technique': 'crochet',
      'difficulty': 'beginner',
      'yarn_requirement': 'Cotton',
      'suggested_needle': '3.0 mm',
      'estimated_hours': 1,
      'description': 'A small flower.',
      'sections': [
        {
          'title': 'Center',
          'subtitle': null,
          'rows': [
            {'row': 1, 'instruction': 'Magic ring, 8 sc', 'stitch_count': 8},
            {'row': 2, 'instruction': 'inc around', 'stitch_count': 16},
          ],
        },
      ],
    };

void main() {
  group('Contrato servidor → Pattern.fromJson', () {
    test('parseia a saída do /patterns/import', () {
      final p = Pattern.fromJson(serverPattern());
      expect(p.name, 'Test flower');
      expect(p.technique, StitchTechnique.crochet);
      expect(p.difficulty, Difficulty.beginner);
      expect(p.suggestedNeedle, '3.0 mm');
      expect(p.sections, hasLength(1));
      expect(p.totalRows, 2);
      expect(p.sections.first.rows.first.stitchCount, 8);
    });

    test('abbrev_glossary é opcional', () {
      expect(Pattern.fromJson(serverPattern()).abbrevGlossary, isNull);
      final withG = Pattern.fromJson({
        ...serverPattern(),
        'abbrev_glossary': {'sc': 'single crochet', 'ch': 'chain'},
      });
      expect(withG.abbrevGlossary, isNotNull);
      expect(withG.abbrevGlossary!['sc'], 'single crochet');
    });
  });

  group('ImportedPatternsStore', () {
    late Directory dir;
    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('imp_test');
      Hive.init(dir.path);
      await Hive.openBox<String>(HiveBoxes.importedPatterns);
    });
    tearDownAll(() async {
      await Hive.deleteBoxFromDisk(HiveBoxes.importedPatterns);
      await dir.delete(recursive: true);
    });

    test('add → all → getById faz round-trip', () async {
      final store = ImportedPatternsStore();
      final saved = await store.add(serverPattern());
      expect(saved.totalRows, 2);

      final all = store.all();
      expect(all, isNotEmpty);
      expect(all.any((p) => p.id == 'imp_abc'), isTrue);

      final fetched = store.getById('imp_abc');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Test flower');

      await store.remove('imp_abc');
      expect(store.getById('imp_abc'), isNull);
    });
  });
}
