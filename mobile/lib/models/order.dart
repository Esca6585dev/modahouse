import 'json.dart';
import 'user.dart';

enum OrderStatus {
  isNew('new'),
  confirmed('confirmed'),
  shipped('shipped'),
  delivered('delivered'),
  cancelled('cancelled'),
  unknown('');

  const OrderStatus(this.value);

  /// API value, e.g. `new`.
  final String value;

  static OrderStatus parse(String? v) {
    for (final s in values) {
      if (s.value == v && s != unknown) return s;
    }
    return unknown;
  }

  /// The happy path shown in the status timeline.
  static const flow = [isNew, confirmed, shipped, delivered];

  /// Position in [flow] (-1 for cancelled / unknown).
  int get step => flow.indexOf(this);
}

class OrderItem {
  const OrderItem({
    this.pinId,
    required this.title,
    this.imageUrl = '',
    this.price = 0,
    this.color = '',
    this.size = '',
    this.quantity = 1,
  });

  factory OrderItem.fromJson(Json j) => OrderItem(
    pinId: asIntOrNull(j['pinId']),
    title: asString(j['title']),
    imageUrl: asString(j['imageUrl']),
    price: asInt(j['price']),
    color: asString(j['color']),
    size: asString(j['size']),
    quantity: asInt(j['quantity']),
  );

  /// null when the product was deleted later.
  final int? pinId;
  final String title;
  final String imageUrl;
  final int price;
  final String color;
  final String size;
  final int quantity;

  int get lineTotal => price * quantity;
}

class Order {
  const Order({
    required this.id,
    required this.status,
    this.total = 0,
    required this.buyer,
    required this.business,
    this.fullName = '',
    this.phone = '',
    this.address = '',
    this.note = '',
    this.items = const [],
    this.canCancel = false,
    this.nextStatuses = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Json j) => Order(
    id: asInt(j['id']),
    status: OrderStatus.parse(asString(j['status'])),
    total: asInt(j['total']),
    buyer: UserBrief.fromJson(asJson(j['buyer'])),
    business: UserBrief.fromJson(asJson(j['business'])),
    fullName: asString(j['fullName']),
    phone: asString(j['phone']),
    address: asString(j['address']),
    note: asString(j['note']),
    items: asList(j['items'], (e) => OrderItem.fromJson(asJson(e))),
    canCancel: asBool(j['canCancel']),
    nextStatuses: asList(
      j['nextStatuses'],
      (e) => OrderStatus.parse(asString(e)),
    ).where((s) => s != OrderStatus.unknown).toList(),
    createdAt: asDate(j['createdAt']),
    updatedAt: asDate(j['updatedAt']),
  );

  final int id;
  final OrderStatus status;
  final int total;
  final UserBrief buyer;
  final UserBrief business;
  final String fullName;
  final String phone;
  final String address;
  final String note;
  final List<OrderItem> items;

  /// Buyer, while the status is "new".
  final bool canCancel;

  /// What the business may set next.
  final List<OrderStatus> nextStatuses;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get itemsCount => items.fold(0, (n, i) => n + i.quantity);
}

/// Body of `POST /orders` → `buyNow`.
class BuyNow {
  const BuyNow({
    required this.pinId,
    this.color = '',
    this.size = '',
    this.quantity = 1,
  });

  final int pinId;
  final String color;
  final String size;
  final int quantity;

  Json toJson() => {
    'pinId': pinId,
    if (color.isNotEmpty) 'color': color,
    if (size.isNotEmpty) 'size': size,
    'quantity': quantity,
  };
}
