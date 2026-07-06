import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/community.dart';
import '../feature_flags.dart';
import '../../presentation/main_shell.dart';
import '../../presentation/pages/analyze/analyze_page.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/aulas/aulas_page.dart';
import '../../presentation/pages/aulas_salvas/saved_lessons_page.dart';
import '../../presentation/pages/community/community_page.dart';
import '../../presentation/pages/community/post_detail_page.dart';
import '../../presentation/pages/community/publish_post_page.dart';
import '../../presentation/pages/community/user_profile_page.dart';
import '../../presentation/pages/ferramentas/chat_page.dart';
import '../../presentation/pages/follow/follow_pattern_page.dart';
import '../../presentation/pages/import/import_pattern_page.dart';
import '../../presentation/pages/inicio/inicio_page.dart';
import '../../presentation/pages/painel/lesson_detail_page.dart';
import '../../presentation/pages/onboarding/onboarding_page.dart';
import '../../presentation/pages/patterns/pattern_detail_page.dart';
import '../../presentation/pages/patterns/patterns_page.dart';
import '../../presentation/pages/paywall/paywall_page.dart';
import '../../presentation/pages/perfil/perfil_page.dart';
import '../../presentation/pages/stitches/stitch_detail_page.dart';
import '../../presentation/pages/stitches/stitch_library_page.dart';
import '../app_state.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// Cria o router. `observerFactory` produz um observer NOVO por navigator.
///
/// [isSignedIn] decide se o usuário já autenticou (Firebase); [authListenable]
/// faz o router reavaliar o redirect quando o login/logout acontece.
GoRouter createRouter({
  NavigatorObserver Function()? observerFactory,
  NavigatorObserver Function()? analyticsObserverFactory,
  bool Function()? isSignedIn,
  Listenable? authListenable,
}) {
  List<NavigatorObserver> obs() => [
        if (observerFactory != null) observerFactory(),
        if (analyticsObserverFactory != null) analyticsObserverFactory(),
      ];
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    observers: obs(),
    refreshListenable: authListenable,
    redirect: (_, state) {
      final loc = state.matchedLocation;
      final signedIn = isSignedIn?.call() ?? true;

      // Comunidade desativada por enquanto: bloqueia qualquer rota /community.
      if (!kCommunityEnabled && loc.startsWith('/community')) return '/';

      // Paywall é SOFT: acessível por push, nunca obriga. Não redireciona.
      if (loc == '/paywall') return null;

      // 1) Onboarding sempre primeiro.
      if (!AppState.onboardingSeen) {
        return loc == '/onboarding' ? null : '/onboarding';
      }
      if (loc == '/onboarding') return signedIn ? '/' : '/login';

      // 2) Login depois do onboarding (grátis — sem exigir assinatura).
      if (!signedIn) return loc == '/login' ? null : '/login';
      if (loc == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/onboarding',
        pageBuilder: (_, state) => const NoTransitionPage(
          name: 'onboarding',
          child: OnboardingPage(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/paywall',
        pageBuilder: (_, state) => const NoTransitionPage(
          name: 'paywall',
          child: PaywallGate(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/login',
        pageBuilder: (_, state) => const NoTransitionPage(
          name: 'login',
          child: LoginPage(),
        ),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        observers: obs(),
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'inicio',
            pageBuilder: (_, state) =>
                const NoTransitionPage(name: 'inicio', child: InicioPage()),
          ),
          GoRoute(
            path: '/aulas',
            name: 'aulas',
            pageBuilder: (_, state) =>
                const NoTransitionPage(name: 'aulas', child: AulasPage()),
          ),
          GoRoute(
            path: '/community',
            name: 'community',
            pageBuilder: (_, state) =>
                const NoTransitionPage(name: 'community', child: CommunityPage()),
          ),
          GoRoute(
            path: '/perfil',
            name: 'perfil',
            pageBuilder: (_, state) =>
                const NoTransitionPage(name: 'perfil', child: PerfilPage()),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/community/publish',
        pageBuilder: (_, state) =>
            const MaterialPage(name: 'community_publish', child: PublishPostPage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/community/post/:id',
        pageBuilder: (_, state) => MaterialPage(
          name: 'community_post',
          child: PostDetailPage(
            postId: state.pathParameters['id']!,
            post: state.extra is Post ? state.extra as Post : null,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/community/user/:id',
        pageBuilder: (_, state) => MaterialPage(
          name: 'community_user',
          child: UserProfilePage(userId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/lessons/:slug',
        name: 'lesson_detail',
        pageBuilder: (_, state) => MaterialPage(
          name: 'lesson_detail',
          child: LessonDetailPage(slug: state.pathParameters['slug']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/analyze',
        pageBuilder: (_, state) =>
            const MaterialPage(name: 'analyze', child: AnalyzePage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/chat',
        pageBuilder: (_, state) =>
            const MaterialPage(name: 'chat', child: ChatPage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/import',
        pageBuilder: (_, state) =>
            const MaterialPage(name: 'import', child: ImportPatternPage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/follow/:patternId',
        pageBuilder: (_, state) => MaterialPage(
          name: 'follow',
          child: FollowPatternPage(
              patternId: state.pathParameters['patternId']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/patterns',
        pageBuilder: (_, state) =>
            const MaterialPage(name: 'patterns', child: PatternsPage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/patterns/:patternId',
        pageBuilder: (_, state) => MaterialPage(
          name: 'pattern_detail',
          child: PatternDetailPage(
              patternId: state.pathParameters['patternId']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/stitches',
        pageBuilder: (_, state) =>
            const MaterialPage(name: 'stitches', child: StitchLibraryPage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/stitches/:id',
        pageBuilder: (_, state) => MaterialPage(
          name: 'stitch_detail',
          child: StitchDetailPage(stitchId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/aulas-salvas',
        pageBuilder: (_, state) =>
            const MaterialPage(name: 'aulas_salvas', child: SavedLessonsPage()),
      ),
    ],
  );
}
