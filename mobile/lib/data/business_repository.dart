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
  });

  final BusinessCategory? category;
  final String? phone;
  final String? address;
  final String? city;
  final String? instagram;
  final String? workingHours;
  final int? deliveryDays;
  final int? returnDays;

  Json toJson() => {
    'category': ?category?.value,
    'phone': ?phone,
    'address': ?address,
    'city': ?city,
    'instagram': ?instagram,
    'workingHours': ?workingHours,
    'deliveryDays': ?deliveryDays,
    'returnDays': ?returnDays,
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
    BusinessCategory? category,
    int page = 1,
    int limit = AppConfig.pageSize,
  }) async => Page.fromJson(
    parseJson(
      await _api.get(
        '/businesses',
        query: {
          'q': q?.trim(),
          'category': category?.value,
          'page': page,
          'limit': limit,
        },
      ),
    ),
    BusinessCard.fromJson,
  );

  /// Top 10 ranking.
  Future<List<TopEntry>> top({
    StatsPeriod period = StatsPeriod.week,
    BusinessCategory? category,
    int limit = 10,
  }) async => parseList(
    await _api.get(
      '/top',
      query: {
        'period': period.value,
        'category': category?.value,
        'limit': limit,
      },
    ),
    TopEntry.fromJson,
  );
}
