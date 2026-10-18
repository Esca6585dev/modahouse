import 'dart:typed_data';

import 'json.dart';
import 'user.dart';

/// A file attached to a chat message (`Attachment` in docs/API.md, v6).
///
/// The URL is signed and valid for 24 hours; every message list returns
/// fresh links.
class Attachment {
  const Attachment({
    required this.url,
    this.name = '',
    this.size = 0,
    this.mimeType = '',
    this.width = 0,
    this.height = 0,
  });

  factory Attachment.fromJson(Json j) => Attachment(
    url: asString(j['url']),
    name: asString(j['name']),
    size: asInt(j['size']),
    mimeType: asString(j['mimeType']),
    width: asInt(j['width']),
    height: asInt(j['height']),
  );

  final String url;
  final String name;

  /// Bytes.
  final int size;
  final String mimeType;
  final int width;
  final int height;

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');

  /// width / height for image bubbles, guarded against missing sizes.
  double get aspectRatio {
    if (width <= 0 || height <= 0) return 1;
    return (width / height).clamp(0.5, 1.9);
  }
}

/// A shared post inside a message (`PinPreview`).
class PinPreview {
  const PinPreview({
    required this.id,
    this.title = '',
    this.imageUrl = '',
    this.width = 0,
    this.height = 0,
    this.color = '',
    this.price = 0,
    this.listingType = '',
  });

  factory PinPreview.fromJson(Json j) => PinPreview(
    id: asInt(j['id']),
    title: asString(j['title']),
    imageUrl: asString(j['imageUrl']),
    width: asInt(j['width']),
    height: asInt(j['height']),
    color: asString(j['color']),
    price: asInt(j['price']),
    listingType: asString(j['listingType']),
  );

  final int id;
  final String title;
  final String imageUrl;
  final int width;
  final int height;
  final String color;

  /// 0 = not for sale.
  final int price;

  /// `post`, `sale`, `rent`, `custom` (or "").
  final String listingType;
}

enum MessageKind {
  text,
  image,
  file,
  pin;

  static MessageKind parse(String v) => switch (v) {
    'image' => MessageKind.image,
    'file' => MessageKind.file,
    'pin' => MessageKind.pin,
    _ => MessageKind.text,
  };
}

/// Where an own message is: on the server, still being sent, or failed.
enum MessageStatus { sent, pending, failed }

/// A file chosen in the composer, kept until the server accepted it (so a
/// failed upload can be sent again).
class OutgoingFile {
  const OutgoingFile({
    required this.bytes,
    required this.name,
    required this.mimeType,
    this.width = 0,
    this.height = 0,
  });

  final Uint8List bytes;
  final String name;
  final String mimeType;
  final int width;
  final int height;

  bool get isImage => mimeType.startsWith('image/');
}

class Message {
  const Message({
    required this.id,
    required this.chatId,
    required this.sender,
    this.kind = MessageKind.text,
    this.text = '',
    this.attachment,
    this.pin,
    this.clientId = '',
    this.mine = false,
    this.read = false,
    this.deleted = false,
    this.createdAt,
    this.status = MessageStatus.sent,
    this.progress,
    this.file,
  });

  factory Message.fromJson(Json j) => Message(
    id: asInt(j['id']),
    chatId: asInt(j['chatId']),
    sender: UserBrief.fromJson(asJson(j['sender'])),
    kind: MessageKind.parse(asString(j['kind'])),
    text: asString(j['text']),
    attachment: j['attachment'] is Map
        ? Attachment.fromJson(asJson(j['attachment']))
        : null,
    pin: j['pin'] is Map ? PinPreview.fromJson(asJson(j['pin'])) : null,
    clientId: asString(j['clientId']),
    mine: asBool(j['mine']),
    read: asBool(j['read']),
    deleted: asBool(j['deleted']),
    createdAt: asDate(j['createdAt']),
  );

  /// Server id; 0 for an optimistic message that was not accepted yet.
  final int id;
  final int chatId;
  final UserBrief sender;
  final MessageKind kind;

  /// The text, or the caption of an image/file/post. "" when deleted.
  final String text;
  final Attachment? attachment;
  final PinPreview? pin;

  /// Echoed from the send request; matches optimistic bubbles.
  final String clientId;

  /// Sent by the viewer.
  final bool mine;

  /// The other side has read it.
  final bool read;
  final bool deleted;
  final DateTime? createdAt;

  // ---- Local only (optimistic sending) ----
  final MessageStatus status;

  /// Upload progress 0..1 while a file is sent.
  final double? progress;

  /// The file being sent (preview and "Gaýtadan ugrat").
  final OutgoingFile? file;

  bool get isPending => status == MessageStatus.pending;
  bool get isFailed => status == MessageStatus.failed;
  bool get isLocal => id == 0;

  Message copyWith({
    int? id,
    bool? read,
    bool? deleted,
    String? text,
    MessageStatus? status,
    double? progress,
    bool clearProgress = false,
    DateTime? createdAt,
    String? clientId,
  }) => Message(
    id: id ?? this.id,
    chatId: chatId,
    sender: sender,
    kind: kind,
    text: text ?? this.text,
    attachment: (deleted ?? this.deleted) ? null : attachment,
    pin: (deleted ?? this.deleted) ? null : pin,
    clientId: clientId ?? this.clientId,
    mine: mine,
    read: read ?? this.read,
    deleted: deleted ?? this.deleted,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    progress: clearProgress ? null : (progress ?? this.progress),
    file: file,
  );

  /// "Bu habar pozuldy" version of this message.
  Message asDeleted() => copyWith(deleted: true, text: '');
}

class Chat {
  const Chat({
    required this.id,
    required this.other,
    this.lastMessage,
    this.unreadCount = 0,
    this.blocked = false,
    this.updatedAt,
  });

  factory Chat.fromJson(Json j) => Chat(
    id: asInt(j['id']),
    other: UserBrief.fromJson(asJson(j['other'])),
    lastMessage: j['lastMessage'] is Map
        ? Message.fromJson(asJson(j['lastMessage']))
        : null,
    unreadCount: asInt(j['unreadCount']),
    blocked: asBool(j['blocked']),
    updatedAt: asDate(j['updatedAt']),
  );

  final int id;

  /// The person on the other side.
  final UserBrief other;
  final Message? lastMessage;

  /// Messages from the other side not read yet.
  final int unreadCount;

  /// Either side blocked the other: sending is disabled.
  final bool blocked;
  final DateTime? updatedAt;

  Chat copyWith({
    Message? lastMessage,
    int? unreadCount,
    bool? blocked,
    DateTime? updatedAt,
  }) => Chat(
    id: id,
    other: other,
    lastMessage: lastMessage ?? this.lastMessage,
    unreadCount: unreadCount ?? this.unreadCount,
    blocked: blocked ?? this.blocked,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// `GET /chats/:id/messages`: oldest → newest.
class MessagePage {
  const MessagePage({this.items = const [], this.hasMore = false});

  factory MessagePage.fromJson(Json j) => MessagePage(
    items: asList(j['items'], (e) => Message.fromJson(asJson(e))),
    hasMore: asBool(j['hasMore']),
  );

  final List<Message> items;
  final bool hasMore;
}
