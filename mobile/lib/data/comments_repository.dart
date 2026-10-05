import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

class CommentsRepository {
  CommentsRepository(this._api);
  final ApiClient _api;

  Future<Page<Comment>> list(int pinId, int page) async => Page.fromJson(
    parseJson(
      await _api.get(
        '/pins/$pinId/comments',
        query: {'page': page, 'limit': 30},
      ),
    ),
    Comment.fromJson,
  );

  Future<Comment> add(int pinId, String text) async => Comment.fromJson(
    parseJson(await _api.post('/pins/$pinId/comments', data: {'text': text})),
  );

  Future<void> delete(int commentId) => _api.delete('/comments/$commentId');
}
