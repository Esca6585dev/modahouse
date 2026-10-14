import 'json.dart';

/// `{name: "Gyzyl", hex: "#C62828"}`
class ColorOption {
  const ColorOption({required this.name, required this.hex});

  factory ColorOption.fromJson(Json j) =>
      ColorOption(name: asString(j['name']), hex: asString(j['hex']));

  final String name;
  final String hex;

  Json toJson() => {'name': name, 'hex': hex};

  @override
  bool operator ==(Object other) =>
      other is ColorOption && other.name == name && other.hex == hex;

  @override
  int get hashCode => Object.hash(name, hex);
}

/// "Täze", "Hit!", "Aksiýa" label on product cards (sale > hit > new).
enum ProductBadge {
  none(''),
  isNew('new'),
  hit('hit'),
  sale('sale');

  const ProductBadge(this.value);
  final String value;

  static ProductBadge parse(String? v) {
    for (final b in values) {
      if (b.value == v) return b;
    }
    return none;
  }
}

/// What a post is for (v3). `post` = just sharing (no price).
enum ListingType {
  post('post'),
  sale('sale'),
  rent('rent'),
  custom('custom');

  const ListingType(this.value);
  final String value;

  static ListingType parse(String? v, {ListingType fallback = sale}) {
    for (final t in values) {
      if (t.value == v) return t;
    }
    return fallback;
  }
}

/// Shop fields of a pin (set when the author is a business and price > 0).
class Product {
  const Product({
    required this.price,
    this.oldPrice = 0,
    this.colors = const [],
    this.sizes = const [],
    this.stock,
    this.deliveryDays = 0,
    this.returnDays = 0,
    this.material = '',
    this.badge = ProductBadge.none,
    this.listingType = 'sale',
    this.deposit = 0,
    this.minDays = 0,
    this.readyDays = 0,
  });

  factory Product.fromJson(Json j) => Product(
    price: asInt(j['price']),
    oldPrice: asInt(j['oldPrice']),
    colors: asList(j['colors'], (e) => ColorOption.fromJson(asJson(e))),
    sizes: asList(j['sizes'], asString),
    stock: asIntOrNull(j['stock']),
    deliveryDays: asInt(j['deliveryDays']),
    returnDays: asInt(j['returnDays']),
    material: asString(j['material']),
    badge: ProductBadge.parse(asString(j['badge'])),
    listingType: asString(j['listingType']).isEmpty
        ? 'sale'
        : asString(j['listingType']),
    deposit: asInt(j['deposit']),
    minDays: asInt(j['minDays']),
    readyDays: asInt(j['readyDays']),
  );

  /// TMT (whole manats).
  final int price;

  /// 0 = no discount; greater than [price] = discount.
  final int oldPrice;
  final List<ColorOption> colors;
  final List<String> sizes;

  /// null = not tracked (always available), 0 = out of stock.
  final int? stock;
  final int deliveryDays;
  final int returnDays;
  final String material;
  final ProductBadge badge;

  /// v3: `sale` (default), `rent` (price per day) or `custom` ("from" price).
  /// Only `sale` products can go into the cart; the others are "contact the
  /// seller".
  final String listingType;

  /// Rent: deposit in TMT (0 = none).
  final int deposit;

  /// Rent: minimum rental days (0 = none).
  final int minDays;

  /// Custom: days to make (0 = unknown).
  final int readyDays;

  bool get isSale => listingType == 'sale';

  ListingType get type => ListingType.parse(listingType);

  bool get hasDiscount => oldPrice > price && price > 0;

  /// Discount in percent (rounded), 0 when there is none.
  int get discountPercent =>
      hasDiscount ? ((oldPrice - price) * 100 / oldPrice).round() : 0;

  bool get inStock => stock == null || stock! > 0;

  bool get hasOptions => colors.isNotEmpty || sizes.isNotEmpty;
}

/// One image of a pin (`images[0]` is the cover).
class PinImage {
  const PinImage({
    required this.url,
    this.width = 0,
    this.height = 0,
    this.color = '',
    this.type = 'image',
    this.posterUrl = '',
    this.duration = 0,
  });

  factory PinImage.fromJson(Json j) => PinImage(
    url: asString(j['url']),
    width: asInt(j['width']),
    height: asInt(j['height']),
    color: asString(j['color']),
    type: asString(j['type']).isEmpty ? 'image' : asString(j['type']),
    posterUrl: asString(j['posterUrl']),
    duration: asDouble(j['duration']),
  );

  /// The image, or the video file (MP4 / WebM).
  final String url;

  /// `image` or `video`.
  final String type;

  /// Video: poster image ("" for images).
  final String posterUrl;

  /// Video: seconds (0 = unknown).
  final double duration;

  bool get isVideo => type == 'video';

  /// What to show as a still: the poster for videos.
  String get stillUrl => isVideo && posterUrl.isNotEmpty ? posterUrl : url;

  final int width;
  final int height;
  final String color;

  double get aspectRatio {
    if (width <= 0 || height <= 0) return 3 / 4;
    return (width / height).clamp(0.45, 2.2);
  }
}
