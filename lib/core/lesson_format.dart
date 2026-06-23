import '../data/local/saved_lessons_store.dart';

/// Um passo da aula (título + instrução), no estilo das aulas do app.
class LessonStep {
  const LessonStep(this.title, this.body);
  final String title;
  final String body;
}

/// Aula estruturada, parseada do Markdown gerado pelo Stitch.
class ParsedLesson {
  const ParsedLesson({
    required this.title,
    required this.intro,
    required this.materials,
    required this.steps,
    required this.tips,
  });

  final String title;
  final String intro;
  final List<String> materials;
  final List<LessonStep> steps;
  final List<String> tips;

  /// Tem estrutura suficiente pra renderizar em cards (senão, cai no Markdown).
  bool get isStructured => steps.length >= 2;
}

String _stripMd(String s) => s
    .replaceAll(RegExp(r'\*\*|__|`'), '')
    .replaceAll(RegExp(r'^\s*[-*]\s+'), '')
    .trim();

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-zà-ú ]'), '').trim();

String? _bullet(String t) {
  final m = RegExp(r'^[-*]\s+(.*)$').firstMatch(t);
  return m?.group(1);
}

LessonStep _parseStep(String text) {
  final t = text.trim();
  // **Título** — corpo   |   **Título:** corpo   |   **Título** corpo
  final bold = RegExp(r'^\*\*(.+?)\*\*\s*[—:\-–]*\s*([\s\S]*)$').firstMatch(t);
  if (bold != null) {
    final title = bold.group(1)!.trim().replaceAll(RegExp(r'[:.]$'), '');
    final body = _stripMd(bold.group(2)!).trim();
    return LessonStep(title, body.isEmpty ? title : body);
  }
  // sem negrito: usa a 1ª frase curta como título
  final clean = _stripMd(t);
  final dot = clean.indexOf(RegExp(r'[.!?:]'));
  if (dot > 2 && dot < 64) {
    final title = clean.substring(0, dot).trim();
    final body = clean.substring(dot + 1).trim();
    return LessonStep(title, body.isEmpty ? clean : body);
  }
  return LessonStep('Passo', clean);
}

/// Parseia o Markdown da IA em: título, intro, materiais, passos e dicas.
ParsedLesson parseLesson(String markdown) {
  final lines = markdown.replaceAll('\r', '').split('\n');
  String title = '';
  final intro = StringBuffer();
  final materials = <String>[];
  final steps = <LessonStep>[];
  final tips = <String>[];

  String section = 'intro'; // intro | materials | steps | tips | other
  String? stepBuf;
  void flush() {
    if (stepBuf != null && stepBuf!.trim().isNotEmpty) {
      steps.add(_parseStep(stepBuf!));
    }
    stepBuf = null;
  }

  for (final raw in lines) {
    final t = raw.trim();
    // Título principal (# ...), ignorando ## e ###
    if (title.isEmpty && RegExp(r'^#\s+\S').hasMatch(t)) {
      title = _stripMd(t.replaceFirst(RegExp(r'^#\s+'), ''));
      continue;
    }
    // Cabeçalhos de seção (## / ###)
    if (RegExp(r'^#{2,}\s+').hasMatch(t)) {
      flush();
      final h = _norm(t.replaceFirst(RegExp(r'^#{2,}\s+'), ''));
      if (h.contains('materi')) {
        section = 'materials';
      } else if (h.contains('passo') ||
          h.contains('etapa') ||
          h.contains('como fazer') ||
          h.contains('tutorial')) {
        section = 'steps';
      } else if (h.contains('dica') ||
          h.contains('varia') ||
          h.contains('observa')) {
        section = 'tips';
      } else {
        section = 'other';
      }
      continue;
    }

    switch (section) {
      case 'intro':
        if (t.isNotEmpty) {
          if (intro.isNotEmpty) intro.write(' ');
          intro.write(_stripMd(t));
        }
        break;
      case 'materials':
        final b = _bullet(t);
        if (b != null) materials.add(_stripMd(b));
        break;
      case 'steps':
        final num = RegExp(r'^\d+[.)]\s+(.*)$').firstMatch(t);
        if (num != null) {
          flush();
          stepBuf = num.group(1);
        } else if (t.isNotEmpty && stepBuf != null) {
          final sub = _bullet(t);
          stepBuf = '$stepBuf\n${sub ?? t}';
        }
        break;
      case 'tips':
        final b = _bullet(t);
        if (b != null) tips.add(_stripMd(b));
        break;
      default:
        break;
    }
  }
  flush();

  return ParsedLesson(
    title: title.isEmpty ? SavedLesson.titleFromMarkdown(markdown) : title,
    intro: intro.toString().trim(),
    materials: materials,
    steps: steps,
    tips: tips,
  );
}
