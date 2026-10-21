import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/chat_format.dart';
import '../core/local_notifications.dart';
import 'auth.dart';
import 'chat_state.dart';
import 'realtime.dart';

/// The platform's local notifications (a no-op on the web and in tests).
final localNotifierProvider = Provider<LocalNotifier>(
  (ref) => platformLocalNotifier(),
);

/// Shows a local notification for each incoming message unless its chat is
/// on screen with the app in the foreground. Kept alive by `ModaHouseApp`.
final chatAlertsProvider = Provider<void>((ref) {
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return;
  final notifier = ref.read(localNotifierProvider);
  final sub = ref.read(realtimeHubProvider).events.listen((e) {
    if (e is! ChatMessageEvent) return;
    final m = e.message;
    if (m.mine || m.sender.id == me || chatVisible(ref, e.chatId)) return;
    notifier.showMessage(
      chatId: e.chatId,
      title: m.sender.displayName,
      body: messagePreview(m, you: false),
    );
  });
  ref.onDispose(sub.cancel);
});
