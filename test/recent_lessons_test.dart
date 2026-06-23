import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stitchmind/data/local/recent_lessons_store.dart';
import 'package:stitchmind/presentation/providers/recent_lessons_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RecentLessonsStore', () {
    test('record move o slug pro topo e remove duplicata', () async {
      final store = RecentLessonsStore();
      await store.record('a');
      await store.record('b');
      final out = await store.record('a'); // 'a' volta pro topo
      expect(out, ['a', 'b']);
    });

    test('limita a maxItems mantendo os mais recentes', () async {
      final store = RecentLessonsStore();
      for (var i = 0; i < RecentLessonsStore.maxItems + 5; i++) {
        await store.record('slug$i');
      }
      final out = await store.all();
      expect(out.length, RecentLessonsStore.maxItems);
      expect(out.first, 'slug${RecentLessonsStore.maxItems + 4}'); // último gravado
    });

    test('persiste entre instâncias', () async {
      await RecentLessonsStore().record('x');
      final out = await RecentLessonsStore().all();
      expect(out, ['x']);
    });
  });

  group('RecentLessonsNotifier (corrida init x record)', () {
    test('record logo na criação não é apagado pelo _init', () async {
      // Cria o notifier (dispara _init async) e grava imediatamente —
      // simula abrir uma aula assim que o provider é criado.
      final notifier = RecentLessonsNotifier(RecentLessonsStore());
      await notifier.record('aula-aberta');
      // Dá tempo do _init concorrente terminar e tentar sobrescrever.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, contains('aula-aberta'));
    });
  });
}
