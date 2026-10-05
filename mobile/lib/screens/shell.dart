import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../state/notifications_state.dart';
import '../widgets/states.dart';

/// Bottom navigation with the five tabs.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const notificationsIndex = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final p = AppPalette.of(context);

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) {
            if (i == notificationsIndex) ref.read(notificationsVisitProvider.notifier).bump();
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: S.tabHome,
            ),
            const NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(Icons.saved_search_rounded),
              label: S.tabSearch,
            ),
            NavigationDestination(
              icon: _CreateIcon(active: false, color: p.text),
              selectedIcon: _CreateIcon(active: true, color: p.text),
              label: S.tabCreate,
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unread > 0,
                backgroundColor: AppPalette.accent,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: unread > 0,
                backgroundColor: AppPalette.accent,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications_rounded),
              ),
              label: S.tabNotifications,
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: S.tabProfile,
            ),
          ],
        ),
      ),
    );
  }
}

/// The "+" create button in the bottom bar.
class _CreateIcon extends StatelessWidget {
  const _CreateIcon({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 30,
        decoration: BoxDecoration(
          color: AppPalette.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(active ? Icons.add_rounded : Icons.add_rounded, color: Colors.white, size: 24),
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
          action: FilledButton(onPressed: () => context.go('/'), child: const Text(S.tabHome)),
        ),
      );
}
