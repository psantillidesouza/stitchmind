import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/saved_lessons_store.dart';

/// Aula-semente (em inglês — o app é forçado em EN).
const _seedMarkdownEn = '''
# 🌸 Your first crochet flower
A simple, cute little flower — perfect to start with. It looks lovely on appliqués, hair clips and decorations.

## 🧶 Materials
- **Cotton yarn** in any color you like (and a bit of yellow for the center)
- A **crochet hook** that matches the yarn (e.g. 2.5–3.0 mm)
- **Scissors** and a **tapestry needle** (to hide the ends)

## 📋 Step by step
1. **Magic ring** — make a loop forming a circle you can tighten later.
2. **Center** — inside the ring: **1 chain** (ch) and **8 single crochet (sc)**. Close with **1 slip stitch (sl st)** in the 1st sc and **pull the ring tight**.
3. **Petal base** — **1 ch** and **1 sc in each stitch** (8 sc total). Close with **1 sl st**.
4. **Petals** — in each stitch work: **1 sl st, 1 ch, 3 double crochet (dc) in the same stitch, 1 ch, 1 sl st**. Repeat all the way around — you'll get **8 petals**.
5. **Finish** — cut the yarn, pull it through the last loop and weave in the ends with the tapestry needle.

## 💡 Tips
- **Pull the magic ring tight** so the center doesn't open up.
- Want a **bigger** flower? Use thicker yarn and a larger hook. **Smaller**? Thin yarn and a smaller hook.
- Change the **center** color for extra charm (yellow, orange or white look great).
''';

class SavedLessonsNotifier extends StateNotifier<List<SavedLesson>> {
  SavedLessonsNotifier(this._store) : super(const []) {
    _init();
  }
  final SavedLessonsStore _store;

  Future<void> _init() async {
    var lessons = await _store.all();
    if (lessons.isEmpty) {
      final md = _seedMarkdownEn.trim();
      lessons = await _store.add(SavedLesson(
        id: 'seed-flor',
        title: SavedLesson.titleFromMarkdown(md),
        markdown: md,
        createdAt: 1,
      ));
    }
    if (mounted) state = lessons;
  }

  /// Salva um tutorial (markdown) como aula, opcionalmente com a foto enviada.
  /// Devolve true se salvou.
  Future<bool> saveMarkdown(String markdown, {String? imagePath}) async {
    final md = markdown.trim();
    if (md.isEmpty || contains(md)) return false;
    final id = 'l${DateTime.now().millisecondsSinceEpoch}';
    // Copia a foto para um local persistente (o do image_picker é temporário).
    final savedImage =
        imagePath != null ? await _store.persistImage(id, imagePath) : null;
    final lesson = SavedLesson(
      id: id,
      title: SavedLesson.titleFromMarkdown(md, fallback: 'Stitch lesson'),
      markdown: md,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      imagePath: savedImage,
    );
    state = await _store.add(lesson);
    return true;
  }

  Future<void> remove(String id) async {
    state = await _store.remove(id);
  }

  bool contains(String markdown) =>
      state.any((l) => l.markdown.trim() == markdown.trim());
}

final savedLessonsProvider =
    StateNotifierProvider<SavedLessonsNotifier, List<SavedLesson>>(
  (ref) => SavedLessonsNotifier(SavedLessonsStore()),
);
