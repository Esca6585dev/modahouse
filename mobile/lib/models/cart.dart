import 'json.dart';
import 'user.dart';

/// The product summary inside a cart line.
class CartPin {
  const CartPin({
    required this.id,
    required this.title,
    this.imageUrl = '',
    this.color = '',
    this.price = 0,
    this.oldPrice = 0,
    this.stock,
    required this.author,
  });

  factory CartPin.fromJson(Json j) => CartPin(
    id: asInt(j['id']),
    title: asString(j['title']),
    imageUrl: asString(j['imageUrl']),
    color: asString(j['color']),
    price: asInt(j['price']),
    oldPrice: asInt(j['oldPrice']),
    stock: asIntOrNull(j['stock']),
    author: UserBrief.fromJson(asJson(j['author'])),
  );

  final int id;
  final String title;
  final String imageUrl;

  /// Placeholder color of the image (not the chosen product color).
  final String color;
  final int price;
  final int oldPrice;
  final int? stock;
  final UserBrief author;
}

class CartItem {
  const CartItem({
    required this.id,
    required this.quantity,
    this.color = '',
    this.size = '',
    required this.pin,
    this.lineTotal = 0,
    this.available = true,
  });

  factory CartItem.fromJson(Json j) => CartItem(
    id: asInt(j['id']),
    quantity: asInt(j['quantity']),
    color: asString(j['color']),
    size: asString(j['size']),
    pin: CartPin.fromJson(asJson(j['pin'])),
    lineTotal: asInt(j['lineTotal']),
    available: j['available'] == null ? true : asBool(j['available']),
  );

  final int id;
  final int quantity;

  /// `ColorOption.name`, empty when the product has no colors.
  final String color;
  final String size;
  final CartPin pin;
  final int lineTotal;

  /// False when the product was removed, is no longer for sale or the stock
  /// is smaller than [quantity].
  final bool available;
}

class Cart {
  const Cart({this.items = const [], this.total = 0, this.count = 0});

  factory Cart.fromJson(Json j) => Cart(
    items: asList(j['items'], (e) => CartItem.fromJson(asJson(e))),
    total: asInt(j['total']),
    count: asInt(j['count']),
  );

  final List<CartItem> items;
  final int total;

  /// Sum of quantities (the badge number).
  final int count;

  bool get isEmpty => items.isEmpty;

  /// Lines grouped by shop, in the order the shops first appear.
  List<CartShopGroup> get byShop {
    final groups = <int, CartShopGroup>{};
    for (final item in items) {
      final shop = item.pin.author;
      final g = groups.putIfAbsent(
        shop.id,
        () => CartShopGroup(shop: shop, items: []),
      );
      g.items.add(item);
    }
    return groups.values.toList();
  }
}

class CartShopGroup {
  CartShopGroup({required this.shop, required this.items});

  final UserBrief shop;
  final List<CartItem> items;

  int get subtotal =>
      items.where((i) => i.available).fold(0, (sum, i) => sum + i.lineTotal);
}
