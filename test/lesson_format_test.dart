import 'package:flutter_test/flutter_test.dart';
import 'package:stitchmind/core/lesson_format.dart';

void main() {
  test('parseLesson extrai passos', () {
    const md = '''
# 🌸 Sua primeira flor de crochê
Uma florzinha simples e fofa, perfeita pra começar.

## 🧶 Materiais
- **Fio** de algodão da cor que quiser
- **Agulha de crochê** 2,5–3,0 mm
- **Tesoura** e agulha de tapeçaria

## 📋 Passo a passo
1. **Anel mágico** — faça uma laçada formando um círculo que dá pra apertar depois.
2. **Miolo** — dentro do anel: 1 correntinha e 8 pontos baixos. Feche com 1 pbx e aperte o anel.
3. **Base das pétalas** — 1 corr e 1 pb em cada ponto (8 pb). Feche com 1 pbx.
4. **Pétalas** — em cada ponto: 1 pbx, 1 corr, 3 pa no mesmo ponto, 1 corr, 1 pbx. Repita até dar a volta.
5. **Arremate** — corte o fio, puxe pela última laçada e esconda as pontas.

## 💡 Dicas
- Aperte bem o anel mágico.
- Fio mais grosso = flor maior.
''';
    final p = parseLesson(md);
    print('TÍTULO: ${p.title}');
    print('INTRO: ${p.intro}');
    print('MATERIAIS (${p.materials.length}): ${p.materials}');
    print('PASSOS (${p.steps.length}):');
    for (final s in p.steps) { print('  • ${s.title}  ::  ${s.body}'); }
    print('DICAS (${p.tips.length}): ${p.tips}');
    expect(p.isStructured, true);
    expect(p.steps.length, 5);
    expect(p.materials.length, 3);
  });
}
