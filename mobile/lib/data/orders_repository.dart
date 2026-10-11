import '../config.dart';
import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

class OrdersRepository {
  OrdersRepository(this._api);
  final ApiClient _api;

  /// Places the order: the cart lines in [cartItemIds] (default: all
  /// available lines) or a single [buyNow] product. Returns one order per shop.
  Future<List<Order>> create({
    required String fullName,
    required String phone,
    required String address,
    String note = '',
    List<int>? cartItemIds,
    BuyNow? buyNow,
  }) async => parseList(
    await _api.post(
      '/orders',
      data: {
        'fullName': fullName,
        'phone': phone,
        'address': address,
        'note': note,
        'cartItemIds': ?cartItemIds,
        'buyNow': ?buyNow?.toJson(),
      },
    ),
    Order.fromJson,
  );

  /// My purchases.
  Future<Page<Order>> mine({
    OrderStatus? status,
    int page = 1,
    int limit = AppConfig.pageSize,
  }) async => Page.fromJson(
    parseJson(
      await _api.get(
        '/orders',
        query: {'status': status?.value, 'page': page, 'limit': limit},
      ),
    ),
    Order.fromJson,
  );

  Future<Order> get(int id) async =>
      Order.fromJson(parseJson(await _api.get('/orders/$id')));

  Future<Order> cancel(int id) async =>
      Order.fromJson(parseJson(await _api.post('/orders/$id/cancel')));

  /// Orders my shop received.
  Future<Page<Order>> incoming({
    OrderStatus? status,
    int page = 1,
    int limit = AppConfig.pageSize,
  }) async => Page.fromJson(
    parseJson(
      await _api.get(
        '/business/orders',
        query: {'status': status?.value, 'page': page, 'limit': limit},
      ),
    ),
    Order.fromJson,
  );

  /// Business: new→confirmed/cancelled, confirmed→shipped/cancelled,
  /// shipped→delivered.
  Future<Order> setStatus(int id, OrderStatus status) async => Order.fromJson(
    parseJson(
      await _api.put('/business/orders/$id', data: {'status': status.value}),
    ),
  );
}
