import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'providers.dart';
import 'realtime.dart';

/// Unread notification count for the bell badge. Updated instantly by
/// `notification` events from `/events`, refetched when the event stream
/// reconnects and polled every 60 seconds as a fallback.
class UnreadCountNotifier extends Notifier<int> {
  static const interval = Duration(seconds: 60);
  Timer? _timer;

  @override
  int build() {
    final loggedIn = ref.watch(authProvider.select((s) => s.isLoggedIn));
    ref.watch(apiClientProvider); // Reload after a server switch.
    _timer?.cancel();
    _timer = null;
    ref.onDispose(() => _timer?.cancel());
    if (!loggedIn) return 0;
    final sub = ref.read(realtimeHubProvider).events.listen((e) {
      if (e is NotificationEvent) {
        state = e.unreadCount;
      } else if (e is ReconnectedEvent) {
        unawaited(refresh());
      }
    });
    ref.onDispose(sub.cancel);
    _timer = Timer.periodic(interval, (_) => refresh());
    unawaited(Future.microtask(refresh));
    return 0;
  }

  Future<void> refresh() async {
    if (!ref.read(authProvider).isLoggedIn) return;
    try {
      final n = await ref.read(notificationsRepositoryProvider).unreadCount();
      if (ref.mounted) state = n;
    } catch (_) {
      // The badge is best effort; ignore failures.
    }
  }

  void reset() => state = 0;

  void set(int count) => state = count < 0 ? 0 : count;
}

final unreadCountProvider = NotifierProvider<UnreadCountNotifier, int>(
  UnreadCountNotifier.new,
);

/// Bumped whenever the notifications tab is selected, so the screen reloads
/// and marks everything as read.
class NotificationsVisitNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final notificationsVisitProvider =
    NotifierProvider<NotificationsVisitNotifier, int>(
      NotificationsVisitNotifier.new,
    );
