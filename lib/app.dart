import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/telemetry/screen_observer.dart';
import 'core/theme/app_theme.dart';
import 'data/services/firebase_auth_service.dart';
import 'data/services/push_service.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers/platform_providers.dart';

class StitchMindApp extends ConsumerStatefulWidget {
  const StitchMindApp({super.key});

  @override
  ConsumerState<StitchMindApp> createState() => _StitchMindAppState();
}

class _StitchMindAppState extends ConsumerState<StitchMindApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final telemetry = ref.read(telemetryProvider);
    final realtime = ref.read(realtimeProvider);
    final auth = ref.read(authServiceProvider) as FirebaseAuthService;
    final subscription = ref.read(subscriptionServiceProvider);
    final analytics = ref.read(analyticsServiceProvider);
    _router = createRouter(
      observerFactory: () => TelemetryNavigatorObserver(telemetry, realtime),
      // Screen views automáticas no Firebase Analytics (1 observer/navigator).
      analyticsObserverFactory: () => analytics.observer(),
      isSignedIn: () => auth.isSignedIn,
      // Reavalia o redirect quando login muda (e premium, p/ a UI reagir).
      authListenable: Listenable.merge([auth, subscription]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tapTracker = ref.read(tapTrackerProvider);
    return MaterialApp.router(
      title: 'StitchMind',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: pushMessengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      // Idioma: SEMPRE inglês (independente do aparelho). As traduções PT
      // continuam disponíveis em app_strings.dart caso queira reativar depois.
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('pt')],
      routerConfig: _router,
      // Listener global: captura toques para heatmap + rage/dead tap.
      builder: (context, child) {
        final size = MediaQuery.of(context).size;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerUp: (e) => tapTracker.onTap(e.position, size),
          // Tocar fora de um campo de texto fecha o teclado (global).
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
