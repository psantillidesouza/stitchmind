import 'package:flutter/foundation.dart';

/// Tipografia padrão do app: fonte nativa de cada plataforma.
/// Android → Roboto · iOS/macOS → SF Pro Display (San Francisco).
///
/// Pesos padronizados: texto corrido = w400 (regular) · títulos = w600
/// (semi-bold). Não use w700/w800 nem `fontFamily` hardcoded — a família
/// vem do tema e este token só é necessário em estilos que não herdam do
/// `textTheme` (component themes, overlays).
class AppFonts {
  AppFonts._();

  static String get family => switch (defaultTargetPlatform) {
        TargetPlatform.iOS ||
        TargetPlatform.macOS =>
          'CupertinoSystemDisplay', // mapeado pela engine para SF Pro Display
        _ => 'Roboto',
      };
}
