import 'package:dio/dio.dart';

import '../config.dart';
import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

class PinsRepository {
  PinsRepository(this._api);
  final ApiClient _api;

  Future<List<Category>> categories() async =>
      parseList(await _api.get('/categories'), Category.fromJson);

  Future<Page<Pin>> list({
    String? q,
    String? category,
    bool following = false,
    int page = 1,
    int limit = AppConfig.pageSize,
  }) async => Page.fromJson(
    parseJson(
      await _api.get(
        '/pins',
        query: {
          'q': q?.trim(),
          'category': category,
          'feed': following ? 'following' : null,
          'page': page,
          'limit': limit,
        },
      ),
    ),
    Pin.fromJson,
  );

  Future<Pin> get(int id) async =>
      Pin.fromJson(parseJson(await _api.get('/pins/$id')));

  Future<Pin> create({
    required PickedImage image,
    required String title,
    required String category,
    String description = '',
    String link = '',
    String tags = '',
    int? boardId,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'image': image.toMultipart(),
      'title': title,
      'category': category,
      'description': description,
      'link': link,
      'tags': tags,
      if (boardId != null) 'boardId': '$boardId',
    });
    return Pin.fromJson(
      parseJson(
        await _api.post('/pins', data: form, onSendProgress: onProgress),
      ),
    );
  }

  Future<Pin> update(
    int id, {
    String? title,
    String? description,
    String? link,
    String? category,
    String? tags,
  }) async => Pin.fromJson(
    parseJson(
      await _api.put(
        '/pins/$id',
        data: {
          'title': ?title,
          'description': ?description,
          'link': ?link,
          'category': ?category,
          'tags': ?tags,
        },
      ),
    ),
  );

  Future<void> delete(int id) => _api.delete('/pins/$id');

  Future<Page<Pin>> similar(
    int id,
    int page, {
    int limit = AppConfig.pageSize,
  }) async => Page.fromJson(
    parseJson(
      await _api.get(
        '/pins/$id/similar',
        query: {'page': page, 'limit': limit},
      ),
    ),
    Pin.fromJson,
  );

  Future<LikeState> like(int id) async =>
      LikeState.fromJson(parseJson(await _api.post('/pins/$id/like')));

  Future<LikeState> unlike(int id) async =>
      LikeState.fromJson(parseJson(await _api.delete('/pins/$id/like')));
}
