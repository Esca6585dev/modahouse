import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/snack.dart';
import 'l10n/strings.dart';
import 'screens/auth_screens.dart';
import 'screens/board_screen.dart';
import 'screens/create_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/pin_detail_screen.dart';
import 'screens/pin_edit_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shell.dart';
import 'screens/user_list_screen.dart';
import 'state/auth.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

int? _intParam(GoRouterState s, String name) => int.tryParse(s.pathParameters[name] ?? '');

final routerProvider = Provider<GoRouter>((ref) {
  String? requireLogin(BuildContext context, GoRouterState state) {
    if (ref.read(authProvider).isLoggedIn) return null;
    return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
  }

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/search',
              builder: (_, s) => SearchScreen(
                initialQuery: s.uri.queryParameters['q'],
                initialCategory: s.uri.queryParameters['category'],
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/create', builder: (_, _) => const CreateScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, _) => const MyProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/pin/:id',
        builder: (_, s) => PinDetailScreen(id: _intParam(s, 'id') ?? 0),
      ),
      GoRoute(
        path: '/pin/:id/edit',
        redirect: requireLogin,
        builder: (_, s) => PinEditScreen(id: _intParam(s, 'id') ?? 0),
      ),
      GoRoute(
        path: '/user/:username',
        builder: (_, s) => UserProfileScreen(username: s.pathParameters['username'] ?? ''),
      ),
      GoRoute(
        path: '/user/:username/followers',
        builder: (_, s) => UserListScreen(username: s.pathParameters['username'] ?? '', followers: true),
      ),
      GoRoute(
        path: '/user/:username/following',
        builder: (_, s) => UserListScreen(username: s.pathParameters['username'] ?? '', followers: false),
      ),
      GoRoute(
        path: '/board/:id',
        builder: (_, s) => BoardScreen(id: _intParam(s, 'id') ?? 0),
      ),
      GoRoute(
        path: '/settings',
        redirect: requireLogin,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, s) => LoginScreen(from: s.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/register',
        builder: (_, s) => RegisterScreen(from: s.uri.queryParameters['from']),
      ),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );

  // A 401 on an authenticated request: the token was cleared, go to login.
  ref.read(authProvider.notifier).onSessionExpired = () {
    showSnack(S.sessionExpired, error: true);
    final current = router.state.uri.toString();
    if (!current.startsWith('/login')) {
      router.push('/login?from=${Uri.encodeComponent(current)}');
    }
  };
  ref.onDispose(router.dispose);
  return router;
});
