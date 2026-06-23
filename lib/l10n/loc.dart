/// Helper para strings FORA de widgets (camada de serviços), onde não há
/// BuildContext. O app está forçado em inglês (ver app.dart), então sempre EN.
const bool appLocaleIsPt = false;

/// Escolhe inglês (padrão) ou português. Como o app é forçado em EN, devolve EN.
String tr2(String en, String pt) => appLocaleIsPt ? pt : en;
