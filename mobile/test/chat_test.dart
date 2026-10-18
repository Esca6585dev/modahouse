import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:modahouse/core/api_client.dart';
import 'package:modahouse/core/api_exception.dart';
import 'package:modahouse/core/chat_format.dart';
import 'package:modahouse/core/local_notifications.dart';
import 'package:modahouse/core/sse.dart';
import 'package:modahouse/data/chats_repository.dart';
import 'package:modahouse/l10n/strings.dart';
import 'package:modahouse/models/models.dart';
import 'package:modahouse/state/chat_logic.dart';
import 'package:modahouse/state/conversation.dart';
import 'package:modahouse/state/realtime.dart';

Map<String, dynamic> userJson(int id, String username) => {
  'id': id,
  'username': username,
  'name': username == 'ak.gelin' ? 'Ak Gelin' : 'Aýlar Studio',
  'avatarUrl': '',
  'isBusiness': username == 'ak.gelin',
  'verified': username == 'ak.gelin',
};

Map<String, dynamic> msgJson(
  int id, {
  bool mine = false,
  String text = 'Salam',
  String kind = 'text',
  String clientId = '',
  bool read = false,
  String createdAt = '2026-10-18T10:00:00Z',
}) => {
  'id': id,
  'chatId': 5,
  'sender': mine ? userJson(1, 'aylar.studio') : userJson(2, 'ak.gelin'),
  'kind': kind,
  'text': text,
  'attachment': null,
  'pin': null,
  'clientId': clientId,
  'mine': mine,
  'read': read,
  'deleted': false,
  'createdAt': createdAt,
};

Message msg(
  int id, {
  bool mine = false,
  String clientId = '',
  bool read = false,
}) => Message.fromJson(msgJson(id, mine: mine, clientId: clientId, read: read));

Message local(String clientId, {String text = 'hi'}) => Message(
  id: 0,
  chatId: 5,
  sender: const UserBrief(id: 1, username: 'aylar.studio', name: 'Aýlar'),
  text: text,
  clientId: clientId,
  mine: true,
  status: MessageStatus.pending,
);

class FakeTimer implements Timer {
  FakeTimer(this.delay, this.run);

  final Duration delay;
  final void Function() run;
  bool cancelled = false;
  bool fired = false;

  void fire() {
    if (cancelled || fired) return;
    fired = true;
    run();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => 0;
}

class FakeChatsRepository extends ChatsRepository {
  FakeChatsRepository() : super(ApiClient(baseUrl: 'http://test/api'));

  final sent = <Map<String, Object?>>[];
  final reads = <int>[];
  int typingCalls = 0;
  int nextId = 100;
  Object? failWith;
  Completer<void>? gate;
  bool echoClientId = true;
  List<Message> history = [];
  bool historyHasMore = false;

  @override
  Future<Chat> get(int id) async => Chat.fromJson({
    'id': id,
    'other': userJson(2, 'ak.gelin'),
    'unreadCount': 0,
    'blocked': false,
  });

  @override
  Future<MessagePage> messages(
    int chatId, {
    int? before,
    int limit = ChatsRepository.messagesLimit,
  }) async {
    final items = before == null
        ? history
        : history.where((m) => m.id < before).toList();
    return MessagePage(items: items, hasMore: historyHasMore);
  }

  @override
  Future<Message> sendText(
    int chatId, {
    String text = '',
    int? pinId,
    String clientId = '',
  }) async {
    sent.add({'text': text, 'pinId': pinId, 'clientId': clientId});
    if (gate != null) await gate!.future;
    final f = failWith;
    if (f != null) throw f;
    return Message.fromJson(
      msgJson(
        nextId++,
        mine: true,
        text: text,
        kind: pinId == null ? 'text' : 'pin',
        clientId: echoClientId ? clientId : '',
      ),
    );
  }

  @override
  Future<void> read(int chatId, int messageId) async => reads.add(messageId);

  @override
  Future<void> typing(int chatId) async => typingCalls++;
}

void main() {
  group('SSE parser', () {
    late List<SseEvent> events;
    late List<String> comments;
    late SseParser parser;

    setUp(() {
      events = [];
      comments = [];
      parser = SseParser(onEvent: events.add, onComment: comments.add);
    });

    test('named events, default event name and comments', () {
      parser.addText(
        'event: ready\ndata: {"userId":1}\n\n: ping\n\ndata: plain\n\n',
      );
      expect(events.map((e) => e.event), ['ready', 'message']);
      expect(events.first.data, '{"userId":1}');
      expect(events.last.data, 'plain');
      expect(comments, ['ping']);
    });

    test('multi-line data joins with newlines', () {
      parser.addText('event: message\ndata: a\ndata:b\ndata:  c\n\n');
      expect(events.single.data, 'a\nb\n c');
    });

    test('chunks split anywhere, CRLF and CR line endings', () {
      const raw =
          'retry: 3000\r\nevent: typing\r\ndata: {"chatId":5,\r\n'
          'data: "userId":2}\r\n\r\nevent: read\rdata: x\r\r';
      for (var i = 0; i < raw.length; i++) {
        parser.addText(raw[i]);
      }
      expect(events.map((e) => e.event), ['typing', 'read']);
      expect(events.first.data, '{"chatId":5,\n"userId":2}');
      expect(events.last.data, 'x');
    });

    test('UTF-8 bytes split inside a character', () {
      final bytes = utf8.encode('data: Salam, ýazýar…\n\n');
      for (final b in bytes) {
        parser.addBytes([b]);
      }
      expect(events.single.data, 'Salam, ýazýar…');
    });

    test('an event without data is not dispatched; id is remembered', () {
      parser.addText('event: ready\n\nid: 7\ndata: one\n\n');
      expect(events.length, 1);
      expect(events.single.id, '7');
      expect(parser.lastEventId, '7');
    });

    test('an incomplete event waits for the blank line', () {
      parser.addText('event: message\ndata: {"a":1}\n');
      expect(events, isEmpty);
      parser.addText('\n');
      expect(events, hasLength(1));
    });
  });

  group('reconnect', () {
    test('backoff doubles from 1 s up to 30 s and resets', () {
      final b = Backoff();
      expect(
        [for (var i = 0; i < 7; i++) b.next().inSeconds],
        [1, 2, 4, 8, 16, 30, 30],
      );
      b.reset();
      expect(b.next(), const Duration(seconds: 1));
    });

    test('connection retries with backoff, resets after data', () async {
      final timers = <FakeTimer>[];
      var opens = 0;
      var connected = 0;
      final statuses = <SseStatus>[];
      final events = <SseEvent>[];
      StreamController<List<int>>? current;
      var failNext = 2;
      final conn = SseConnection(
        open: () async {
          opens++;
          if (failNext > 0) {
            failNext--;
            throw const ApiException('down', 0);
          }
          current = StreamController<List<int>>();
          return SseStream(current!.stream, () => current!.close());
        },
        onEvent: events.add,
        onConnected: () => connected++,
        onStatus: statuses.add,
        schedule: (d, run) {
          final t = FakeTimer(d, run);
          timers.add(t);
          return t;
        },
      );
      conn.start();
      await pumpEventQueue();
      expect(opens, 1);
      expect(conn.status, SseStatus.waiting);
      expect(conn.nextDelay, const Duration(seconds: 1));

      timers.last.fire();
      await pumpEventQueue();
      expect(opens, 2);
      expect(conn.nextDelay, const Duration(seconds: 2));

      timers.last.fire();
      await pumpEventQueue();
      expect(opens, 3);
      expect(conn.status, SseStatus.connected);
      expect(connected, 1);

      current!.add(utf8.encode('event: ready\ndata: {"userId":1}\n\n'));
      await pumpEventQueue();
      expect(events.single.event, 'ready');
      expect(conn.backoff.attempt, 0, reason: 'data resets the backoff');

      // The server closes the stream: reconnect after 1 s again.
      await current!.close();
      await pumpEventQueue();
      expect(conn.status, SseStatus.waiting);
      expect(conn.nextDelay, const Duration(seconds: 1));

      // App resumed: connect at once, no waiting.
      conn.reconnectNow();
      await pumpEventQueue();
      expect(opens, 4);
      expect(conn.status, SseStatus.connected);
      expect(connected, 2);

      conn.stop();
      expect(conn.status, SseStatus.idle);
      expect(
        statuses,
        containsAllInOrder([
          SseStatus.connecting,
          SseStatus.waiting,
          SseStatus.connected,
          SseStatus.idle,
        ]),
      );
    });

    test('a silent stream counts as dead (watchdog)', () async {
      final timers = <FakeTimer>[];
      var opens = 0;
      final conn = SseConnection(
        open: () async {
          opens++;
          return SseStream(StreamController<List<int>>().stream, () {});
        },
        onEvent: (_) {},
        schedule: (d, run) {
          final t = FakeTimer(d, run);
          timers.add(t);
          return t;
        },
      );
      conn.start();
      await pumpEventQueue();
      final watchdog = timers.lastWhere((t) => t.delay == conn.idleTimeout);
      watchdog.fire();
      expect(conn.status, SseStatus.waiting);
      timers.last.fire();
      await pumpEventQueue();
      expect(opens, 2);
      conn.stop();
    });

    test('stop while connecting closes the late stream', () async {
      final gate = Completer<void>();
      var closed = false;
      final conn = SseConnection(
        open: () async {
          await gate.future;
          return SseStream(const Stream.empty(), () => closed = true);
        },
        onEvent: (_) {},
      );
      conn.start();
      conn.stop();
      gate.complete();
      await pumpEventQueue();
      expect(closed, isTrue);
      expect(conn.status, SseStatus.idle);
    });
  });

  group('models', () {
    test('Chat and Message parse every kind', () {
      final chat = Chat.fromJson({
        'id': 5,
        'other': userJson(2, 'ak.gelin'),
        'lastMessage': {
          ...msgJson(9, kind: 'image', text: ''),
          'attachment': {
            'url': '/api/chat-files/a.jpg?exp=1&sig=x',
            'name': 'a.jpg',
            'size': 2048,
            'mimeType': 'image/jpeg',
            'width': 800,
            'height': 600,
          },
        },
        'unreadCount': 3,
        'blocked': true,
        'updatedAt': '2026-10-18T10:00:00Z',
      });
      expect(chat.other.isBusiness, isTrue);
      expect(chat.other.verified, isTrue);
      expect(chat.unreadCount, 3);
      expect(chat.blocked, isTrue);
      final m = chat.lastMessage!;
      expect(m.kind, MessageKind.image);
      expect(m.attachment!.isImage, isTrue);
      expect(m.attachment!.aspectRatio, closeTo(800 / 600, 0.001));
      expect(m.status, MessageStatus.sent);

      final pin = Message.fromJson({
        ...msgJson(10, kind: 'pin', mine: true, read: true),
        'pin': {
          'id': 42,
          'title': 'Ak köýnek',
          'imageUrl': '/uploads/p.jpg',
          'price': 450,
          'listingType': 'rent',
        },
        'clientId': 'abc',
      });
      expect(pin.kind, MessageKind.pin);
      expect(pin.pin!.id, 42);
      expect(pin.pin!.listingType, 'rent');
      expect(pin.clientId, 'abc');
      expect(pin.mine && pin.read, isTrue);

      expect(Message.fromJson({'kind': 'weird'}).kind, MessageKind.text);
      final page = MessagePage.fromJson({
        'items': [msgJson(1), msgJson(2)],
        'hasMore': true,
      });
      expect(page.items.map((m) => m.id), [1, 2]);
      expect(page.hasMore, isTrue);
    });

    test('deleting clears text and files', () {
      final m = Message.fromJson({
        ...msgJson(3, kind: 'file', text: 'caption'),
        'attachment': {'url': '/x', 'name': 'a.pdf', 'size': 1},
      });
      final d = m.asDeleted();
      expect(d.deleted, isTrue);
      expect(d.text, '');
      expect(d.attachment, isNull);
    });

    test('Pin.credit defaults to empty', () {
      final pin = Pin.fromJson({'id': 1, 'title': 't', 'author': {}});
      expect(pin.credit, '');
      final credited = Pin.fromJson({
        'id': 1,
        'title': 't',
        'author': {},
        'credit': 'Surat: A · CC BY-SA 4.0 · Wikimedia Commons',
      });
      expect(credited.credit, contains('CC BY-SA'));
      expect(credited.copyWith(title: 'x').credit, credited.credit);
    });

    test('realtime events from SSE', () {
      final m = RealtimeEvent.fromSse(
        SseEvent(
          event: 'message',
          data: jsonEncode({'chatId': 5, 'message': msgJson(9)}),
        ),
      );
      expect(m, isA<ChatMessageEvent>());
      expect((m as ChatMessageEvent).chatId, 5);
      expect(m.message.id, 9);

      final r = RealtimeEvent.fromSse(
        const SseEvent(
          event: 'read',
          data: '{"chatId":5,"userId":2,"messageId":9}',
        ),
      );
      expect((r as ChatReadEvent).messageId, 9);

      final n = RealtimeEvent.fromSse(
        SseEvent(
          event: 'notification',
          data: jsonEncode({
            'notification': {
              'id': 1,
              'type': 'like',
              'read': false,
              'actor': userJson(2, 'ak.gelin'),
            },
            'unreadCount': 4,
          }),
        ),
      );
      expect((n as NotificationEvent).unreadCount, 4);
      expect(n.notification!.type, NotificationType.like);

      expect(
        RealtimeEvent.fromSse(
          const SseEvent(event: 'typing', data: '{"chatId":5,"userId":2}'),
        ),
        isA<TypingEvent>(),
      );
      expect(
        RealtimeEvent.fromSse(const SseEvent(event: 'message', data: 'nope')),
        isNull,
      );
      expect(
        RealtimeEvent.fromSse(const SseEvent(event: 'other', data: '{}')),
        isNull,
      );
    });
  });

  group('optimistic messages', () {
    test('server copy replaces the pending bubble by clientId', () {
      var list = [msg(1), msg(2, mine: true), local('c1'), local('c2')];
      final server = msg(3, mine: true, clientId: 'c1');
      list = upsertMessage(list, server);
      expect(list.map((m) => m.id), [1, 2, 3, 0]);
      expect(list[2].status, MessageStatus.sent);
      // The same message again (event after the HTTP reply): no duplicate.
      list = upsertMessage(list, msg(3, mine: true, clientId: 'c1'));
      expect(list.where((m) => m.id == 3), hasLength(1));
    });

    test('incoming messages go before pending bubbles, sorted by id', () {
      var list = [msg(1), local('c1')];
      list = upsertMessage(list, msg(5));
      list = upsertMessage(list, msg(4));
      expect(list.map((m) => m.id), [1, 4, 5, 0]);
      list = upsertMessage(list, msg(5));
      expect(list.map((m) => m.id), [1, 4, 5, 0]);
    });

    test('a late event keeps read and deleted', () {
      var list = [msg(3, mine: true)];
      list = applyRead(list, 3);
      list = upsertMessage(list, msg(3, mine: true));
      expect(list.single.read, isTrue);
      list = applyDeleted(list, 3);
      expect(list.single.deleted, isTrue);
      list = upsertMessage(list, msg(3, mine: true));
      expect(list.single.deleted, isTrue);
    });

    test('read receipts tick only my messages up to the id', () {
      final list = applyRead([
        msg(1, mine: true),
        msg(2),
        msg(3, mine: true),
        local('c'),
      ], 2);
      expect(list.map((m) => m.read), [true, false, false, false]);
      expect(lastIncomingId(list), 2);
      expect(oldestServerId(list), 1);
    });

    test('older pages merge without duplicates', () {
      final list = mergePage([msg(3), msg(4)], [msg(1), msg(2), msg(3)]);
      expect(list.map((m) => m.id), [1, 2, 3, 4]);
    });

    test('client ids are unique', () {
      final ids = {for (var i = 0; i < 200; i++) newClientId()};
      expect(ids, hasLength(200));
    });
  });

  group('conversation controller', () {
    const me = UserBrief(id: 1, username: 'aylar.studio', name: 'Aýlar');

    test('send, reconcile with the event, retry after a failure', () async {
      final repo = FakeChatsRepository()..history = [msg(1), msg(2)];
      final events = StreamController<RealtimeEvent>.broadcast();
      final c = ConversationController(
        chatId: 5,
        repo: repo,
        me: me,
        events: events.stream,
      );
      await c.load();
      expect(c.messages.map((m) => m.id), [1, 2]);
      expect(repo.reads, [2], reason: 'marks the newest incoming as read');

      repo.gate = Completer<void>();
      final pending = c.sendText('Salam!');
      expect(c.messages.last.isPending, isTrue);
      expect(c.messages.last.text, 'Salam!');

      // The event of my own message arrives before the HTTP reply.
      events.add(
        ChatMessageEvent(
          5,
          Message.fromJson(
            msgJson(
              100,
              mine: true,
              text: 'Salam!',
              clientId: pending.clientId,
            ),
          ),
        ),
      );
      await pumpEventQueue();
      expect(c.messages.map((m) => m.id), [1, 2, 100]);
      repo.gate!.complete();
      repo.gate = null;
      await pumpEventQueue();
      expect(c.messages.map((m) => m.id), [1, 2, 100]);
      expect(c.messages.last.status, MessageStatus.sent);

      // A failure keeps the bubble with "Gaýtadan ugrat".
      repo.failWith = const ApiException('down', 0);
      final failed = c.sendText('Ikinji');
      await pumpEventQueue();
      expect(c.messages.last.isFailed, isTrue);
      expect(c.lastError, isA<ApiException>());
      repo.failWith = null;
      c.retry(c.messages.last);
      expect(c.messages.last.isPending, isTrue);
      await pumpEventQueue();
      expect(c.messages.last.status, MessageStatus.sent);
      expect(c.messages.last.clientId, failed.clientId);
      expect(repo.sent.last['clientId'], failed.clientId);

      // The other side reads it; then writes.
      events.add(ChatReadEvent(5, 2, c.messages.last.id));
      await pumpEventQueue();
      expect(c.messages.last.read, isTrue);
      events.add(ChatMessageEvent(5, msg(200)));
      await pumpEventQueue();
      expect(c.messages.last.id, 200);
      expect(c.incoming, 1);
      expect(repo.reads.last, 200);

      c.dispose();
      await events.close();
    });

    test('a 403 blocks the chat; typing pings are throttled', () async {
      final repo = FakeChatsRepository();
      final c = ConversationController(chatId: 5, repo: repo, me: me);
      await c.load();
      c.typed();
      c.typed();
      expect(repo.typingCalls, 1);
      repo.failWith = const ApiException(S.chatBlocked, 403);
      c.sendText('x');
      await pumpEventQueue();
      expect(c.blocked, isTrue);
      expect(c.messages.single.isFailed, isTrue);
      c.dispose();
    });

    test('a server without clientId echo still reconciles', () async {
      final repo = FakeChatsRepository()..echoClientId = false;
      final c = ConversationController(chatId: 5, repo: repo, me: me);
      await c.load();
      c.sendText('hi');
      await pumpEventQueue();
      expect(c.messages, hasLength(1));
      expect(c.messages.single.id, 100);
      c.dispose();
    });
  });

  group('format', () {
    final now = DateTime(2026, 10, 18, 15, 0);

    test('previews', () {
      expect(messagePreview(msg(1)), 'Salam');
      expect(messagePreview(msg(1, mine: true)), S.youPrefix('Salam'));
      expect(
        messagePreview(Message.fromJson(msgJson(2, kind: 'image', text: ''))),
        S.photoPreview,
      );
      expect(
        messagePreview(
          Message.fromJson({
            ...msgJson(3, kind: 'file', text: ''),
            'attachment': {'url': '/f', 'name': 'olcheg.pdf'},
          }),
        ),
        '📎 olcheg.pdf',
      );
      expect(
        messagePreview(Message.fromJson(msgJson(4, kind: 'pin', text: ''))),
        S.postPreview,
      );
      expect(messagePreview(msg(5).asDeleted()), S.messageDeleted);
    });

    test('times and days', () {
      expect(
        chatTime(now.subtract(const Duration(seconds: 20)), now: now),
        S.justNow,
      );
      expect(
        chatTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5 min',
      );
      expect(chatTime(DateTime(2026, 10, 18, 9), now: now), '6 sag');
      expect(chatTime(DateTime(2026, 10, 17, 23), now: now), S.yesterdayDay);
      expect(chatTime(DateTime(2026, 10, 1), now: now), '01.10.2026');
      expect(dayLabel(DateTime(2026, 10, 18, 1), now: now), S.today);
      expect(dayLabel(DateTime(2026, 10, 17, 1), now: now), S.yesterdayDay);
      expect(dayLabel(DateTime(2026, 10, 3), now: now), '3 oktýabr');
      expect(dayLabel(DateTime(2025, 3, 3), now: now), '3 mart 2025');
      expect(fileSize(820 * 1024), '820 KB');
      expect(fileSize(1468006), '1,4 MB');
    });

    test('notification payloads', () {
      expect(chatIdFromPayload(chatPayload(12)), 12);
      expect(chatIdFromPayload('other'), isNull);
      expect(chatIdFromPayload(null), isNull);
    });
  });
}
