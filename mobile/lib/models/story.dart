import 'json.dart';
import 'user.dart';

class Story {
  const Story({
    required this.id,
    required this.imageUrl,
    this.width = 0,
    this.height = 0,
    this.color = '',
    this.caption = '',
    this.pinId,
    this.seen = false,
    this.viewsCount = 0,
    this.createdAt,
    this.expiresAt,
    this.mediaType = 'image',
    this.videoUrl = '',
  });

  factory Story.fromJson(Json j) => Story(
    id: asInt(j['id']),
    imageUrl: asString(j['imageUrl']),
    width: asInt(j['width']),
    height: asInt(j['height']),
    color: asString(j['color']),
    caption: asString(j['caption']),
    pinId: asIntOrNull(j['pinId']),
    seen: asBool(j['seen']),
    viewsCount: asInt(j['viewsCount']),
    createdAt: asDate(j['createdAt']),
    expiresAt: asDate(j['expiresAt']),
    mediaType: asString(j['mediaType']).isEmpty
        ? 'image'
        : asString(j['mediaType']),
    videoUrl: asString(j['videoUrl']),
  );

  final int id;
  final String imageUrl;
  final int width;
  final int height;
  final String color;
  final String caption;

  /// Linked product, if any.
  final int? pinId;
  final bool seen;

  /// Only filled for the owner.
  final int viewsCount;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  /// `image` or `video`; for videos [imageUrl] is the poster.
  final String mediaType;
  final String videoUrl;

  bool get isVideo => mediaType == 'video' && videoUrl.isNotEmpty;

  Story copyWith({bool? seen}) => Story(
    id: id,
    imageUrl: imageUrl,
    width: width,
    height: height,
    color: color,
    caption: caption,
    pinId: pinId,
    seen: seen ?? this.seen,
    viewsCount: viewsCount,
    createdAt: createdAt,
    expiresAt: expiresAt,
    mediaType: mediaType,
    videoUrl: videoUrl,
  );
}

class StoryGroup {
  const StoryGroup({
    required this.user,
    this.stories = const [],
    this.allSeen = false,
  });

  factory StoryGroup.fromJson(Json j) => StoryGroup(
    user: UserBrief.fromJson(asJson(j['user'])),
    stories: asList(j['stories'], (e) => Story.fromJson(asJson(e))),
    allSeen: asBool(j['allSeen']),
  );

  final UserBrief user;
  final List<Story> stories;
  final bool allSeen;

  /// First unseen story (where the viewer starts), or 0.
  int get firstUnseen {
    final i = stories.indexWhere((s) => !s.seen);
    return i < 0 ? 0 : i;
  }

  StoryGroup markSeen(int storyId) {
    final list = [
      for (final s in stories) s.id == storyId ? s.copyWith(seen: true) : s,
    ];
    return StoryGroup(
      user: user,
      stories: list,
      allSeen: list.every((s) => s.seen),
    );
  }
}
