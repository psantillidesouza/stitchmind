import 'package:shared_preferences/shared_preferences.dart';

/// Estado leve de aplicação consultado pelo router em tempo de redirect.
/// Carregado uma vez no [main()] após o bootstrap do Hive.
class AppState {
  AppState._();

  static const _onboardingKey = 'onboarding_seen_v1';
  static const _preferredNameKey = 'preferred_name_v1';
  static const _reviewRequestedKey = 'review_requested_v1';
  static const _communityGuidelinesKey = 'community_guidelines_accepted_v1';

  static bool onboardingSeen = false;

  /// Aceitou as diretrizes da comunidade? (exigido antes da 1ª publicação —
  /// requisito de UGC da App Store/Play.)
  static bool communityGuidelinesAccepted = false;

  /// Já pedimos a avaliação nativa da loja uma vez? (evita repetir/spam.)
  static bool reviewRequested = false;

  /// A paywall já foi mostrada NESTE launch? (em memória, reseta a cada cold
  /// start.) Garante que não-assinantes vejam a paywall toda vez que abrem o
  /// app, mas só uma vez por sessão (o X dispensa até a próxima abertura).
  static bool paywallShownThisLaunch = false;

  /// Como a pessoa quer ser chamada (coletado no onboarding, antes do login).
  /// Aplicado ao perfil do Firebase no primeiro login.
  static String? preferredName;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingSeen = prefs.getBool(_onboardingKey) ?? false;
    reviewRequested = prefs.getBool(_reviewRequestedKey) ?? false;
    communityGuidelinesAccepted = prefs.getBool(_communityGuidelinesKey) ?? false;
    final name = prefs.getString(_preferredNameKey)?.trim();
    preferredName = (name != null && name.isNotEmpty) ? name : null;
  }

  static Future<void> markReviewRequested() async {
    reviewRequested = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reviewRequestedKey, true);
  }

  static Future<void> markCommunityGuidelinesAccepted() async {
    communityGuidelinesAccepted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_communityGuidelinesKey, true);
  }

  static Future<void> markOnboardingSeen() async {
    onboardingSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  static Future<void> setPreferredName(String name) async {
    final trimmed = name.trim();
    preferredName = trimmed.isEmpty ? null : trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (preferredName == null) {
      await prefs.remove(_preferredNameKey);
    } else {
      await prefs.setString(_preferredNameKey, preferredName!);
    }
  }
}
