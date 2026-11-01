import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

/// Teňňe: balance, packages, top-up requests and history.
class CoinsRepository {
  CoinsRepository(this._api);
  final ApiClient _api;

  /// `GET /me/coins`.
  Future<CoinsInfo> mine() async =>
      CoinsInfo.fromJson(parseJson(await _api.get('/me/coins')));

  /// `POST /me/coins/requests`: "I paid, add my teňňe" (an admin approves).
  Future<CoinRequest> request(int coins, {String note = ''}) async =>
      CoinRequest.fromJson(
        parseJson(
          await _api.post(
            '/me/coins/requests',
            data: {
              'coins': coins,
              if (note.trim().isNotEmpty) 'note': note.trim(),
            },
          ),
        ),
      );
}
