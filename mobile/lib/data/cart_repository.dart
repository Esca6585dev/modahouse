import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

class CartRepository {
  CartRepository(this._api);
  final ApiClient _api;

  Future<Cart> get() async => Cart.fromJson(parseJson(await _api.get('/cart')));

  Future<int> count() async =>
      asInt(parseJson(await _api.get('/cart/count'))['count']);

  /// Adds a line (or increases an identical one). [color] / [size] are
  /// required when the product has options.
  Future<Cart> add(
    int pinId, {
    String color = '',
    String size = '',
    int quantity = 1,
  }) async => Cart.fromJson(
    parseJson(
      await _api.post(
        '/cart',
        data: {
          'pinId': pinId,
          if (color.isNotEmpty) 'color': color,
          if (size.isNotEmpty) 'size': size,
          'quantity': quantity,
        },
      ),
    ),
  );

  Future<Cart> setQuantity(int itemId, int quantity) async => Cart.fromJson(
    parseJson(await _api.put('/cart/$itemId', data: {'quantity': quantity})),
  );

  Future<Cart> remove(int itemId) async =>
      Cart.fromJson(parseJson(await _api.delete('/cart/$itemId')));

  Future<Cart> clear() async =>
      Cart.fromJson(parseJson(await _api.delete('/cart')));
}
