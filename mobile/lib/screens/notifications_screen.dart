import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/notifications_state.dart';
import '../state/paged_controller.dart';
import '../state/providers.dart';
import '../widgets/app_image.dart';
import '../widgets/avatar.dart';
import '../widgets/states.dart';

String notificationText(NotificationType type) {
  switch (type) {
    case NotificationType.like:
      return S.notifLike;
    case NotificationType.comment:
      return S.notifComment;
    case NotificationType.save:
      return S.notifSave;
    case NotificationType.follow:
      return S.notifFollow;
    case NotificationType.unknown:
      return '';
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(S.notifications)),
      body: userId == null
          ? const LoginPrompt(
              text: S.loginPromptNotifications,
              from: '/notifications',
              icon: Icons.notifications_none_rounded,
            )
          : _NotificationsList(key: ValueKey(userId)),
    );
  }
}

class _NotificationsList extends ConsumerStatefulWidget {
  const _NotificationsList({super.key});

  @override
  ConsumerState<_NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends ConsumerState<_NotificationsList> {
  late final PagedController<Notification> _items = PagedController(
    (page) => ref.read(notificationsRepositoryProvider).list(page),
    autoload: false,
  );

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _items.dispose();
    super.dispose();
  }

  /// Load the newest notifications, then mark everything as read.
  Future<void> _open() async {
    await _items.refresh();
    if (_items.error != null) return;
    try {
      await ref.read(notificationsRepositoryProvider).readAll();
      if (mounted) ref.read(unreadCountProvider.notifier).reset();
    } catch (_) {
      // Not critical: the badge will catch up on the next poll.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notificationsVisitProvider, (_, _) => _open());
    return ListenableBuilder(
      listenable: _items,
      builder: (context, _) {
        if (!_items.loaded) return const LoadingView();
        if (_items.error != null && _items.items.isEmpty) {
          return ErrorView(error: _items.error!, onRetry: _open);
        }
        final items = _items.items;
        return RefreshIndicator(
          color: AppPalette.accent,
          onRefresh: _open,
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    EmptyView(
                      icon: Icons.notifications_none_rounded,
                      title: S.noNotificationsTitle,
                      text: S.noNotificationsText,
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  itemCount: items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == items.length) return _footer();
                    if (i >= items.length - 5) _maybeLoadMore();
                    return _NotificationTile(n: items[i]);
                  },
                ),
        );
      },
    );
  }

  void _maybeLoadMore() {
    if (_items.hasMore && !_items.loading && _items.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _items.loadMore());
    }
  }

  Widget _footer() {
    if (_items.loading) {
      return const SizedBox(height: 56, child: Center(child: Spinner()));
    }
    if (_items.error != null) {
      return Center(
        child: TextButton(
          onPressed: _items.loadMore,
          child: Text('${errorMessage(_items.error)} · ${S.retry}'),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.n});

  final Notification n;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pin = n.pin;
    final profilePath = '/user/${Uri.encodeComponent(n.actor.username)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: n.read
            ? Colors.transparent
            : AppPalette.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              context.push(pin != null ? '/pin/${pin.id}' : profilePath),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                UserAvatar(
                  user: n.actor,
                  size: 44,
                  onTap: () => context.push(profilePath),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: n.actor.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: ' ${notificationText(n.type)}'),
                          ],
                        ),
                        style: const TextStyle(fontSize: 15, height: 1.3),
                      ),
                      if (pin != null && pin.title.isNotEmpty)
                        Text(
                          pin.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.muted, fontSize: 14),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo(n.createdAt),
                        style: TextStyle(color: p.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (pin != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      dimension: 56,
                      child: AppImage(pin.imageUrl),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
