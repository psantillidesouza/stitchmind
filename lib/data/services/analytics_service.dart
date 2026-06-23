import 'package:firebase_analytics/firebase_analytics.dart';

/// Wrapper fino sobre o Firebase Analytics.
///
/// - `observer()` cria um [FirebaseAnalyticsObserver] NOVO por navigator
///   (não se reaproveita um observer entre navigators) → telas automáticas.
/// - Os métodos `log*` registram os eventos-chave do funil. Nenhum deles
///   pode quebrar o app: tudo passa por [_safe].
class AnalyticsService {
  AnalyticsService() : _analytics = FirebaseAnalytics.instance;
  final FirebaseAnalytics _analytics;

  FirebaseAnalytics get instance => _analytics;

  /// Observer para o go_router (1 por navigator). Usa o `name:` das rotas
  /// como nome da tela.
  FirebaseAnalyticsObserver observer() =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Liga a coleta (no iOS o plist trazia `IS_ANALYTICS_ENABLED=false`).
  Future<void> init() => _safe(() => _analytics.setAnalyticsCollectionEnabled(true));

  /// Associa os eventos ao usuário logado (ou limpa no logout).
  Future<void> setUser(String? uid) => _safe(() => _analytics.setUserId(id: uid));

  // ─── Eventos do funil ──────────────────────────────────────────────
  Future<void> logPaywallView({String? source}) => _safe(() => _analytics.logEvent(
        name: 'paywall_view',
        parameters: {if (source != null) 'source': source},
      ));

  Future<void> logPaywallPurchaseTap(String productId) => _safe(() => _analytics.logEvent(
        name: 'paywall_purchase_tap',
        parameters: {'product_id': productId},
      ));

  Future<void> logPurchaseSuccess(String productId, {double? value, String? currency}) =>
      _safe(() => _analytics.logEvent(
            name: 'purchase_success',
            parameters: {
              'product_id': productId,
              if (value != null) 'value': value,
              if (currency != null) 'currency': currency,
            },
          ));

  Future<void> logLessonOpen(String slug, {bool premium = false}) =>
      _safe(() => _analytics.logEvent(
            name: 'lesson_open',
            parameters: {'slug': slug, 'premium': premium ? 1 : 0},
          ));

  Future<void> logAnalyzePhoto() =>
      _safe(() => _analytics.logEvent(name: 'analyze_photo'));

  Future<void> _safe(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {
      // Analytics nunca derruba o app.
    }
  }
}
