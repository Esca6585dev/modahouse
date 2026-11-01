import '../config.dart';
import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

/// Fields of `POST/PUT /me/business`.
class BusinessInput {
  const BusinessInput({
    this.category,
    this.phone,
    this.address,
    this.city,
    this.instagram,
    this.workingHours,
    this.deliveryDays,
    this.returnDays,
    this.tiktok,
    this.telegram,
    this.whatsapp,
    this.imo,
    this.youtube,
    this.website,
  });

  final String? category;
  final String? tiktok;
  final String? telegram;
  final String? whatsapp;
  final String? imo;
  final String? youtube;
  final String? website;
  final String? phone;
  final String? address;
  final String? city;
  final String? instagram;
  final String? workingHours;
  final int? deliveryDays;
  final int? returnDays;

  Json toJson() => {
    'category': ?category,
    'phone': ?phone,
    'address': ?address,
    'city': ?city,
    'instagram': ?instagram,
    'workingHours': ?workingHours,
    'deliveryDays': ?deliveryDays,
    'returnDays': ?returnDays,
    'tiktok': ?tiktok,
    'telegram': ?telegram,
    'whatsapp': ?whatsapp,
    'imo': ?imo,
    'youtube': ?youtube,
    'website': ?website,
  };
}

class BusinessRepository {
  BusinessRepository(this._api);
  final ApiClient _api;

  /// Switches the current account to a business account.
  Future<Me> open(BusinessInput input) async => Me.fromJson(
    parseJson(await _api.post('/me/business', data: input.toJson())),
  );

  Future<Me> update(BusinessInput input) async => Me.fromJson(
    parseJson(await _api.put('/me/business', data: input.toJson())),
  );

  /// Back to a personal account (products stop being products).
  Future<Me> close() async =>
      Me.fromJson(parseJson(await _api.delete('/me/business')));

  Future<BusinessStats> stats(StatsPeriod period) async =>
      BusinessStats.fromJson(
        parseJson(
          await _api.get('/business/stats', query: {'period': period.value}),
        ),
      );

  /// Shops directory.
  Future<Page<BusinessCard>> list({
    String? q,
    String? category,
    int page = 1,
    int limit = AppConfig.pageSize,
  }) async => Page.fromJson(
    parseJson(
      await _api.get(
        '/businesses',
        query: {
          'q': q?.trim(),
          'category': category,
          'page': page,
          'limit': limit,
        },
      ),
    ),
    BusinessCard.fromJson,
  );

  /// Masters directory (`GET /masters`): every profile with a craft,
  /// personal or business.
  Future<Page<BusinessCard>> masters({
    String? q,
    String? category,
    int page = 1,
    int limit = AppConfig.pageSize,
  }) async => Page.fromJson(
    parseJson(
      await _api.get(
        '/masters',
        query: {
          'q': q?.trim(),
          'category': category,
          'page': page,
          'limit': limit,
        },
      ),
    ),
    BusinessCard.fromJson,
  );

  /// `GET /profile-categories`: crafts any profile may show.
  Future<List<Category>> profileCategories() async =>
      parseList(await _api.get('/profile-categories'), Category.fromJson);

  /// `GET /business-categories`.
  Future<List<Category>> categories() async =>
      parseList(await _api.get('/business-categories'), Category.fromJson);

  /// Top 10 ranking.
  Future<List<TopEntry>> top({
    StatsPeriod period = StatsPeriod.week,
    TopSort sort = TopSort.score,
    String? category,
    int limit = 10,
  }) async => parseList(
    await _api.get(
      '/top',
      query: {
        'period': period.value,
        'sort': sort.value,
        'category': category,
        'limit': limit,
      },
    ),
    TopEntry.fromJson,
  );
}
