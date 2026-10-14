import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

class StoriesRepository {
  StoriesRepository(this._api);
  final ApiClient _api;

  /// Own group first, then followed users, then other businesses.
  Future<List<StoryGroup>> feed() async =>
      parseList(await _api.get('/stories'), StoryGroup.fromJson);

  /// 404 when the user has no active story.
  Future<StoryGroup> ofUser(String username) async => StoryGroup.fromJson(
    parseJson(await _api.get('/users/${encodeSegment(username)}/stories')),
  );

  Future<Story> create({
    required PickedImage image,
    String caption = '',
    int? pinId,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      if (image.isVideo) ...{
        'video': image.toMultipart(),
        if (image.poster != null) 'poster': image.poster!.toMultipart(),
      } else
        'image': image.toMultipart(),
      'caption': caption,
      if (pinId != null) 'pinId': '$pinId',
    });
    return Story.fromJson(
      parseJson(
        await _api.post('/stories', data: form, onSendProgress: onProgress),
      ),
    );
  }

  Future<void> markViewed(int storyId) => _api.post('/stories/$storyId/view');

  Future<void> delete(int storyId) => _api.delete('/stories/$storyId');
}
