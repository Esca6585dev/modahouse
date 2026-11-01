import 'comment.dart';
import 'json.dart';
import 'product.dart';
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
    this.images = const [],
    this.product,
    this.viewsCount = 0,
    this.ordersCount = 0,
    this.rating = 0,
    this.reviewsCount = 0,
    this.mediaType = 'image',
    this.latestComments = const [],
    this.credit = '',
    this.promoted = false,
    this.boostedUntil,
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
    images: asList(j['images'], (e) => PinImage.fromJson(asJson(e))),
    product: j['product'] is Map
        ? Product.fromJson(asJson(j['product']))
        : null,
    viewsCount: asInt(j['viewsCount']),
    ordersCount: asInt(j['ordersCount']),
    rating: asDouble(j['rating']),
    reviewsCount: asInt(j['reviewsCount']),
    mediaType: asString(j['mediaType']).isEmpty
        ? 'image'
        : asString(j['mediaType']),
    latestComments: asList(
      j['latestComments'],
      (e) => Comment.fromJson(asJson(e)),
    ),
    credit: asString(j['credit']),
    promoted: asBool(j['promoted']),
    boostedUntil: asDate(j['boostedUntil']),
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

  /// 1..8 images, the first one is the cover (= [imageUrl]).
  final List<PinImage> images;

  /// Shop fields; null for idea pins.
  final Product? product;
  final int viewsCount;
  final int ordersCount;

  /// 0..5 average review rating of this pin.
  final double rating;
  final int reviewsCount;

  /// `image` or `video` (type of the first media item).
  final String mediaType;

  /// The two latest comments (only with `?withComments=1`).
  final List<Comment> latestComments;

  /// Photo credit of an imported, openly licensed photo (e.g. "Surat:
  /// A. Author · CC BY-SA 4.0 · Wikimedia Commons"); [link] is the source.
  final String credit;

  /// Boosted with teňňe and shown at the top of a feed ("Öňe çykarylan").
  final bool promoted;

  /// End of the running boost (sent to the owner only).
  final DateTime? boostedUntil;

  bool get isSaved => savedBoardIds.isNotEmpty;

  bool get isVideo => mediaType == 'video';

  bool get isProduct => product != null;

  /// Images for the carousel; falls back to the cover for older servers.
  List<PinImage> get gallery => images.isNotEmpty
      ? images
      : [PinImage(url: imageUrl, width: width, height: height, color: color)];

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
    Product? product,
    int? viewsCount,
    double? rating,
    int? reviewsCount,
    DateTime? boostedUntil,
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
    images: images,
    product: product ?? this.product,
    viewsCount: viewsCount ?? this.viewsCount,
    ordersCount: ordersCount,
    rating: rating ?? this.rating,
    reviewsCount: reviewsCount ?? this.reviewsCount,
    mediaType: mediaType,
    latestComments: latestComments,
    credit: credit,
    promoted: promoted,
    boostedUntil: boostedUntil ?? this.boostedUntil,
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
