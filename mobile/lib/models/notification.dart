import 'json.dart';
import 'order.dart';
import 'user.dart';

enum NotificationType {
  like,
  comment,
  follow,
  save,
  order,
  orderStatus,
  review,
  unknown,
}

NotificationType notificationTypeFrom(String v) {
  switch (v) {
    case 'like':
      return NotificationType.like;
    case 'comment':
      return NotificationType.comment;
    case 'follow':
      return NotificationType.follow;
    case 'save':
      return NotificationType.save;
    case 'order':
      return NotificationType.order;
    case 'order_status':
      return NotificationType.orderStatus;
    case 'review':
      return NotificationType.review;
    default:
      return NotificationType.unknown;
  }
}

/// The small pin preview attached to like/comment/save notifications.
class NotificationPin {
  const NotificationPin({
    required this.id,
    required this.title,
    this.imageUrl = '',
  });

  factory NotificationPin.fromJson(Json j) => NotificationPin(
    id: asInt(j['id']),
    title: asString(j['title']),
    imageUrl: asString(j['imageUrl']),
  );

  final int id;
  final String title;
  final String imageUrl;
}

/// The order attached to `order` / `order_status` notifications.
class NotificationOrder {
  const NotificationOrder({
    required this.id,
    required this.status,
    this.currentStatus,
    this.total = 0,
    this.role = '',
  });

  factory NotificationOrder.fromJson(Json j) => NotificationOrder(
    id: asInt(j['id']),
    status: OrderStatus.parse(asString(j['status'])),
    currentStatus: j['currentStatus'] == null
        ? null
        : OrderStatus.parse(asString(j['currentStatus'])),
    total: asInt(j['total']),
    role: asString(j['role']),
  );

  final int id;

  /// The step this notification is about.
  final OrderStatus status;

  /// The order's status now (null on older servers).
  final OrderStatus? currentStatus;
  final int total;

  /// `buyer` or `seller`: who received the notification.
  final String role;

  bool get forSeller => role == 'seller';
}

/// Named after the API type. Flutter also has a `Notification` widget class,
/// so files that use both import material with `hide Notification`.
class Notification {
  const Notification({
    required this.id,
    required this.type,
    required this.read,
    required this.actor,
    this.pin,
    this.order,
    this.createdAt,
  });

  factory Notification.fromJson(Json j) => Notification(
    id: asInt(j['id']),
    type: notificationTypeFrom(asString(j['type'])),
    read: asBool(j['read']),
    actor: UserBrief.fromJson(asJson(j['actor'])),
    pin: j['pin'] is Map ? NotificationPin.fromJson(asJson(j['pin'])) : null,
    order: j['order'] is Map
        ? NotificationOrder.fromJson(asJson(j['order']))
        : null,
    createdAt: asDate(j['createdAt']),
  );

  final int id;
  final NotificationType type;
  final bool read;
  final UserBrief actor;
  final NotificationPin? pin;
  final NotificationOrder? order;
  final DateTime? createdAt;
}
