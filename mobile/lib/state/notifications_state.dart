import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'providers.dart';

/// Unread notification count for the bottom-nav badge.
/// Polled every 60 seconds while the user is logged in.
class UnreadCountNotifier extends Notifier<int> {
  static const interval = Duration(seconds: 60);
  Timer? _timer;

  @override
  int build() {
    final loggedIn = ref.watch(authProvider.select((s) => s.isLoggedIn));
    _timer?.cancel();
    _timer = null;
    ref.onDispose(() => _timer?.cancel());
    if (!loggedIn) return 0;
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
}

final unreadCountProvider = NotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);

/// Bumped whenever the notifications tab is selected, so the screen reloads
/// and marks everything as read.
class NotificationsVisitNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final notificationsVisitProvider =
    NotifierProvider<NotificationsVisitNotifier, int>(NotificationsVisitNotifier.new);
