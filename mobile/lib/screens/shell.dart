import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../state/auth.dart';
import '../state/interests.dart';
import '../state/providers.dart';
import '../widgets/avatar.dart';
import '../widgets/states.dart';

/// Bottom navigation: Baş sahypa, Gözleg, Döret (+), Reels, Profil.
/// Top 10 opens from the home app bar and the search screen.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const homeIndex = 0;
  static const createIndex = 2;
  static const profileIndex = 4;

  /// After logging in or registering, asks once "Näme bilen
  /// gyzyklanýarsyňyz?" while the server says nothing was picked.
  static Future<void> _maybeAskInterests(
    BuildContext context,
    WidgetRef ref,
    int userId,
  ) async {
    final ask = await shouldPromptInterests(
      ref.read(usersRepositoryProvider),
      userId,
    );
    if (!ask || !context.mounted) return;
    final router = GoRouter.of(context);
    // Let the login / register screen close first (it pops itself).
    for (var i = 0; i < 20; i++) {
      final path = router.state.uri.path;
      if (!path.startsWith('/login') && !path.startsWith('/register')) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!context.mounted || ref.read(currentUserIdProvider) != userId) return;
    await router.push('/interests');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final me = ref.watch(authProvider.select((s) => s.user));
    // A sign-in in this session (not the startup restore of a stored token).
    ref.listen(authProvider, (prev, next) {
      final id = next.user?.id;
      if (prev == null || !prev.ready || prev.user != null || id == null) {
        return;
      }
      _maybeAskInterests(context, ref, id);
    });

    Widget profileIcon(bool active) {
      if (me == null) {
        return Icon(
          active ? Icons.person_rounded : Icons.person_outline_rounded,
        );
      }
      return Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? AppPalette.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: UserAvatar(user: me, size: 24),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: S.tabHome,
            ),
            const NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(Icons.manage_search_rounded),
              label: S.tabSearch,
            ),
            const NavigationDestination(
              icon: _CreateIcon(active: false),
              selectedIcon: _CreateIcon(active: true),
              label: S.tabCreate,
            ),
            const NavigationDestination(
              icon: Icon(Icons.movie_outlined),
              selectedIcon: Icon(Icons.movie_rounded),
              label: S.tabReels,
            ),
            NavigationDestination(
              icon: profileIcon(false),
              selectedIcon: profileIcon(true),
              label: S.tabProfile,
            ),
          ],
        ),
      ),
    );
  }
}

/// The red "+" create button in the bottom bar.
class _CreateIcon extends StatelessWidget {
  const _CreateIcon({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 44,
    height: 32,
    decoration: BoxDecoration(
      color: active ? AppPalette.accentHover : AppPalette.accent,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: AppPalette.accent.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
  );
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: EmptyView(
      icon: Icons.explore_off_outlined,
      title: S.notFound,
      action: FilledButton(
        onPressed: () => context.go('/'),
        child: const Text(S.tabHome),
      ),
    ),
  );
}
