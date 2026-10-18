import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'auth.dart';
import 'chat_logic.dart';
import 'providers.dart';
import 'realtime.dart';

/// The app's lifecycle state (set by `ModaHouseApp`).
class AppLifecycleNotifier extends Notifier<AppLifecycleState> {
  @override
  AppLifecycleState build() => AppLifecycleState.resumed;

  void set(AppLifecycleState s) => state = s;
}

final appLifecycleProvider =
    NotifierProvider<AppLifecycleNotifier, AppLifecycleState>(
      AppLifecycleNotifier.new,
    );

/// The conversation on screen (null = none). Incoming messages there are
/// read right away: no badge, no notification.
class ActiveChatNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? chatId) => state = chatId;

  /// Clears it only if [chatId] is still the active one.
  void leave(int chatId) {
    if (state == chatId) state = null;
  }
}

final activeChatProvider = NotifierProvider<ActiveChatNotifier, int?>(
  ActiveChatNotifier.new,
);

/// True when a message in [chatId] is seen as it arrives.
bool chatVisible(Ref ref, int chatId) =>
    ref.read(activeChatProvider) == chatId &&
    ref.read(appLifecycleProvider) == AppLifecycleState.resumed;

/// Unread messages in all chats (`GET /chats/unread-count` + live events),
/// for the paper-plane badge.
class ChatUnreadNotifier extends Notifier<int> {
  @override
  int build() {
    final loggedIn = ref.watch(authProvider.select((s) => s.isLoggedIn));
    ref.watch(apiClientProvider); // Reload after a server switch.
    if (!loggedIn) return 0;
    final sub = ref.read(realtimeHubProvider).events.listen((e) {
      switch (e) {
        case ReconnectedEvent():
          unawaited(refresh());
        case ChatMessageEvent(:final chatId, :final message):
          if (!message.mine && !chatVisible(ref, chatId)) state = state + 1;
        case ChatReadEvent(:final userId):
          // Read on another device of mine.
          if (userId == ref.read(currentUserIdProvider)) unawaited(refresh());
        default:
      }
    });
    ref.onDispose(sub.cancel);
    unawaited(Future.microtask(refresh));
    return 0;
  }

  Future<void> refresh() async {
    if (!ref.read(authProvider).isLoggedIn) return;
    try {
      final n = await ref.read(chatsRepositoryProvider).unreadCount();
      if (ref.mounted) state = n;
    } catch (_) {
      // Best effort: older servers have no chat.
    }
  }
}

final chatUnreadProvider = NotifierProvider<ChatUnreadNotifier, int>(
  ChatUnreadNotifier.new,
);

/// "ýazýar…": chat ids where the other side is typing right now.
class TypingNotifier extends Notifier<Set<int>> {
  static const showFor = Duration(seconds: 4);
  final _timers = <int, Timer>{};

  @override
  Set<int> build() {
    final me = ref.watch(currentUserIdProvider);
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
    });
    if (me == null) return const {};
    final sub = ref.read(realtimeHubProvider).events.listen((e) {
      switch (e) {
        case TypingEvent(:final chatId, :final userId) when userId != me:
          _timers[chatId]?.cancel();
          _timers[chatId] = Timer(showFor, () => _clear(chatId));
          if (!state.contains(chatId)) state = {...state, chatId};
        case ChatMessageEvent(:final chatId, :final message) when !message.mine:
          _clear(chatId);
        default:
      }
    });
    ref.onDispose(sub.cancel);
    return const {};
  }

  void _clear(int chatId) {
    _timers.remove(chatId)?.cancel();
    if (ref.mounted && state.contains(chatId)) {
      state = {...state}..remove(chatId);
    }
  }
}

final typingProvider = NotifierProvider<TypingNotifier, Set<int>>(
  TypingNotifier.new,
);

class ChatsState {
  const ChatsState({
    this.items = const [],
    this.loading = false,
    this.loaded = false,
    this.hasMore = false,
    this.error,
    this.page = 1,
  });

  final List<Chat> items;
  final bool loading;

  /// The first page arrived (or failed).
  final bool loaded;
  final bool hasMore;
  final Object? error;
  final int page;

  ChatsState copyWith({
    List<Chat>? items,
    bool? loading,
    bool? loaded,
    bool? hasMore,
    Object? error,
    bool clearError = false,
    int? page,
  }) => ChatsState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
    page: page ?? this.page,
  );
}

/// My chats, newest first, kept up to date by the event stream.
class ChatsNotifier extends Notifier<ChatsState> {
  int _generation = 0;

  @override
  ChatsState build() {
    final me = ref.watch(currentUserIdProvider);
    ref.watch(apiClientProvider);
    _generation++;
    if (me == null) return const ChatsState(loaded: true);
    final sub = ref.read(realtimeHubProvider).events.listen(_onEvent);
    ref.onDispose(sub.cancel);
    return const ChatsState();
  }

  /// Loads the first page (also after a reconnect).
  Future<void> refresh() async {
    if (ref.read(currentUserIdProvider) == null) return;
    final gen = ++_generation;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await ref.read(chatsRepositoryProvider).list(1);
      if (!ref.mounted || gen != _generation) return;
      state = ChatsState(
        items: page.items,
        loaded: true,
        hasMore: page.hasMore,
        page: 1,
      );
    } catch (e) {
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(loading: false, loaded: true, error: e);
    }
  }

  /// Loads the first page unless it is already there.
  Future<void> ensureLoaded() async {
    if (state.loaded && state.error == null) return;
    if (state.loading) return;
    await refresh();
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    final gen = _generation;
    state = state.copyWith(loading: true);
    try {
      final next = state.page + 1;
      final page = await ref.read(chatsRepositoryProvider).list(next);
      if (!ref.mounted || gen != _generation) return;
      final known = {for (final c in state.items) c.id};
      state = state.copyWith(
        items: [
          ...state.items,
          ...page.items.where((c) => !known.contains(c.id)),
        ],
        loading: false,
        hasMore: page.hasMore,
        page: next,
      );
    } catch (e) {
      if (!ref.mounted || gen != _generation) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Chat? byId(int id) => state.items.where((c) => c.id == id).firstOrNull;

  /// Puts a chat I opened or wrote to on top of the list.
  void put(Chat chat) {
    final old = byId(chat.id);
    final keep = old == null || chat.lastMessage != null
        ? chat
        : chat.copyWith(lastMessage: old.lastMessage);
    state = state.copyWith(items: upsertChat(state.items, keep));
  }

  /// Replaces a chat without moving it (read state, blocked flag).
  void replace(Chat chat) {
    state = state.copyWith(
      items: [for (final c in state.items) c.id == chat.id ? chat : c],
    );
  }

  /// I read [chatId] up to the newest message.
  void markRead(int chatId) {
    final c = byId(chatId);
    if (c == null || c.unreadCount == 0) return;
    replace(c.copyWith(unreadCount: 0));
  }

  void _onEvent(RealtimeEvent e) {
    switch (e) {
      case ReconnectedEvent():
        if (state.loaded || state.loading) unawaited(refresh());
      case ChatMessageEvent(:final chatId, :final message):
        final c = byId(chatId);
        if (c == null) {
          if (state.loaded) unawaited(_fetchOne(chatId));
          return;
        }
        final unread = message.mine
            ? c.unreadCount
            : (chatVisible(ref, chatId) ? 0 : c.unreadCount + 1);
        state = state.copyWith(
          items: upsertChat(
            state.items,
            c.copyWith(
              lastMessage: message,
              unreadCount: unread,
              updatedAt: message.createdAt,
            ),
          ),
        );
      case ChatReadEvent(:final chatId, :final userId, :final messageId):
        final c = byId(chatId);
        if (c == null) return;
        if (userId == ref.read(currentUserIdProvider)) {
          replace(c.copyWith(unreadCount: 0));
        } else {
          final last = c.lastMessage;
          if (last != null && last.mine && last.id <= messageId) {
            replace(c.copyWith(lastMessage: last.copyWith(read: true)));
          }
        }
      case MessageDeletedEvent(:final chatId, :final messageId):
        final c = byId(chatId);
        final last = c?.lastMessage;
        if (c != null && last != null && last.id == messageId) {
          replace(c.copyWith(lastMessage: last.asDeleted()));
        }
      default:
    }
  }

  Future<void> _fetchOne(int chatId) async {
    try {
      final chat = await ref.read(chatsRepositoryProvider).get(chatId);
      if (ref.mounted) put(chat);
    } catch (_) {}
  }
}

final chatsProvider = NotifierProvider<ChatsNotifier, ChatsState>(
  ChatsNotifier.new,
);
