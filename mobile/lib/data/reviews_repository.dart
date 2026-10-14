import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

class ReviewsRepository {
  ReviewsRepository(this._api);
  final ApiClient _api;

  Future<ReviewsPage> list(int pinId, int page, {int limit = 10}) async =>
      ReviewsPage.fromJson(
        parseJson(
          await _api.get(
            '/pins/$pinId/reviews',
            query: {'page': page, 'limit': limit},
          ),
        ),
      );

  /// One review per user per pin; posting again updates it.
  Future<Review> add(
    int pinId, {
    required int rating,
    String text = '',
  }) async => Review.fromJson(
    parseJson(
      await _api.post(
        '/pins/$pinId/reviews',
        data: {'rating': rating, 'text': text},
      ),
    ),
  );

  Future<void> delete(int reviewId) => _api.delete('/reviews/$reviewId');
}
