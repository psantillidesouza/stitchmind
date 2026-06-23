import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_state.dart';
import 'core/config/server_config.dart';
import 'core/telemetry/crash_reporter.dart';
import 'data/local/hive_init.dart';
import 'data/services/analytics_service.dart';
import 'data/services/api_client.dart';
import 'data/services/firebase_auth_service.dart';
import 'firebase_options.dart';
import 'data/services/push_service.dart';
import 'data/services/realtime_service.dart';
import 'data/services/subscription_service.dart';
import 'data/services/tap_tracker.dart';
import 'data/services/telemetry_service.dart';
import 'presentation/providers/platform_providers.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    await HiveInit.bootstrap();
    await AppState.load();
    await ServerConfig.load();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ─── Plataforma: auth + API + telemetria + crash ───
    // Firebase Auth (Google em iOS/Android, Apple só no iOS). O backend valida
    // o ID token contra o JWKS do projeto stitchmind-b7721.
    final auth = FirebaseAuthService.create();
    final api = ApiClient(auth);
    final telemetry = TelemetryService(api);
    await telemetry.init();

    // Firebase Analytics: liga a coleta (iOS vinha desligado no plist),
    // associa o usuário e habilita screen views automáticas (via observer
    // no go_router). Eventos-chave são logados nas telas.
    final analytics = AnalyticsService();
    await analytics.init();
    await analytics.setUser(auth.uid);
    auth.addListener(() => analytics.setUser(auth.uid));

    // Assinatura (RevenueCat) — precisa estar pronta antes do 1º redirect do
    // router, que decide se mostra o paywall antes do login.
    final subscription = SubscriptionService(api);
    await subscription.init();

    // Push notifications (FCM): pede permissão e registra o token + país no
    // backend. Fire-and-forget para não travar a inicialização no diálogo de
    // permissão. O envio é feito pelo painel admin (/admin/notifications).
    PushService(api).init();

    // presença em tempo real (WebSocket)
    final realtime = RealtimeService(auth);
    realtime.configure(appVersion: telemetry.appVersion);
    await realtime.connect();

    // captura de toques (heatmap + rage/dead tap)
    final tapTracker = TapTracker(api, telemetry);
    tapTracker.start();

    final crashReporter = CrashReporter(api, telemetry);
    crashReporter.install();

    // encerra a sessão quando o app vai pro background / fecha
    WidgetsBinding.instance.addObserver(
      _Lifecycle(
        onPause: () => telemetry.flush(),
        onDetach: () {
          telemetry.endSession();
          realtime.dispose();
        },
      ),
    );

    runApp(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          telemetryProvider.overrideWithValue(telemetry),
          realtimeProvider.overrideWithValue(realtime),
          tapTrackerProvider.overrideWithValue(tapTracker),
          subscriptionServiceProvider.overrideWithValue(subscription),
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
        child: const StitchMindApp(),
      ),
    );
  }, (error, stack) {
    // erros fora do contexto do Flutter caem aqui
    if (kDebugMode) {
      // ignore: avoid_print
      print('[uncaught] $error\n$stack');
    }
  });
}

class _Lifecycle extends WidgetsBindingObserver {
  _Lifecycle({required this.onPause, required this.onDetach});
  final VoidCallback onPause;
  final VoidCallback onDetach;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) onPause();
    if (state == AppLifecycleState.detached) onDetach();
  }
}
