// Pure list operations for chat messages (unit tested in test/chat_test.dart).

import 'dart:math';

import '../models/models.dart';

/// Inserts or replaces [m] in [list] (server messages sorted by id, local
/// optimistic ones at the end):
///
/// - a message with the same non-empty `clientId` (the optimistic bubble, or
///   an earlier copy from the other channel: HTTP reply vs. `message` event)
///   is replaced in place;
/// - a message with the same id is replaced;
/// - otherwise it is inserted after the last server message with a smaller
///   id, i.e. before any still-pending local bubbles.
List<Message> upsertMessage(List<Message> list, Message m) {
  if (m.clientId.isNotEmpty) {
    final i = list.indexWhere((e) => e.clientId == m.clientId);
    if (i >= 0) return _replaceAt(list, i, m);
  }
  if (m.id > 0) {
    final i = list.indexWhere((e) => e.id == m.id);
    if (i >= 0) return _replaceAt(list, i, m);
  }
  var at = list.length;
  while (at > 0) {
    final prev = list[at - 1];
    if (prev.isLocal || (m.id > 0 && prev.id > m.id)) {
      at--;
    } else {
      break;
    }
  }
  if (m.isLocal) at = list.length;
  return [...list.sublist(0, at), m, ...list.sublist(at)];
}

List<Message> _replaceAt(List<Message> list, int i, Message m) {
  final old = list[i];
  // A late event must not undo a newer state (read / deleted).
  final merged = old.id == m.id && old.id > 0
      ? m.copyWith(read: m.read || old.read, deleted: m.deleted || old.deleted)
      : m;
  return [...list.sublist(0, i), merged, ...list.sublist(i + 1)];
}

/// The other side read everything up to [messageId]: tick my messages.
List<Message> applyRead(List<Message> list, int messageId) {
  var changed = false;
  final out = [
    for (final m in list)
      if (m.mine && !m.read && m.id > 0 && m.id <= messageId)
        () {
          changed = true;
          return m.copyWith(read: true);
        }()
      else
        m,
  ];
  return changed ? out : list;
}

/// Shows "Bu habar pozuldy" for [messageId].
List<Message> applyDeleted(List<Message> list, int messageId) {
  final i = list.indexWhere((m) => m.id == messageId);
  if (i < 0 || list[i].deleted) return list;
  return _replaceAt(list, i, list[i].asDeleted());
}

/// Merges a page of server messages (older history or the newest page after
/// a reconnect) into [list] without duplicates.
List<Message> mergePage(List<Message> list, List<Message> page) {
  var out = list;
  for (final m in page) {
    out = upsertMessage(out, m);
  }
  return out;
}

/// The id of the newest message from the other side (0 = none).
int lastIncomingId(List<Message> list) {
  for (var i = list.length - 1; i >= 0; i--) {
    final m = list[i];
    if (!m.mine && m.id > 0) return m.id;
  }
  return 0;
}

/// The id to load older messages before (0 = no server message yet).
int oldestServerId(List<Message> list) {
  for (final m in list) {
    if (m.id > 0) return m.id;
  }
  return 0;
}

final _random = Random();

/// A unique id for an optimistic message.
String newClientId() =>
    'm${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${_random.nextInt(1 << 30).toRadixString(36)}';

/// Chats sorted the way the list shows them: the newest activity first.
List<Chat> upsertChat(List<Chat> chats, Chat chat) => [
  chat,
  for (final c in chats)
    if (c.id != chat.id) c,
];

/// The day key of a message for date separators (local time).
DateTime dayOf(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// True when [a] and [b] belong to one visual group (same sender, same day,
/// less than 5 minutes apart).
bool sameGroup(Message a, Message b) {
  if (a.mine != b.mine || a.sender.id != b.sender.id) return false;
  final ta = a.createdAt;
  final tb = b.createdAt;
  if (ta == null || tb == null) return true;
  if (dayOf(ta) != dayOf(tb)) return false;
  return tb.difference(ta).inMinutes.abs() < 5;
}
