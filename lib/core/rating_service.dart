import 'package:in_app_review/in_app_review.dart';

import 'app_state.dart';

/// Pedido de avaliação nativo da loja (App Store / Google Play).
///
/// Regras: NUNCA durante o onboarding, no máximo 1x por dia (timestamp em
/// [AppState]) e só após ~5 min de sessão — o agendamento fica no MainShell.
/// É best-effort: a PRÓPRIA loja ainda decide se mostra o pop-up (há limites
/// de frequência, ex.: 3x/ano no iOS) e nada aqui bloqueia ou lança.
class RatingService {
  RatingService._();

  static final InAppReview _inAppReview = InAppReview.instance;

  /// Quanto de sessão esperar antes de pedir a avaliação.
  static const sessionDelay = Duration(minutes: 5);

  /// Solicita a avaliação nativa respeitando [AppState.canRequestReview]
  /// (pós-onboarding + 1x/dia). Não bloqueia nem lança.
  static Future<void> maybeRequest() async {
    if (!AppState.canRequestReview()) return;
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        await AppState.markReviewRequested();
      }
    } catch (_) {
      // Silencioso de propósito: avaliação nunca deve travar o app.
    }
  }
}
