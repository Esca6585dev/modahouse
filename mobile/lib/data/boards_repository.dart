import '../config.dart';
import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

class BoardsRepository {
  BoardsRepository(this._api);
  final ApiClient _api;

  Future<List<Board>> mine() async => parseList(await _api.get('/me/boards'), Board.fromJson);

  Future<Board> get(int id) async => Board.fromJson(parseJson(await _api.get('/boards/$id')));

  Future<Board> create({required String name, String description = '', bool isPrivate = false}) async =>
      Board.fromJson(parseJson(await _api.post('/boards', data: {
        'name': name,
        'description': description,
        'isPrivate': isPrivate,
      })));

  Future<Board> update(int id, {String? name, String? description, bool? isPrivate}) async =>
      Board.fromJson(parseJson(await _api.put('/boards/$id', data: {
        'name': ?name,
        'description': ?description,
        'isPrivate': ?isPrivate,
      })));

  Future<void> delete(int id) => _api.delete('/boards/$id');

  Future<Page<Pin>> pins(int id, int page, {int limit = AppConfig.pageSize}) async => Page.fromJson(
        parseJson(await _api.get('/boards/$id/pins', query: {'page': page, 'limit': limit})),
        Pin.fromJson,
      );

  Future<Pin> savePin(int boardId, int pinId) async =>
      Pin.fromJson(parseJson(await _api.post('/boards/$boardId/pins/$pinId')));

  /// Returns the updated pin, or null if the server answered with no body.
  Future<Pin?> unsavePin(int boardId, int pinId) async {
    final data = await _api.delete('/boards/$boardId/pins/$pinId');
    return data is Map ? Pin.fromJson(parseJson(data)) : null;
  }
}
