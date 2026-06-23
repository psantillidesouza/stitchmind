import 'package:in_app_review/in_app_review.dart';

import 'app_state.dart';

/// Pedido de avaliação nativo da loja (App Store / Google Play).
///
/// É best-effort: a PRÓPRIA loja decide se mostra o pop-up (há limites de
/// frequência). Pedimos no máximo UMA vez (flag em [AppState]) e nunca
/// quebramos o fluxo se algo falhar.
class RatingService {
  RatingService._();

  static final InAppReview _inAppReview = InAppReview.instance;

  /// Solicita a avaliação nativa uma única vez. Não bloqueia nem lança.
  static Future<void> maybeRequest() async {
    if (AppState.reviewRequested) return;
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        await AppState.markReviewRequested();
      }
    } catch (_) {
      // Silencioso de propósito: avaliação nunca deve travar o onboarding.
    }
  }
}
