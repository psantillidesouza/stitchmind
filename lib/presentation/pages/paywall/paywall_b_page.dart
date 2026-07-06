import 'package:flutter/material.dart';

import 'paywall_page.dart';

/// Variante **B** do paywall — o design "Pro" (`StitchMind Pro.dc.html`).
///
/// TODO(paywall-b): implementar aqui o layout do design "Pro". Enquanto o
/// design não é trazido para o repositório, esta variante delega para a
/// variante A ([PaywallPage]) — assim nunca mostra tela vazia — mas já registra
/// `paywall_variant: 'b'` no analytics.
///
/// Quando a tela B estiver pronta, troque o `build` abaixo pelo layout real e
/// ligue `kPaywallAbEnabled` em `lib/core/feature_flags.dart` para iniciar o
/// sorteio 50/50. A [PaywallGate] já roteia para cá automaticamente.
class PaywallProPage extends StatelessWidget {
  const PaywallProPage({this.variant = 'b', super.key});

  /// Rótulo da variante para o analytics (`paywall_variant`).
  final String variant;

  @override
  Widget build(BuildContext context) => PaywallPage(variant: variant);
}
