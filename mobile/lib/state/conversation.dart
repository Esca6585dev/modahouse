import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../data/chats_repository.dart';
import '../models/models.dart';
import 'chat_logic.dart';
import 'realtime.dart';

/// One open conversation: history, optimistic sending, read receipts and
/// live events. Created by the conversation screen.
class ConversationController extends ChangeNotifier {
  ConversationController({
    required this.chatId,
    required this.repo,
    required this.me,
    Stream<RealtimeEvent>? events,
    Chat? initialChat,
    this.isVisible,
    this.onChatChanged,
    this.onRead,
  }) : _chat = initialChat {
    _sub = events?.listen(applyEvent);
  }

  final int chatId;
  final ChatsRepository repo;

  /// The viewer (sender of optimistic messages).
  final UserBrief me;

  /// Whether new incoming messages are seen right now (screen on top and the
  /// app in the foreground). Null = always.
  final bool Function()? isVisible;

  /// The chat itself changed (blocked, loaded): updates the chat list.
  final void Function(Chat chat)? onChatChanged;

  /// Called after the viewer read messages (badge refresh).
  final void Function()? onRead;

  static const typingInterval = Duration(seconds: 3);

  StreamSubscription<RealtimeEvent>? _sub;
  Chat? _chat;
  List<Message> _messages = const [];
  bool _loading = false;
  bool _loaded = false;
  bool _loadingOlder = false;
  bool _hasMore = false;
  Object? _error;
  int _readSent = 0;
  DateTime? _lastTyping;
  bool _disposed = false;

  Chat? get chat => _chat;
  List<Message> get messages => _messages;
  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get loadingOlder => _loadingOlder;
  bool get hasMore => _hasMore;
  Object? get error => _error;
  bool get blocked => _chat?.blocked ?? false;

  /// Bumped when a message from the other side arrives (for "Täze habarlar").
  int incoming = 0;

  /// Loads the chat and the newest messages.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      final results = await Future.wait([
        repo.get(chatId),
        repo.messages(chatId),
      ]);
      if (_disposed) return;
      _setChat(results[0] as Chat);
      final page = results[1] as MessagePage;
      _messages = mergePage(
        _messages.where((m) => m.isLocal).toList(),
        page.items,
      );
      if (!_loaded) _hasMore = page.hasMore;
      _loaded = true;
    } catch (e) {
      if (_disposed) return;
      _error = e;
    }
    _loading = false;
    _notify();
    markRead();
  }

  /// After a reconnect: fetch the newest page again and merge it.
  Future<void> refresh() async {
    if (!_loaded) return load();
    try {
      final results = await Future.wait([
        repo.get(chatId),
        repo.messages(chatId),
      ]);
      if (_disposed) return;
      _setChat(results[0] as Chat);
      _messages = mergePage(_messages, (results[1] as MessagePage).items);
      _notify();
      markRead();
    } catch (_) {}
  }

  /// Loads the messages before the oldest one shown.
  Future<void> loadOlder() async {
    if (_loadingOlder || !_hasMore || !_loaded) return;
    final before = oldestServerId(_messages);
    if (before == 0) return;
    _loadingOlder = true;
    _notify();
    try {
      final page = await repo.messages(chatId, before: before);
      if (_disposed) return;
      _messages = mergePage(_messages, page.items);
      _hasMore = page.hasMore;
    } catch (_) {
      // Try again on the next scroll.
    }
    _loadingOlder = false;
    _notify();
  }

  /// Sends text, optionally with a shared post. Returns the optimistic message.
  Message sendText(String text, {PinPreview? pin}) {
    final local = Message(
      id: 0,
      chatId: chatId,
      sender: me,
      kind: pin != null ? MessageKind.pin : MessageKind.text,
      text: text.trim(),
      pin: pin,
      clientId: newClientId(),
      mine: true,
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
    );
    _add(local);
    unawaited(_deliver(local));
    return local;
  }

  /// Sends a photo or document with an optional caption.
  Message sendFile(OutgoingFile file, {String caption = ''}) {
    final local = Message(
      id: 0,
      chatId: chatId,
      sender: me,
      kind: file.isImage ? MessageKind.image : MessageKind.file,
      text: caption.trim(),
      attachment: Attachment(
        url: '',
        name: file.name,
        size: file.bytes.length,
        mimeType: file.mimeType,
        width: file.width,
        height: file.height,
      ),
      clientId: newClientId(),
      mine: true,
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
      progress: 0,
      file: file,
    );
    _add(local);
    unawaited(_deliver(local));
    return local;
  }

  /// "Gaýtadan ugrat" on a failed message.
  void retry(Message m) {
    if (!m.isFailed) return;
    final again = m.copyWith(
      status: MessageStatus.pending,
      progress: m.file == null ? null : 0,
    );
    _replaceLocal(again);
    unawaited(_deliver(again));
  }

  /// Removes a failed message that will not be sent.
  void discard(Message m) {
    _messages = _messages.where((e) => e.clientId != m.clientId).toList();
    _notify();
  }

  Future<void> _deliver(Message local) async {
    try {
      final Message sent;
      final file = local.file;
      if (file != null) {
        var last = 0.0;
        sent = await repo.sendFile(
          chatId,
          file,
          text: local.text,
          clientId: local.clientId,
          onProgress: (p) {
            if (p - last < 0.03 && p < 1) return;
            last = p;
            _progress(local.clientId, p);
          },
        );
      } else {
        sent = await repo.sendText(
          chatId,
          text: local.text,
          pinId: local.pin?.id,
          clientId: local.clientId,
        );
      }
      if (_disposed) return;
      // The server echoes clientId; make sure it does even on older servers.
      final echoed = sent.clientId == local.clientId
          ? sent
          : sent.copyWith(clientId: local.clientId);
      _messages = upsertMessage(_messages, echoed);
      _notify();
      onSent?.call(echoed);
    } catch (e) {
      if (_disposed) return;
      if (e is ApiException && e.statusCode == 403 && _chat != null) {
        _setChat(_chat!.copyWith(blocked: true));
      }
      final i = _messages.indexWhere((m) => m.clientId == local.clientId);
      if (i >= 0 && _messages[i].isLocal) {
        _replaceLocal(
          _messages[i].copyWith(
            status: MessageStatus.failed,
            clearProgress: true,
          ),
        );
      }
      lastError = e;
      _notify();
    }
  }

  /// The last send error (shown as a snackbar by the screen).
  Object? lastError;

  /// Called with each message the server accepted (chat list preview).
  void Function(Message message)? onSent;

  void _progress(String clientId, double p) {
    final i = _messages.indexWhere((m) => m.clientId == clientId);
    if (i < 0 || !_messages[i].isLocal) return;
    _replaceLocal(_messages[i].copyWith(progress: p.clamp(0, 1).toDouble()));
  }

  /// Deletes my message ("Poz"); throws on failure.
  Future<void> delete(Message m) async {
    if (!m.mine) return;
    if (m.isLocal) {
      discard(m);
      return;
    }
    await repo.deleteMessage(m.id);
    if (_disposed) return;
    _messages = applyDeleted(_messages, m.id);
    _notify();
  }

  /// Tells the server I read the newest incoming message (when visible).
  void markRead() {
    if (_disposed || !(isVisible?.call() ?? true)) return;
    final last = lastIncomingId(_messages);
    if (last == 0 || last <= _readSent) return;
    _readSent = last;
    unawaited(
      repo.read(chatId, last).then((_) => onRead?.call()).catchError((
        Object _,
      ) {
        if (_readSent == last) _readSent = 0;
      }),
    );
  }

  /// The composer changed: "ýazýar…" for the other side, at most every 3 s.
  void typed() {
    if (blocked) return;
    final now = DateTime.now();
    final last = _lastTyping;
    if (last != null && now.difference(last) < typingInterval) return;
    _lastTyping = now;
    unawaited(repo.typing(chatId).catchError((Object _) {}));
  }

  void applyEvent(RealtimeEvent e) {
    if (_disposed) return;
    switch (e) {
      case ChatMessageEvent(:final chatId, :final message)
          when chatId == this.chatId:
        _messages = upsertMessage(_messages, message);
        if (!message.mine) incoming++;
        _notify();
        if (!message.mine) markRead();
      case ChatReadEvent(:final chatId, :final userId, :final messageId)
          when chatId == this.chatId && userId != me.id:
        final next = applyRead(_messages, messageId);
        if (!identical(next, _messages)) {
          _messages = next;
          _notify();
        }
      case MessageDeletedEvent(:final chatId, :final messageId)
          when chatId == this.chatId:
        _messages = applyDeleted(_messages, messageId);
        _notify();
      case ReconnectedEvent():
        unawaited(refresh());
      default:
    }
  }

  void _add(Message m) {
    _messages = upsertMessage(_messages, m);
    _notify();
  }

  void _replaceLocal(Message m) {
    _messages = [
      for (final e in _messages) e.clientId == m.clientId && e.isLocal ? m : e,
    ];
    _notify();
  }

  void _setChat(Chat c) {
    _chat = c;
    onChatChanged?.call(c);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
