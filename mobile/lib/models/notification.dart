import 'json.dart';
import 'user.dart';

enum NotificationType { like, comment, follow, save, unknown }

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

/// Named after the API type. Flutter also has a `Notification` widget class,
/// so files that use both import material with `hide Notification`.
class Notification {
  const Notification({
    required this.id,
    required this.type,
    required this.read,
    required this.actor,
    this.pin,
    this.createdAt,
  });

  factory Notification.fromJson(Json j) => Notification(
    id: asInt(j['id']),
    type: notificationTypeFrom(asString(j['type'])),
    read: asBool(j['read']),
    actor: UserBrief.fromJson(asJson(j['actor'])),
    pin: j['pin'] is Map ? NotificationPin.fromJson(asJson(j['pin'])) : null,
    createdAt: asDate(j['createdAt']),
  );

  final int id;
  final NotificationType type;
  final bool read;
  final UserBrief actor;
  final NotificationPin? pin;
  final DateTime? createdAt;
}
