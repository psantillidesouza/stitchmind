import 'package:flutter_test/flutter_test.dart';
import 'package:stitchmind/domain/entities/entities.dart';
import 'package:stitchmind/presentation/pages/follow/follow_model.dart';

Pattern twoSections() => Pattern.fromJson({
      'id': 'p1',
      'name': 'Hat',
      'author': 'Imported',
      'technique': 'crochet',
      'difficulty': 'beginner',
      'yarn_requirement': '',
      'estimated_hours': 1,
      'description': '',
      'sections': [
        {
          'title': 'Brim',
          'rows': [
            {'row': 1, 'instruction': 'ch 40'},
            {'row': 2, 'instruction': 'sc around', 'stitch_count': 40},
          ],
        },
        {
          'title': 'Body',
          'rows': [
            {'row': 1, 'instruction': 'dc around'},
          ],
        },
      ],
    });

void main() {
  group('buildFollowView', () {
    test('achata seções em ordem (3 carreiras, 2 seções)', () {
      final vm = buildFollowView(twoSections(), 0);
      expect(vm.total, 3);
      expect(vm.flat[0].section, 'Brim');
      expect(vm.flat[2].section, 'Body');
      expect(vm.done, 0);
      expect(vm.isDone, isFalse);
      expect(vm.active!.row.instruction, 'ch 40');
      expect(vm.prev, isNull);
      expect(vm.next!.row.instruction, 'sc around');
      expect(vm.progress, 0);
    });

    test('meio do caminho: prev/active/next atravessam seções', () {
      final vm = buildFollowView(twoSections(), 2); // 2 concluídas
      expect(vm.done, 2);
      expect(vm.active!.section, 'Body'); // entrou na 2ª seção
      expect(vm.prev!.section, 'Brim');
      expect(vm.next, isNull);
      expect(vm.progress, closeTo(2 / 3, 1e-9));
    });

    test('concluído quando done >= total', () {
      final vm = buildFollowView(twoSections(), 3);
      expect(vm.isDone, isTrue);
      expect(vm.active, isNull);
      expect(vm.progress, 1);
    });

    test('clampa overflow e valores negativos', () {
      expect(buildFollowView(twoSections(), 99).done, 3);
      expect(buildFollowView(twoSections(), -5).done, 0);
    });
  });
}
