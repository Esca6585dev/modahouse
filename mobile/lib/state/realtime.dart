import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/sse.dart';
import '../core/sse_transport/sse_transport.dart';
import '../models/models.dart';
import 'auth.dart';
import 'providers.dart';
import 'server.dart';

/// A typed event from `GET /events` (docs/API.md, v6).
sealed class RealtimeEvent {
  const RealtimeEvent();

  /// Null for unknown events or broken JSON.
  static RealtimeEvent? fromSse(SseEvent e) {
    Json data;
    try {
      data = asJson(jsonDecode(e.data));
    } catch (_) {
      return null;
    }
    switch (e.event) {
      case 'ready':
        return ReadyEvent(asInt(data['userId']));
      case 'message':
        if (data['message'] is! Map) return null;
        final m = Message.fromJson(asJson(data['message']));
        final chatId = asInt(data['chatId']);
        return ChatMessageEvent(chatId == 0 ? m.chatId : chatId, m);
      case 'message_deleted':
        return MessageDeletedEvent(
          asInt(data['chatId']),
          asInt(data['messageId']),
        );
      case 'read':
        return ChatReadEvent(
          asInt(data['chatId']),
          asInt(data['userId']),
          asInt(data['messageId']),
        );
      case 'typing':
        return TypingEvent(asInt(data['chatId']), asInt(data['userId']));
      case 'notification':
        return NotificationEvent(
          data['notification'] is Map
              ? Notification.fromJson(asJson(data['notification']))
              : null,
          asInt(data['unreadCount']),
        );
      default:
        return null;
    }
  }
}

class ReadyEvent extends RealtimeEvent {
  const ReadyEvent(this.userId);
  final int userId;
}

/// A new message in one of my chats (also my own sends from another device).
class ChatMessageEvent extends RealtimeEvent {
  const ChatMessageEvent(this.chatId, this.message);
  final int chatId;
  final Message message;
}

class MessageDeletedEvent extends RealtimeEvent {
  const MessageDeletedEvent(this.chatId, this.messageId);
  final int chatId;
  final int messageId;
}

/// [userId] read everything up to [messageId] in [chatId].
class ChatReadEvent extends RealtimeEvent {
  const ChatReadEvent(this.chatId, this.userId, this.messageId);
  final int chatId;
  final int userId;
  final int messageId;
}

class TypingEvent extends RealtimeEvent {
  const TypingEvent(this.chatId, this.userId);
  final int chatId;
  final int userId;
}

class NotificationEvent extends RealtimeEvent {
  const NotificationEvent(this.notification, this.unreadCount);
  final Notification? notification;
  final int unreadCount;
}

/// Not from the server: the stream (re)connected. Events sent while offline
/// are not replayed, so listeners refetch what they show.
class ReconnectedEvent extends RealtimeEvent {
  const ReconnectedEvent();
}

/// The app-wide event bus. Lives as long as the app (never rebuilt), so
/// listeners keep their subscription across reconnects and logins.
class RealtimeHub {
  final _controller = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _controller.stream;

  void add(RealtimeEvent e) {
    if (!_controller.isClosed) _controller.add(e);
  }

  Future<void> close() => _controller.close();
}

final realtimeHubProvider = Provider<RealtimeHub>((ref) {
  final hub = RealtimeHub();
  ref.onDispose(hub.close);
  return hub;
});

typedef EventStreamOpener = Future<SseStream> Function(
  ApiClient client,
  String token,
);

/// How the event stream is opened (overridden in tests).
final eventStreamOpenerProvider = Provider<EventStreamOpener>(
  (ref) => openEventStream,
);

/// The `/events` connection: open while logged in, replaced when the server
/// address or the account changes, closed on logout.
class RealtimeNotifier extends Notifier<SseStatus> {
  SseConnection? _conn;

  @override
  SseStatus build() {
    final token = ref.watch(
      authProvider.select((s) => s.isLoggedIn ? s.token : null),
    );
    ref.watch(serverProvider.select((s) => s.apiUrl));
    final client = ref.watch(apiClientProvider);
    final open = ref.watch(eventStreamOpenerProvider);
    final hub = ref.read(realtimeHubProvider);
    ref.onDispose(() {
      _conn?.stop();
      _conn = null;
    });
    if (token == null) return SseStatus.idle;
    late final SseConnection conn;
    conn = SseConnection(
      open: () => open(client, token),
      onEvent: (e) {
        final event = RealtimeEvent.fromSse(e);
        if (event != null) hub.add(event);
      },
      onConnected: () => hub.add(const ReconnectedEvent()),
      onStatus: (s) {
        if (ref.mounted && identical(_conn, conn)) state = s;
      },
    );
    _conn = conn;
    // Not inside build: the status callback sets state.
    scheduleMicrotask(() {
      if (identical(_conn, conn)) conn.start();
    });
    return SseStatus.connecting;
  }

  /// The app came back to the foreground: reconnect now instead of waiting
  /// for the backoff.
  void onResume() => _conn?.reconnectNow();
}

final realtimeProvider = NotifierProvider<RealtimeNotifier, SseStatus>(
  RealtimeNotifier.new,
);
