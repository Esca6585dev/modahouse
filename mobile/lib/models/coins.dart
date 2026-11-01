import 'json.dart';
import 'user.dart';

/// A teňňe package offered in `GET /me/coins` (price in manat).
class CoinPackage {
  const CoinPackage({required this.coins, this.price = ''});

  factory CoinPackage.fromJson(Json j) =>
      CoinPackage(coins: asInt(j['coins']), price: asString(j['price']));

  final int coins;

  /// Manat, as the server formats it (e.g. `"50"` or `"12.5"`).
  final String price;
}

/// How long a post can be boosted and what it costs.
class BoostOption {
  const BoostOption({required this.days, required this.coins});

  factory BoostOption.fromJson(Json j) =>
      BoostOption(days: asInt(j['days']), coins: asInt(j['coins']));

  final int days;
  final int coins;
}

/// One line of the teňňe history.
class CoinTx {
  const CoinTx({
    required this.id,
    required this.amount,
    this.kind = '',
    this.note = '',
    this.pinId,
    this.createdAt,
  });

  factory CoinTx.fromJson(Json j) => CoinTx(
    id: asInt(j['id']),
    amount: asInt(j['amount']),
    kind: asString(j['kind']),
    note: asString(j['note']),
    pinId: asIntOrNull(j['pinId']),
    createdAt: asDate(j['createdAt']),
  );

  final int id;

  /// Positive = added, negative = spent.
  final int amount;

  /// `topup`, `boost`, `prize` or `admin`.
  final String kind;
  final String note;
  final int? pinId;
  final DateTime? createdAt;
}

enum CoinRequestStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const CoinRequestStatus(this.value);
  final String value;

  static CoinRequestStatus parse(String v) => values.firstWhere(
    (s) => s.value == v,
    orElse: () => CoinRequestStatus.pending,
  );
}

/// "I paid, add my teňňe" request, approved by an admin.
class CoinRequest {
  const CoinRequest({
    required this.id,
    required this.coins,
    this.user,
    this.price = '',
    this.note = '',
    this.status = CoinRequestStatus.pending,
    this.createdAt,
    this.decidedAt,
  });

  factory CoinRequest.fromJson(Json j) => CoinRequest(
    id: asInt(j['id']),
    user: j['user'] is Map ? UserBrief.fromJson(asJson(j['user'])) : null,
    coins: asInt(j['coins']),
    price: asString(j['price']),
    note: asString(j['note']),
    status: CoinRequestStatus.parse(asString(j['status'])),
    createdAt: asDate(j['createdAt']),
    decidedAt: asDate(j['decidedAt']),
  );

  final int id;
  final UserBrief? user;
  final int coins;
  final String price;
  final String note;
  final CoinRequestStatus status;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  bool get isPending => status == CoinRequestStatus.pending;
}

/// `GET /me/coins`.
class CoinsInfo {
  const CoinsInfo({
    this.balance = 0,
    this.rate = '1',
    this.paymentInfo = '',
    this.packages = const [],
    this.boostOptions = const [],
    this.history = const [],
    this.requests = const [],
  });

  factory CoinsInfo.fromJson(Json j) => CoinsInfo(
    balance: asInt(j['balance']),
    rate: asString(j['rate']).isEmpty ? '1' : asString(j['rate']),
    paymentInfo: asString(j['paymentInfo']),
    packages: asList(j['packages'], (e) => CoinPackage.fromJson(asJson(e))),
    boostOptions: asList(
      j['boostOptions'],
      (e) => BoostOption.fromJson(asJson(e)),
    ),
    history: asList(j['history'], (e) => CoinTx.fromJson(asJson(e))),
    requests: asList(j['requests'], (e) => CoinRequest.fromJson(asJson(e))),
  );

  final int balance;

  /// Manat for one teňňe.
  final String rate;

  /// How to pay (set by an admin), shown above the packages.
  final String paymentInfo;
  final List<CoinPackage> packages;
  final List<BoostOption> boostOptions;
  final List<CoinTx> history;
  final List<CoinRequest> requests;
}

/// Response of `POST /pins/:id/boost`.
class BoostResult {
  const BoostResult({this.boostedUntil, this.balance = 0});

  factory BoostResult.fromJson(Json j) => BoostResult(
    boostedUntil: asDate(j['boostedUntil']),
    balance: asInt(j['balance']),
  );

  final DateTime? boostedUntil;
  final int balance;
}
