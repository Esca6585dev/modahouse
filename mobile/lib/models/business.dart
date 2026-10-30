import 'json.dart';
import 'user.dart';

/// Business category slugs (`GET /business-categories`) with their Turkmen
/// names, used until the server list is loaded.
const businessCategoryNames = <String, String>{
  'tailor': 'Tikinçi',
  'kurte': 'Kürte tikinçi',
  'atelier': 'Atelýe',
  'designer': 'Dizaýner',
  'embroidery': 'El keşdeçi',
  'dress': 'Köýnek dükany',
  'boutique': 'Butik',
  'bridal': 'Gelin salony',
  'rental': 'Kärende salony',
  'fata': 'Fata satyjy',
  'beauty': 'Gözellik salony',
  'hair': 'Saç ussasy',
  'makeup': 'Makiýažçy',
  'lashes': 'Kirpikçi',
  'nails': 'Dyrnakçy',
  'jewelry': 'Şaý-sep ussasy',
  'accessories': 'Aksessuarlar',
};

/// Shop details of a business profile.
class Business {
  const Business({
    this.category = '',
    this.phone = '',
    this.address = '',
    this.city = '',
    this.instagram = '',
    this.tiktok = '',
    this.telegram = '',
    this.whatsapp = '',
    this.imo = '',
    this.youtube = '',
    this.website = '',
    this.workingHours = '',
    this.deliveryDays = 0,
    this.returnDays = 0,
    this.rating = 0,
    this.reviewsCount = 0,
    this.ordersCount = 0,
    this.productsCount = 0,
  });

  factory Business.fromJson(Json j) => Business(
    category: asString(j['category']),
    phone: asString(j['phone']),
    address: asString(j['address']),
    city: asString(j['city']),
    instagram: asString(j['instagram']),
    tiktok: asString(j['tiktok']),
    telegram: asString(j['telegram']),
    whatsapp: asString(j['whatsapp']),
    imo: asString(j['imo']),
    youtube: asString(j['youtube']),
    website: asString(j['website']),
    workingHours: asString(j['workingHours']),
    deliveryDays: asInt(j['deliveryDays']),
    returnDays: asInt(j['returnDays']),
    rating: asDouble(j['rating']),
    reviewsCount: asInt(j['reviewsCount']),
    ordersCount: asInt(j['ordersCount']),
    productsCount: asInt(j['productsCount']),
  );

  /// Category slug, e.g. `rental` (see [businessCategoryNames]).
  final String category;
  final String phone;
  final String address;
  final String city;
  final String instagram;
  final String tiktok;
  final String telegram;
  final String whatsapp;
  final String imo;
  final String youtube;
  final String website;
  final String workingHours;

  /// Defaults for new products.
  final int deliveryDays;
  final int returnDays;

  /// 0..5 average of all product reviews (0 = no reviews).
  final double rating;
  final int reviewsCount;
  final int ordersCount;
  final int productsCount;
}

/// A shop in the directory (`GET /businesses`) and in the Top 10.
class BusinessCard extends UserBrief {
  const BusinessCard({
    required super.id,
    required super.username,
    required super.name,
    super.avatarUrl,
    super.isBusiness = true,
    super.verified,
    super.category,
    this.city = '',
    this.rating = 0,
    this.reviewsCount = 0,
    this.followersCount = 0,
    this.productsCount = 0,
    this.hasStory = false,
    this.covers = const [],
    this.isFollowing = false,
  });

  factory BusinessCard.fromJson(Json j) => BusinessCard(
    id: asInt(j['id']),
    username: asString(j['username']),
    name: asString(j['name']),
    avatarUrl: asString(j['avatarUrl']),
    isBusiness: j['isBusiness'] == null ? true : asBool(j['isBusiness']),
    verified: asBool(j['verified']),
    category: asString(j['category']),
    city: asString(j['city']),
    rating: asDouble(j['rating']),
    reviewsCount: asInt(j['reviewsCount']),
    followersCount: asInt(j['followersCount']),
    productsCount: asInt(j['productsCount']),
    hasStory: asBool(j['hasStory']),
    covers: asList(j['covers'], asString),
    isFollowing: asBool(j['isFollowing']),
  );

  final String city;
  final double rating;
  final int reviewsCount;
  final int followersCount;
  final int productsCount;
  final bool hasStory;

  /// Up to 4 product image URLs.
  final List<String> covers;

  /// The viewer follows this shop.
  final bool isFollowing;
}

/// Stats period for the Top 10 and the business dashboard.
enum StatsPeriod {
  week('week'),
  month('month'),
  all('all');

  const StatsPeriod(this.value);
  final String value;
}

/// One place of `GET /top`.
class TopEntry {
  const TopEntry({
    required this.rank,
    required this.business,
    this.score = 0,
    this.views = 0,
    this.likes = 0,
    this.orders = 0,
    this.moreCount = 0,
  });

  factory TopEntry.fromJson(Json j) => TopEntry(
    rank: asInt(j['rank']),
    business: BusinessCard.fromJson(asJson(j['business'])),
    score: asInt(j['score']),
    views: asInt(j['views']),
    likes: asInt(j['likes']),
    orders: asInt(j['orders']),
    moreCount: asInt(j['moreCount']),
  );

  /// 1..10
  final int rank;
  final BusinessCard business;

  /// 0..100 "Umumy bal".
  final int score;
  final int views;
  final int likes;
  final int orders;

  /// Products not shown in the covers ("+5").
  final int moreCount;
}

/// `GET /business/stats`.
class BusinessStats {
  const BusinessStats({
    this.views = 0,
    this.likes = 0,
    this.orders = 0,
    this.revenue = 0,
    this.pendingOrders = 0,
    this.rating = 0,
    this.reviewsCount = 0,
    this.productsCount = 0,
    this.followersCount = 0,
  });

  factory BusinessStats.fromJson(Json j) => BusinessStats(
    views: asInt(j['views']),
    likes: asInt(j['likes']),
    orders: asInt(j['orders']),
    revenue: asInt(j['revenue']),
    pendingOrders: asInt(j['pendingOrders']),
    rating: asDouble(j['rating']),
    reviewsCount: asInt(j['reviewsCount']),
    productsCount: asInt(j['productsCount']),
    followersCount: asInt(j['followersCount']),
  );

  final int views;
  final int likes;
  final int orders;

  /// TMT
  final int revenue;
  final int pendingOrders;
  final double rating;
  final int reviewsCount;
  final int productsCount;
  final int followersCount;
}
