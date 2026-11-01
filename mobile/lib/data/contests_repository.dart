import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

/// Ýaryşlar: list, detail, entering and voting.
class ContestsRepository {
  ContestsRepository(this._api);
  final ApiClient _api;

  /// `GET /contests` (running first); [status] filters.
  Future<List<Contest>> list({ContestStatus? status}) async => parseList(
    await _api.get('/contests', query: {'status': status?.value}),
    Contest.fromJson,
  );

  Future<ContestDetail> get(int id) async =>
      ContestDetail.fromJson(parseJson(await _api.get('/contests/$id')));

  /// Enters one of my posts (409 if I already entered).
  Future<Contest> enter(int id, int pinId) async => Contest.fromJson(
    parseJson(await _api.post('/contests/$id/entries', data: {'pinId': pinId})),
  );

  /// Withdraws my entry (its votes are freed).
  Future<Contest> leave(int id) async =>
      Contest.fromJson(parseJson(await _api.delete('/contests/$id/entries')));

  /// One final vote per contest (409 if I already voted).
  Future<Contest> vote(int id, int pinId) async => Contest.fromJson(
    parseJson(await _api.post('/contests/$id/vote', data: {'pinId': pinId})),
  );
}
