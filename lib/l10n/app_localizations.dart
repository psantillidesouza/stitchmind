import 'package:flutter/widgets.dart';

import 'app_strings.dart';

/// Localização leve baseada em mapas (EN padrão + PT).
///
/// Uso nas telas: `context.l10n.tr('chave')` ou, com variáveis,
/// `context.l10n.tr('chave', {'n': '5'})` (a string usa `{n}`).
class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      AppLocalizations(const Locale('en'));

  bool get isPt => locale.languageCode == 'pt';

  Map<String, String> get _table => isPt ? ptStrings : enStrings;

  /// Traduz [key]. Cai no inglês e, por fim, na própria chave se faltar.
  String tr(String key, [Map<String, String>? params]) {
    var s = _table[key] ?? enStrings[key] ?? key;
    if (params != null) {
      params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    }
    return s;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['en', 'pt'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
