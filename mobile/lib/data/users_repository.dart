import '../config.dart';
import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

class UsersRepository {
  UsersRepository(this._api);
  final ApiClient _api;

  Future<Profile> profile(String username) async =>
      Profile.fromJson(parseJson(await _api.get('/users/${encodeSegment(username)}')));

  Future<Page<Pin>> pins(String username, int page, {int limit = AppConfig.pageSize}) async =>
      Page.fromJson(
        parseJson(await _api.get('/users/${encodeSegment(username)}/pins', query: {'page': page, 'limit': limit})),
        Pin.fromJson,
      );

  Future<List<Board>> boards(String username) async =>
      parseList(await _api.get('/users/${encodeSegment(username)}/boards'), Board.fromJson);

  Future<Page<UserBrief>> followers(String username, int page) async => Page.fromJson(
        parseJson(await _api.get('/users/${encodeSegment(username)}/followers', query: {'page': page, 'limit': 30})),
        UserBrief.fromJson,
      );

  Future<Page<UserBrief>> following(String username, int page) async => Page.fromJson(
        parseJson(await _api.get('/users/${encodeSegment(username)}/following', query: {'page': page, 'limit': 30})),
        UserBrief.fromJson,
      );

  Future<Profile> follow(String username) async =>
      Profile.fromJson(parseJson(await _api.post('/users/${encodeSegment(username)}/follow')));

  Future<Profile> unfollow(String username) async =>
      Profile.fromJson(parseJson(await _api.delete('/users/${encodeSegment(username)}/follow')));
}
