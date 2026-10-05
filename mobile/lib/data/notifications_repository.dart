import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);
  final ApiClient _api;

  Future<Page<Notification>> list(int page) async => Page.fromJson(
        parseJson(await _api.get('/notifications', query: {'page': page, 'limit': 30})),
        Notification.fromJson,
      );

  Future<int> unreadCount() async => asInt(parseJson(await _api.get('/notifications/unread-count'))['count']);

  Future<void> readAll() => _api.post('/notifications/read-all');
}
