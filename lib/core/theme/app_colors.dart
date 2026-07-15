import 'package:flutter/material.dart';

/// Paleta "Yarn Warmth" — pêssego quente + acento coral, com uma camada
/// editorial extra (tinta café, sombras quentes, luz radial) que dá ao app
/// um ar de revista de artesanato premium.
class AppColors {
  AppColors._();

  // ── Fundos (gradiente pêssego) ──────────────────────────────────────
  static const peachTop = Color(0xFFF8D8C3);
  static const peach = Color(0xFFF7E4D7);
  static const peachSoft = Color(0xFFFAEFE7);
  static const cream = Color(0xFFFBF3EC);
  // Fundo do app: branco neutro (#FAFAFA). Superfícies (cards/nav) ficam em
  // branco puro e se separam do fundo pela sombra suave.
  static const background = Color(0xFFFAFAFA);
  static const paper = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const hairline = Color(0xFFECECEC); // borda sutil de cards no fundo claro
  static const linen = Color(0xFFEBDCCE);
  static const linenSoft = Color(0xFFF1E6DB);

  // ── Texto (tinta café, mais quente que preto puro) ──────────────────
  static const ink = Color(0xFF2B211B);
  static const walnut = Color(0xFF2B211B);
  static const walnutSoft = Color(0xFF6B5D53);
  static const walnutMuted = Color(0xFFA89A8E);

  // ── Acentos ─────────────────────────────────────────────────────────
  static const coral = Color(0xFFF2604E);
  static const coralDeep = Color(0xFFDB4631);
  static const coralSoft = Color(0xFFFBEDE8); // wash de coral p/ fundos
  static const terracotta = Color(0xFFF2604E); // alias p/ código existente
  static const terracottaDeep = Color(0xFFDB4631);
  static const ochre = Color(0xFFF5A623); // badge "Pro"
  static const ochreSoft = Color(0xFFFDF1DD); // wash de ochre p/ badges "em progresso"
  static const gold = Color(0xFFF5B731); // estrelas
  static const sage = Color(0xFF7C9A6A);
  static const sageSoft = Color(0xFFEDF1E8);

  // ── Sombra quente (não cinza neutro) ────────────────────────────────
  static const shadow = Color(0xFF4A3526);

  // ── Gradientes de capa dos patterns (tricô x crochê) ────────────────
  static const knitGradTop = Color(0xFFD4A24A);
  static const knitGradBottom = Color(0xFFC75D3C);
  static const crochetGradTop = sage; // 0xFF7C9A6A
  static const crochetGradBottom = Color(0xFF445E3A);

  // ── Superfícies escuras da paywall ──────────────────────────────────
  static const paywallBg = Color(0xFF0E0B0A);
  static const paywallCard = Color(0xFF1C1714);
  static const paywallCardLine = Color(0xFF332A25);

  // ── Dark (placeholder) ──────────────────────────────────────────────
  static const inkSurface = Color(0xFF1A1410);
  static const inkPaper = Color(0xFF231B14);
  static const inkLinen = Color(0xFF3A2E22);

}

/// Escala de raios de borda do design system.
/// card/superfícies = 24 · chip = 8 · botão preenchido = 30 · campo/botão
/// secundário = 12. Use estes tokens em vez de valores mágicos (14/16/18/20/22).
class AppRadii {
  AppRadii._();

  static const chip = 8.0;
  static const field = 12.0;
  static const card = 24.0;
  static const button = 30.0;
}

/// Estilos de texto semânticos que não têm equivalente direto no `textTheme`
/// do Material. A cor é definida por contexto via `.copyWith(color: ...)`.
class AppText {
  AppText._();

  /// Overline/eyebrow: rótulo pequeno com tracking, usado em títulos de seção
  /// e cursos (ex.: "CONTINUAR DE ONDE PAROU"). Canônico: 11 / w600 / ls 1.2.
  /// A família tipográfica herda do tema (nativa por plataforma).
  static const eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    height: 1.2,
  );

  /// Selo/badge: texto de pílula pequena (Premium, WIP, tipo de post).
  /// Canônico: 11 / w600 / ls 0.3.
  static const badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
}
