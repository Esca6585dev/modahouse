import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../state/auth.dart';
import '../state/notifications_state.dart';
import '../state/shop_state.dart';

/// Icon with a small red count badge.
class BadgeIcon extends StatelessWidget {
  const BadgeIcon({super.key, required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    backgroundColor: AppPalette.accent,
    textColor: Colors.white,
    offset: const Offset(6, -5),
    label: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
    ),
    child: Icon(icon, size: 27),
  );
}

/// Cart button with the item count; opens `/cart` (login first if needed).
class CartButton extends ConsumerWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    return IconButton(
      key: const Key('cart-button'),
      tooltip: count > 0 ? '${S.cart} ($count)' : S.cart,
      onPressed: () => context.push('/cart'),
      icon: BadgeIcon(icon: Icons.shopping_bag_outlined, count: count),
    );
  }
}

/// Notifications bell with the unread count.
class NotificationsButton extends ConsumerWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final loggedIn = ref.watch(authProvider.select((s) => s.isLoggedIn));
    return IconButton(
      key: const Key('notifications-button'),
      tooltip: unread > 0 ? '${S.notifications} ($unread)' : S.notifications,
      onPressed: () {
        if (loggedIn) ref.read(notificationsVisitProvider.notifier).bump();
        context.push('/notifications');
      },
      icon: BadgeIcon(
        icon: unread > 0
            ? Icons.notifications_rounded
            : Icons.notifications_none_rounded,
        count: unread,
      ),
    );
  }
}

/// The right side of the main app bars: notifications + cart.
List<Widget> topActions() => const [
  NotificationsButton(),
  CartButton(),
  SizedBox(width: 6),
];
