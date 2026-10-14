import 'json.dart';
import 'page.dart';
import 'user.dart';

class Review {
  const Review({
    required this.id,
    required this.rating,
    this.text = '',
    required this.author,
    this.canDelete = false,
    this.createdAt,
  });

  factory Review.fromJson(Json j) => Review(
    id: asInt(j['id']),
    rating: asInt(j['rating']),
    text: asString(j['text']),
    author: UserBrief.fromJson(asJson(j['author'])),
    canDelete: asBool(j['canDelete']),
    createdAt: asDate(j['createdAt']),
  );

  final int id;

  /// 1..5
  final int rating;
  final String text;
  final UserBrief author;
  final bool canDelete;
  final DateTime? createdAt;
}

/// `GET /pins/:id/reviews`: a page plus the pin's summary and whether the
/// viewer may write a review (bought it and the order was delivered).
class ReviewsPage extends Page<Review> {
  const ReviewsPage({
    required super.items,
    super.page,
    super.limit,
    super.hasMore,
    this.rating = 0,
    this.reviewsCount = 0,
    this.canReview = false,
  });

  factory ReviewsPage.fromJson(Json j) {
    final p = Page.fromJson(j, Review.fromJson);
    return ReviewsPage(
      items: p.items,
      page: p.page,
      limit: p.limit,
      hasMore: p.hasMore,
      rating: asDouble(j['rating']),
      reviewsCount: asInt(j['reviewsCount']),
      canReview: asBool(j['canReview']),
    );
  }

  final double rating;
  final int reviewsCount;
  final bool canReview;
}
