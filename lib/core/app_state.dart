import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'feature_flags.dart';

/// Estado leve de aplicação consultado pelo router em tempo de redirect.
/// Carregado uma vez no [main()] após o bootstrap do Hive.
class AppState {
  AppState._();

  static const _onboardingKey = 'onboarding_seen_v1';
  static const _preferredNameKey = 'preferred_name_v1';
  static const _reviewLastRequestKey = 'review_last_request_v1';
  static const _communityGuidelinesKey = 'community_guidelines_accepted_v1';
  static const _paywallVariantKey = 'paywall_variant_v1';
  static const _annualOfferLastShownKey = 'annual_offer_last_shown_v1';

  static bool onboardingSeen = false;

  /// Aceitou as diretrizes da comunidade? (exigido antes da 1ª publicação —
  /// requisito de UGC da App Store/Play.)
  static bool communityGuidelinesAccepted = false;

  /// Última vez que pedimos a avaliação nativa da loja. Persistida — limita
  /// o pedido a no máximo 1x por dia (a loja ainda aplica os limites dela).
  static DateTime? reviewLastRequest;

  /// Pode pedir avaliação agora? Só depois do onboarding e no máximo 1x/dia.
  static bool canRequestReview() {
    if (!onboardingSeen) return false;
    final last = reviewLastRequest;
    return last == null ||
        DateTime.now().difference(last) >= const Duration(days: 1);
  }

  /// A paywall já foi mostrada NESTE launch? (em memória, reseta a cada cold
  /// start.) Garante que não-assinantes vejam a paywall toda vez que abrem o
  /// app, mas só uma vez por sessão (o X dispensa até a próxima abertura).
  static bool paywallShownThisLaunch = false;

  /// Oferta de saída (anual + 3 dias grátis) "armada" para o PRÓXIMO paywall.
  /// Ligada SOMENTE ao finalizar o onboarding pela 1ª vez (ver
  /// [markOnboardingSeen]); o paywall pós-onboarding consome via
  /// [consumeAnnualOfferPending] e mostra a oferta se for fechado no X.
  /// Não aparece em nenhum outro paywall (aberturas seguintes, CTAs premium).
  static bool _annualOfferPending = false;

  /// Lê e desarma a oferta de saída. Retorna true apenas na primeira chamada
  /// após o onboarding — quem chama é o paywall que abre logo em seguida.
  static bool consumeAnnualOfferPending() {
    final pending = _annualOfferPending;
    _annualOfferPending = false;
    return pending;
  }

  /// Última vez que a oferta anual foi exibida (qualquer origem). Persistida —
  /// controla o cooldown da reexibição periódica.
  static DateTime? annualOfferLastShown;

  /// Registra a exibição da oferta anual AGORA (chamado pela própria tela).
  static Future<void> markAnnualOfferShown() async {
    annualOfferLastShown = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_annualOfferLastShownKey,
        annualOfferLastShown!.millisecondsSinceEpoch);
  }

  /// A oferta anual pode reaparecer espontaneamente? Exige pelo menos 2 dias
  /// desde a última exibição (nunca exibida = liberada).
  static bool annualOfferCooldownOver() {
    final last = annualOfferLastShown;
    return last == null ||
        DateTime.now().difference(last) >= const Duration(days: 2);
  }

  /// Como a pessoa quer ser chamada (coletado no onboarding, antes do login).
  /// Aplicado ao perfil do Firebase no primeiro login.
  static String? preferredName;

  /// Variante de paywall sorteada para esta instalação: `'a'` (atual) ou `'b'`
  /// (design "Pro"). Vazio até a 1ª resolução. Fixa por install e persistida —
  /// ver [currentPaywallVariant].
  static String paywallVariant = '';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingSeen = prefs.getBool(_onboardingKey) ?? false;
    final lastReview = prefs.getInt(_reviewLastRequestKey);
    reviewLastRequest = lastReview != null
        ? DateTime.fromMillisecondsSinceEpoch(lastReview)
        : null;
    communityGuidelinesAccepted = prefs.getBool(_communityGuidelinesKey) ?? false;
    paywallVariant = prefs.getString(_paywallVariantKey) ?? '';
    final lastOffer = prefs.getInt(_annualOfferLastShownKey);
    annualOfferLastShown = lastOffer != null
        ? DateTime.fromMillisecondsSinceEpoch(lastOffer)
        : null;
    final name = prefs.getString(_preferredNameKey)?.trim();
    preferredName = (name != null && name.isNotEmpty) ? name : null;
  }

  /// Retorna a variante de paywall desta instalação, sorteando-a na primeira
  /// vez. Síncrono (não bloqueia a UI): quando sorteia, persiste em background.
  ///
  /// - Com [kPaywallAbEnabled] `false`: sempre `'a'` e NÃO persiste, para que
  ///   um futuro liga/desliga do teste ainda consiga sortear estas instalações.
  /// - Com o teste ligado: sorteio 50/50 fixo, persistido em [_paywallVariantKey].
  static String currentPaywallVariant() {
    if (paywallVariant == 'a' || paywallVariant == 'b') return paywallVariant;
    if (!kPaywallAbEnabled) return 'a'; // trava em A sem persistir
    final assigned = Random().nextBool() ? 'b' : 'a';
    paywallVariant = assigned;
    // Persiste sem bloquear a construção da tela.
    SharedPreferences.getInstance()
        .then((p) => p.setString(_paywallVariantKey, assigned));
    return assigned;
  }

  static Future<void> markReviewRequested() async {
    reviewLastRequest = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _reviewLastRequestKey, reviewLastRequest!.millisecondsSinceEpoch);
  }

  static Future<void> markCommunityGuidelinesAccepted() async {
    communityGuidelinesAccepted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_communityGuidelinesKey, true);
  }

  static Future<void> markOnboardingSeen() async {
    // Primeira finalização do onboarding: arma a oferta de saída pro paywall
    // que abre na sequência.
    if (!onboardingSeen) _annualOfferPending = true;
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
