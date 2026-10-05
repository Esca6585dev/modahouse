import 'json.dart';
import 'user.dart';

class Comment {
  const Comment({
    required this.id,
    required this.text,
    required this.author,
    this.canDelete = false,
    this.createdAt,
  });

  factory Comment.fromJson(Json j) => Comment(
        id: asInt(j['id']),
        text: asString(j['text']),
        author: UserBrief.fromJson(asJson(j['author'])),
        canDelete: asBool(j['canDelete']),
        createdAt: asDate(j['createdAt']),
      );

  final int id;
  final String text;
  final UserBrief author;
  final bool canDelete;
  final DateTime? createdAt;
}
