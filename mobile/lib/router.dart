import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/snack.dart';
import 'l10n/strings.dart';
import 'screens/auth_screens.dart';
import 'models/models.dart';
import 'screens/board_screen.dart';
import 'screens/business_screens.dart';
import 'screens/cart_screens.dart';
import 'screens/create_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/orders_screens.dart';
import 'screens/pin_detail_screen.dart';
import 'screens/pin_edit_screen.dart';
import 'data/common.dart';
import 'screens/profile_screen.dart';
import 'screens/reels_screen.dart';
import 'screens/search_screen.dart';
import 'screens/server_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shell.dart';
import 'screens/shops_screen.dart';
import 'screens/story_screens.dart';
import 'screens/tag_screen.dart';
import 'screens/top_screen.dart';
import 'screens/user_list_screen.dart';
import 'screens/visual_search_screen.dart';
import 'state/auth.dart';
import 'widgets/cart_flow.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

int? _intParam(GoRouterState s, String name) =>
    int.tryParse(s.pathParameters[name] ?? '');

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
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (_, s) => SearchScreen(
                  initialQuery: s.uri.queryParameters['q'],
                  initialCategory: s.uri.queryParameters['category'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/create', builder: (_, _) => const CreateScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/reels', builder: (_, _) => const ReelsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const MyProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/top', builder: (_, _) => const TopScreen()),
      GoRoute(
        path: '/tag/:tag',
        builder: (_, s) => TagScreen(
          key: ValueKey('tag-${s.pathParameters['tag']}'),
          tag: s.pathParameters['tag'] ?? '',
        ),
      ),
      GoRoute(
        path: '/visual',
        builder: (_, s) => PhotoSearchScreen(
          image: s.extra is PickedImage ? s.extra! as PickedImage : null,
        ),
      ),
      GoRoute(
        path: '/visual/pin/:id',
        builder: (_, s) => SimilarByPhotoScreen(
          key: ValueKey('visual-${s.pathParameters['id']}'),
          pinId: _intParam(s, 'id') ?? 0,
        ),
      ),
      GoRoute(
        path: '/settings/blocked',
        redirect: requireLogin,
        builder: (_, _) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/cart',
        redirect: requireLogin,
        builder: (_, _) => const CartScreen(),
      ),
      GoRoute(
        path: '/checkout',
        redirect: requireLogin,
        builder: (_, s) => CheckoutScreen(
          args: s.extra is CheckoutArgs
              ? s.extra! as CheckoutArgs
              : const CheckoutArgs(),
        ),
      ),
      GoRoute(
        path: '/orders',
        redirect: requireLogin,
        builder: (_, _) => const MyOrdersScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        redirect: requireLogin,
        builder: (_, s) => OrderDetailScreen(
          id: _intParam(s, 'id') ?? 0,
          initial: s.extra is Order ? s.extra! as Order : null,
        ),
      ),
      GoRoute(
        path: '/business',
        redirect: requireLogin,
        builder: (_, _) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/business/setup',
        redirect: requireLogin,
        builder: (_, _) => const BusinessSetupScreen(),
      ),
      GoRoute(path: '/shops', builder: (_, _) => const ShopsScreen()),
      GoRoute(
        path: '/story/new',
        redirect: requireLogin,
        builder: (_, _) => const AddStoryScreen(),
      ),
      GoRoute(
        path: '/stories/:username',
        pageBuilder: (_, s) => CustomTransitionPage(
          key: s.pageKey,
          opaque: true,
          transitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (_, a, _, child) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(a),
              child: child,
            ),
          ),
          child: StoryViewerScreen(
            username: s.pathParameters['username'] ?? '',
            args: s.extra is StoryViewerArgs
                ? s.extra! as StoryViewerArgs
                : null,
          ),
        ),
      ),
      GoRoute(
        path: '/pin/:id',
        // Keyed by id: going from one pin to another must load the new one.
        builder: (_, s) => PinDetailScreen(
          key: ValueKey('pin-${s.pathParameters['id']}'),
          id: _intParam(s, 'id') ?? 0,
        ),
      ),
      GoRoute(
        path: '/pin/:id/edit',
        redirect: requireLogin,
        builder: (_, s) => PinEditScreen(
          key: ValueKey('pin-edit-${s.pathParameters['id']}'),
          id: _intParam(s, 'id') ?? 0,
        ),
      ),
      GoRoute(
        path: '/user/:username',
        builder: (_, s) => UserProfileScreen(
          key: ValueKey('user-${s.pathParameters['username']}'),
          username: s.pathParameters['username'] ?? '',
          initialTab: s.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: '/user/:username/followers',
        builder: (_, s) => UserListScreen(
          username: s.pathParameters['username'] ?? '',
          followers: true,
        ),
      ),
      GoRoute(
        path: '/user/:username/following',
        builder: (_, s) => UserListScreen(
          username: s.pathParameters['username'] ?? '',
          followers: false,
        ),
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
      GoRoute(path: '/server', builder: (_, _) => const ServerScreen()),
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
