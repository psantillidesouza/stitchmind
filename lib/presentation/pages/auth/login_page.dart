import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/firebase_auth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/platform_providers.dart';
import '../../widgets/gradient_bg.dart';

/// Tela de login. Google nos dois sistemas; Apple apenas no iOS.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _busy = false;

  FirebaseAuthService get _auth =>
      ref.read(authServiceProvider) as FirebaseAuthService;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _linkSubscription();
      await _seedPreferredName();
    } on AuthFailure catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError(context.l10n.tr('login_error_generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Associa a compra (feita anônima no paywall) ao usuário do Firebase.
  Future<void> _linkSubscription() async {
    final uid = _auth.uid;
    if (uid == null) return;
    await ref.read(subscriptionServiceProvider).identify(uid);
  }

  /// Aplica, uma única vez, o nome escolhido no onboarding ao perfil recém-logado.
  Future<void> _seedPreferredName() async {
    final name = AppState.preferredName;
    if (name == null || name.isEmpty) return;
    if (!_auth.isSignedIn) return;
    try {
      await ref.read(profileServiceProvider).updateName(name);
    } catch (_) {
      // best-effort: se falhar (rede), o nome continua salvo localmente.
      return;
    }
    await AppState.setPreferredName(''); // não re-aplica em logins futuros
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.coralDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && Platform.isIOS;

    return Scaffold(
      body: GradientBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                // ── Marca (mascote, com fallback p/ o quadrado coral) ──
                Image.asset(
                  'assets/illustrations/login.png',
                  height: 168,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.coral,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: elevatedShadow(),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: AppColors.paper, size: 40),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'StitchMind',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.tr('login_subtitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(flex: 4),
                // ── Botões ─────────────────────────────────────────
                _GoogleButton(
                  enabled: !_busy,
                  onTap: () => _run(_auth.signInWithGoogle),
                ),
                if (isIOS) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 54,
                    child: SignInWithAppleButton(
                      style: SignInWithAppleButtonStyle.black,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () =>
                          _busy ? null : _run(_auth.signInWithApple),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                AnimatedOpacity(
                  opacity: _busy ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.coral),
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    context.l10n.tr('login_terms'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão "Continuar com Google" — cartão branco com o G colorido.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.linen),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _GoogleGlyph(size: 20),
                const SizedBox(width: 12),
                Text(
                  context.l10n.tr('login_continue_google'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.walnut,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "G" do Google desenhado com as 4 cores oficiais (sem asset externo).
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);
    final stroke = w * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final inner = rect.deflate(stroke / 2);

    void arc(Color c, double startDeg, double sweepDeg) {
      paint.color = c;
      canvas.drawArc(inner, startDeg * 3.1415926 / 180,
          sweepDeg * 3.1415926 / 180, false, paint);
    }

    // Quadrantes aproximados nas 4 cores da marca Google.
    arc(const Color(0xFF4285F4), -20, 80); // azul (direita)
    arc(const Color(0xFFEA4335), 130, 110); // vermelho (topo-esq)
    arc(const Color(0xFFFBBC05), 90, 60); // amarelo (esq-baixo)
    arc(const Color(0xFF34A853), 20, 70); // verde (baixo-dir)

    // Barra horizontal do "G".
    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.52, h * 0.42, w * 0.46, stroke * 0.9),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
