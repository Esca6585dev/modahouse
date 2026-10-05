import 'json.dart';
import 'user.dart';

class Pin {
  const Pin({
    required this.id,
    required this.title,
    this.description = '',
    this.link = '',
    this.category = '',
    this.tags = const [],
    this.imageUrl = '',
    this.width = 0,
    this.height = 0,
    this.color = '',
    required this.author,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.liked = false,
    this.savedBoardIds = const [],
    this.createdAt,
  });

  factory Pin.fromJson(Json j) => Pin(
    id: asInt(j['id']),
    title: asString(j['title']),
    description: asString(j['description']),
    link: asString(j['link']),
    category: asString(j['category']),
    tags: asList(j['tags'], asString),
    imageUrl: asString(j['imageUrl']),
    width: asInt(j['width']),
    height: asInt(j['height']),
    color: asString(j['color']),
    author: UserBrief.fromJson(asJson(j['author'])),
    likesCount: asInt(j['likesCount']),
    commentsCount: asInt(j['commentsCount']),
    liked: asBool(j['liked']),
    savedBoardIds: asList(j['savedBoardIds'], asInt),
    createdAt: asDate(j['createdAt']),
  );

  final int id;
  final String title;
  final String description;
  final String link;

  /// Category slug.
  final String category;
  final List<String> tags;

  /// Relative path such as `/uploads/seed/pin-01.svg`.
  final String imageUrl;
  final int width;
  final int height;

  /// Placeholder background while the image loads (`#rrggbb`).
  final String color;
  final UserBrief author;
  final int likesCount;
  final int commentsCount;
  final bool liked;

  /// The viewer's boards that contain this pin (empty = not saved).
  final List<int> savedBoardIds;
  final DateTime? createdAt;

  bool get isSaved => savedBoardIds.isNotEmpty;

  /// width / height, guarded against missing sizes and extreme shapes.
  double get aspectRatio {
    if (width <= 0 || height <= 0) return 3 / 4;
    return (width / height).clamp(0.45, 2.2);
  }

  Pin copyWith({
    String? title,
    String? description,
    String? link,
    String? category,
    List<String>? tags,
    int? likesCount,
    int? commentsCount,
    bool? liked,
    List<int>? savedBoardIds,
  }) => Pin(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    link: link ?? this.link,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    imageUrl: imageUrl,
    width: width,
    height: height,
    color: color,
    author: author,
    likesCount: likesCount ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    liked: liked ?? this.liked,
    savedBoardIds: savedBoardIds ?? this.savedBoardIds,
    createdAt: createdAt,
  );
}

/// Response of `POST/DELETE /pins/:id/like`.
class LikeState {
  const LikeState({required this.liked, required this.likesCount});

  factory LikeState.fromJson(Json j) =>
      LikeState(liked: asBool(j['liked']), likesCount: asInt(j['likesCount']));

  final bool liked;
  final int likesCount;
}
