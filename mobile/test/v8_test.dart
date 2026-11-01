import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:modahouse/core/api_client.dart';
import 'package:modahouse/core/snack.dart';
import 'package:modahouse/core/theme.dart';
import 'package:modahouse/core/token_storage.dart';
import 'package:modahouse/data/auth_repository.dart';
import 'package:modahouse/data/business_repository.dart';
import 'package:modahouse/data/coins_repository.dart';
import 'package:modahouse/data/contests_repository.dart';
import 'package:modahouse/data/pins_repository.dart';
import 'package:modahouse/l10n/strings.dart';
import 'package:modahouse/models/models.dart';
import 'package:modahouse/screens/coins_screen.dart';
import 'package:modahouse/screens/contests_screens.dart';
import 'package:modahouse/screens/top_screen.dart';
import 'package:modahouse/state/pin_updates.dart';
import 'package:modahouse/state/providers.dart';
import 'package:modahouse/widgets/boost_sheet.dart';
import 'package:modahouse/widgets/pin_card.dart';
import 'package:modahouse/widgets/promo_ui.dart';

/// Answers by "METHOD /path" with JSON (or `(status, body)`), recording
/// every request.
class _Net implements HttpClientAdapter {
  _Net(this.routes);

  final Map<String, Object?> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method} ${options.uri.path}';
    if (!routes.containsKey(key)) {
      return ResponseBody.fromString('{"error":"nope"}', 404);
    }
    var body = routes[key];
    var status = body == null ? 204 : 200;
    if (body is (int, Object?)) {
      status = body.$1;
      body = body.$2;
    }
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  Iterable<RequestOptions> sent(String method, String path) =>
      requests.where((r) => r.method == method && r.uri.path == path);
}

ApiClient _client(_Net net) => ApiClient(
  dio: Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = net,
  token: () => 't',
);

Map<String, Object?> _pinJson(
  int id, {
  int authorId = 2,
  String category = 'toy',
  bool promoted = false,
}) => {
  'id': id,
  'title': 'Köýnek $id',
  'category': category,
  'imageUrl': '/uploads/$id.jpg',
  'width': 300,
  'height': 400,
  'author': {'id': authorId, 'username': 'u$authorId', 'name': 'U$authorId'},
  'promoted': ?(promoted ? true : null),
};

const _coins = {
  'balance': 40,
  'rate': '1',
  'paymentInfo': 'Halkbank kart: 9934 0000 1111 2222 (A. Aman)',
  'packages': [
    {'coins': 50, 'price': '50'},
    {'coins': 100, 'price': '100'},
  ],
  'boostOptions': [
    {'days': 1, 'coins': 10},
    {'days': 3, 'coins': 25},
    {'days': 7, 'coins': 50},
    {'days': 30, 'coins': 150},
  ],
  'history': [
    {
      'id': 3,
      'amount': -10,
      'kind': 'boost',
      'note': '1 gün öňe çykarmak',
      'pinId': 7,
      'createdAt': '2026-10-30T10:00:00Z',
    },
    {
      'id': 2,
      'amount': 50,
      'kind': 'topup',
      'note': '',
      'pinId': null,
      'createdAt': '2026-10-29T10:00:00Z',
    },
  ],
  'requests': [
    {
      'id': 9,
      'user': {'id': 1, 'username': 'me', 'name': 'Me'},
      'coins': 100,
      'price': '100',
      'note': '+99365',
      'status': 'pending',
      'createdAt': '2026-10-31T09:00:00Z',
      'decidedAt': null,
    },
  ],
};

Map<String, Object?> _contestJson({
  String status = 'active',
  int? myVote,
  int? myEntry,
  Object? winner,
  String category = '',
}) => {
  'id': 5,
  'title': 'Güýz toý köýnegi',
  'description': 'Iň owadan toý köýnegi',
  'category': category,
  'prize': '500 TMT',
  'prizeCoins': 100,
  'startsAt': '2026-10-25T00:00:00Z',
  'endsAt': '2026-11-10T00:00:00Z',
  'status': status,
  'entriesCount': 2,
  'votesCount': 7,
  'winner': winner,
  'myVotePinId': myVote,
  'myEntryPinId': myEntry,
};

void main() {
  group('v8 models', () {
    test('me coins and pin boost fields', () {
      final me = Me.fromJson({'id': 1, 'username': 'me', 'coins': 75});
      expect(me.coins, 75);
      expect(Me.fromJson({'id': 1, 'username': 'me'}).coins, 0);
      final more = me.withCoins(25);
      expect(more.coins, 25);
      expect(more.username, 'me');
      expect(more.isMe, isTrue);

      final plain = Pin.fromJson(_pinJson(1));
      expect(plain.promoted, isFalse);
      expect(plain.boostedUntil, isNull);
      final boosted = Pin.fromJson({
        ..._pinJson(2, promoted: true),
        'boostedUntil': '2026-11-04T12:00:00Z',
      });
      expect(boosted.promoted, isTrue);
      expect(boosted.boostedUntil, DateTime.utc(2026, 11, 4, 12));
      final copy = boosted.copyWith(likesCount: 3);
      expect(copy.promoted, isTrue);
      expect(copy.boostedUntil, boosted.boostedUntil);
      final later = DateTime.utc(2026, 12);
      expect(plain.copyWith(boostedUntil: later).boostedUntil, later);
    });

    test('coins info parses packages, options, history and requests', () {
      final info = CoinsInfo.fromJson(_coins);
      expect(info.balance, 40);
      expect(info.rate, '1');
      expect(info.paymentInfo, contains('Halkbank'));
      expect(info.packages.map((p) => p.coins), [50, 100]);
      expect(info.packages.first.price, '50');
      expect(info.boostOptions.map((o) => o.days), [1, 3, 7, 30]);
      expect(info.boostOptions[1].coins, 25);
      expect(info.history.first.amount, -10);
      expect(info.history.first.kind, 'boost');
      expect(info.history.first.pinId, 7);
      expect(info.history.last.pinId, isNull);
      final r = info.requests.single;
      expect(r.isPending, isTrue);
      expect(r.user?.username, 'me');
      expect(r.decidedAt, isNull);
      expect(
        CoinRequest.fromJson({'id': 1, 'status': 'rejected'}).status,
        CoinRequestStatus.rejected,
      );
      expect(CoinsInfo.fromJson({}).rate, '1');
      final res = BoostResult.fromJson({
        'boostedUntil': '2026-11-04T12:00:00Z',
        'balance': 15,
      });
      expect(res.balance, 15);
      expect(res.boostedUntil, isNotNull);
    });

    test('contest detail with winner and my vote', () {
      final d = ContestDetail.fromJson({
        'contest': _contestJson(
          status: 'finished',
          myVote: 11,
          winner: {'pin': _pinJson(11), 'votes': 5, 'rank': 1},
        ),
        'entries': [
          {'pin': _pinJson(11), 'votes': 5, 'rank': 1},
          {'pin': _pinJson(12, authorId: 3), 'votes': 2, 'rank': 2},
        ],
      });
      final c = d.contest;
      expect(c.isFinished, isTrue);
      expect(c.prizeCoins, 100);
      expect(c.voted, isTrue);
      expect(c.entered, isFalse);
      expect(c.winner?.pin.id, 11);
      expect(c.winner?.votes, 5);
      expect(d.entries.map((e) => e.rank), [1, 2]);
      expect(contestStatusLabel(c.status), S.contestFinished);
      expect(contestPrizeLine(c), '500 TMT · +100 teňňe');
      final upcoming = Contest.fromJson(_contestJson(status: 'upcoming'));
      expect(upcoming.status, ContestStatus.upcoming);
      expect(upcoming.winner, isNull);
      expect(contestStatusLabel(ContestStatus.active), S.contestActive);
      expect(contestStatusLabel(ContestStatus.upcoming), S.contestUpcoming);
    });
  });

  group('v8 repositories', () {
    test('top sort, boost and promoted', () async {
      final net = _Net({
        'GET /api/top': [],
        'POST /api/pins/7/boost': {
          'boostedUntil': '2026-11-04T12:00:00Z',
          'balance': 15,
        },
        'GET /api/pins/promoted': [_pinJson(7)],
      });
      final client = _client(net);
      final biz = BusinessRepository(client);
      await biz.top();
      expect(net.requests.last.uri.queryParameters['sort'], 'score');
      await biz.top(sort: TopSort.rating, period: StatsPeriod.month);
      expect(net.requests.last.uri.queryParameters['sort'], 'rating');
      expect(net.requests.last.uri.queryParameters['period'], 'month');

      final pins = PinsRepository(client);
      final res = await pins.boost(7, 3);
      expect(net.requests.last.data, {'days': 3});
      expect(res.balance, 15);
      final promoted = await pins.promoted();
      expect(promoted.single.promoted, isTrue);
    });

    test('coins and contests endpoints', () async {
      final net = _Net({
        'GET /api/me/coins': _coins,
        'POST /api/me/coins/requests': (
          201,
          (_coins['requests']! as List).first,
        ),
        'GET /api/contests': [_contestJson()],
        'GET /api/contests/5': {'contest': _contestJson(), 'entries': []},
        'POST /api/contests/5/entries': (201, _contestJson(myEntry: 3)),
        'DELETE /api/contests/5/entries': _contestJson(),
        'POST /api/contests/5/vote': _contestJson(myVote: 4),
      });
      final client = _client(net);
      final coins = CoinsRepository(client);
      expect((await coins.mine()).balance, 40);
      final r = await coins.request(100, note: ' +99365 ');
      expect(net.requests.last.data, {'coins': 100, 'note': '+99365'});
      expect(r.coins, 100);
      await coins.request(50);
      expect(net.requests.last.data, {'coins': 50});

      final contests = ContestsRepository(client);
      await contests.list();
      expect(
        net.requests.last.uri.queryParameters.containsKey('status'),
        isFalse,
      );
      await contests.list(status: ContestStatus.active);
      expect(net.requests.last.uri.queryParameters['status'], 'active');
      expect((await contests.get(5)).contest.id, 5);
      expect((await contests.enter(5, 3)).myEntryPinId, 3);
      expect(net.requests.last.data, {'pinId': 3});
      expect((await contests.leave(5)).entered, isFalse);
      expect(net.requests.last.method, 'DELETE');
      expect((await contests.vote(5, 4)).myVotePinId, 4);
      expect(net.requests.last.data, {'pinId': 4});
    });
  });

  group('v8 widgets', () {
    testWidgets('Top 10 pill: red, bold white text, no icon, opens /top', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                Scaffold(appBar: AppBar(actions: const [Top10Button()])),
          ),
          GoRoute(path: '/top', builder: (_, _) => const Text('top screen')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: router,
        ),
      );
      final pill = find.byKey(const Key('top10-button'));
      expect(pill, findsOneWidget);
      expect(tester.widget<Material>(pill).color, AppPalette.accent);
      final text = tester.widget<Text>(
        find.descendant(of: pill, matching: find.text('Top 10')),
      );
      expect(text.style?.color, Colors.white);
      expect(text.style?.fontWeight, FontWeight.w800);
      expect(
        find.descendant(of: pill, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);
      expect(find.bySemanticsLabel(S.top10Title), findsOneWidget);

      await tester.tap(pill);
      await tester.pumpAndSettle();
      expect(find.text('top screen'), findsOneWidget);
    });

    Widget app(
      _Net net,
      Widget child, {
      bool loggedIn = false,
    }) => ProviderScope(
      overrides: [
        networkImagesProvider.overrideWithValue(false),
        tokenStorageProvider.overrideWithValue(
          MemoryTokenStorage(loggedIn ? 't' : null),
        ),
        authRepositoryProvider.overrideWithValue(AuthRepository(_client(net))),
        pinsRepositoryProvider.overrideWithValue(PinsRepository(_client(net))),
        coinsRepositoryProvider.overrideWithValue(
          CoinsRepository(_client(net)),
        ),
        contestsRepositoryProvider.overrideWithValue(
          ContestsRepository(_client(net)),
        ),
        businessRepositoryProvider.overrideWithValue(
          BusinessRepository(_client(net)),
        ),
        categoriesProvider.overrideWith(
          (ref) async => const [Category(slug: 'toy', name: 'Toý')],
        ),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        scaffoldMessengerKey: rootMessengerKey,
        home: child,
      ),
    );

    testWidgets('Top 10 screen: sort chips, promoted strip, contest banner', (
      tester,
    ) async {
      final net = _Net({
        'GET /api/top': [],
        'GET /api/pins/promoted': [_pinJson(7)],
        'GET /api/contests': [_contestJson()],
      });
      await tester.pumpWidget(app(net, const TopScreen()));
      await tester.pumpAndSettle();
      expect(
        net.sent('GET', '/api/top').last.uri.queryParameters['sort'],
        'score',
      );
      for (final label in [
        S.sortAuto,
        S.sortLikes,
        S.sortViews,
        S.sortOrders,
        S.sortRating,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byKey(const Key('promoted-strip')), findsOneWidget);
      expect(find.text(S.promotedTitle), findsOneWidget);
      expect(find.byKey(const Key('active-contest-banner')), findsOneWidget);
      expect(find.byKey(const Key('contests-button')), findsOneWidget);
      expect(
        net.sent('GET', '/api/contests').last.uri.queryParameters['status'],
        'active',
      );

      await tester.tap(find.text(S.sortLikes));
      await tester.pumpAndSettle();
      expect(
        net.sent('GET', '/api/top').last.uri.queryParameters['sort'],
        'likes',
      );
    });

    testWidgets('promoted strip hides when nothing is boosted', (tester) async {
      final net = _Net({'GET /api/pins/promoted': []});
      await tester.pumpWidget(app(net, const Scaffold(body: PromotedStrip())));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('promoted-strip')), findsNothing);
    });

    testWidgets('promoted label on feed cards', (tester) async {
      await tester.pumpWidget(
        app(
          _Net({}),
          Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PinCard(
                    pin: Pin.fromJson(_pinJson(1, promoted: true)),
                  ),
                ),
                Expanded(child: PinCard(pin: Pin.fromJson(_pinJson(2)))),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('promoted-label')), findsOneWidget);
      expect(find.text(S.promoted), findsOneWidget);
    });

    testWidgets('boost sheet: options as tiles, boost, then 402', (
      tester,
    ) async {
      final net = _Net({
        'GET /api/me/coins': _coins,
        'POST /api/pins/7/boost': {
          'boostedUntil': '2026-11-04T12:00:00Z',
          'balance': 30,
        },
      });
      final pin = Pin.fromJson(_pinJson(7, authorId: 1));
      late WidgetRef ref;
      await tester.pumpWidget(
        app(
          net,
          Consumer(
            builder: (context, r, _) {
              ref = r;
              final current =
                  r.watch(pinUpdatesProvider.select((u) => u.updated[7])) ??
                  pin;
              return Scaffold(body: BoostSection(pin: current));
            },
          ),
        ),
      );
      expect(find.text(S.boostText), findsOneWidget);
      await tester.tap(find.byKey(const Key('boost-button')));
      await tester.pumpAndSettle();
      expect(find.text(S.boostTitle), findsOneWidget);
      expect(find.text(S.coinsCount(40)), findsOneWidget);
      for (final d in [1, 3, 7, 30]) {
        expect(find.byKey(Key('boost-$d')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('boost-1')));
      await tester.pumpAndSettle();
      expect(net.sent('POST', '/api/pins/7/boost').single.data, {'days': 1});
      // The sheet closed and the section shows the end date.
      expect(find.text(S.boostTitle), findsNothing);
      final until = ref.read(pinUpdatesProvider).updated[7]?.boostedUntil;
      expect(until, DateTime.utc(2026, 11, 4, 12));
      expect(find.textContaining('Öňe çykarylan:'), findsOneWidget);
      expect(find.textContaining('çenli'), findsWidgets);

      // Not enough teňňe: the sheet offers "Teňňelerim".
      net.routes['POST /api/pins/7/boost'] = (
        402,
        {'error': 'Teňňe ýeterlik däl: ilki teňňe satyn alyň'},
      );
      await tester.tap(find.byKey(const Key('boost-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('boost-30')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('boost-short')), findsOneWidget);
      expect(find.textContaining('Teňňe ýeterlik däl'), findsOneWidget);
      expect(find.byKey(const Key('boost-buy-coins')), findsOneWidget);
    });

    testWidgets('vote button states', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        app(
          _Net({}),
          Scaffold(
            body: Column(
              children: [
                ContestVoteButton(pinId: 1, onPressed: () => taps++),
                const ContestVoteButton(pinId: 2, onPressed: null),
                const ContestVoteButton(
                  pinId: 3,
                  onPressed: null,
                  isMyVote: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('vote-1')));
      expect(taps, 1);
      final disabled = find.descendant(
        of: find.byKey(const Key('vote-2')),
        matching: find.text(S.vote),
      );
      expect(disabled, findsOneWidget);
      expect(
        tester
            .widget<ButtonStyleButton>(find.byKey(const Key('vote-2')))
            .enabled,
        isFalse,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('vote-3')),
          matching: find.text(S.voted),
        ),
        findsOneWidget,
      );
    });

    testWidgets('contest detail: vote, server error in a snack', (
      tester,
    ) async {
      final net = _Net({
        'GET /api/me': {'id': 1, 'username': 'me', 'name': 'Me'},
        'GET /api/contests/5': {
          'contest': _contestJson(),
          'entries': [
            {'pin': _pinJson(11), 'votes': 5, 'rank': 1},
            {'pin': _pinJson(12, authorId: 1), 'votes': 2, 'rank': 2},
          ],
        },
        'POST /api/contests/5/vote': (
          409,
          {'error': 'Siz bu ýaryşda eýýäm ses berdiňiz: her ulanyja 1 ses'},
        ),
      });
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(net, const ContestDetailScreen(id: 5), loggedIn: true),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.contestActive), findsOneWidget);
      expect(find.textContaining('500 TMT'), findsWidgets);
      expect(find.byKey(const Key('contest-enter')), findsOneWidget);
      // My own post cannot get my vote.
      expect(
        tester
            .widget<ButtonStyleButton>(find.byKey(const Key('vote-12')))
            .enabled,
        isFalse,
      );
      expect(find.text(S.yourEntry), findsOneWidget);

      await tester.tap(find.byKey(const Key('vote-11')));
      await tester.pumpAndSettle();
      expect(find.text(S.voteConfirmTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, S.vote).last);
      await tester.pumpAndSettle();
      expect(net.sent('POST', '/api/contests/5/vote').single.data, {
        'pinId': 11,
      });
      expect(
        find.text('Siz bu ýaryşda eýýäm ses berdiňiz: her ulanyja 1 ses'),
        findsOneWidget,
      );
    });

    testWidgets('finished contest shows the winner, no actions', (
      tester,
    ) async {
      final net = _Net({
        'GET /api/contests/5': {
          'contest': _contestJson(
            status: 'finished',
            winner: {'pin': _pinJson(11), 'votes': 5, 'rank': 1},
          ),
          'entries': [
            {'pin': _pinJson(11), 'votes': 5, 'rank': 1},
          ],
        },
      });
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(net, const ContestDetailScreen(id: 5)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contest-winner')), findsOneWidget);
      expect(find.text(S.contestFinished), findsOneWidget);
      expect(find.byKey(const Key('contest-enter')), findsNothing);
      expect(
        tester
            .widget<ButtonStyleButton>(find.byKey(const Key('vote-11')))
            .enabled,
        isFalse,
      );
    });

    testWidgets('coins screen: payment info, packages, request with note', (
      tester,
    ) async {
      final net = _Net({
        'GET /api/me/coins': _coins,
        'POST /api/me/coins/requests': (
          201,
          (_coins['requests']! as List).first,
        ),
      });
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(net, const CoinsScreen()));
      await tester.pumpAndSettle();
      expect(find.text(S.coinsCount(40)), findsOneWidget);
      expect(find.textContaining('Halkbank'), findsOneWidget);
      expect(find.text(S.coinRequestPending), findsOneWidget);
      expect(find.text('-10'), findsOneWidget);
      expect(find.text('+50'), findsOneWidget);

      await tester.tap(find.byKey(const Key('coin-package-50')));
      await tester.pumpAndSettle();
      expect(find.text(S.buyCoinsTitle(50)), findsOneWidget);
      await tester.enterText(find.byKey(const Key('coin-note')), '+99365');
      await tester.tap(find.byKey(const Key('coin-request-send')));
      await tester.pumpAndSettle();
      expect(net.sent('POST', '/api/me/coins/requests').single.data, {
        'coins': 50,
        'note': '+99365',
      });
      expect(find.text(S.coinRequestSent), findsOneWidget);
    });
  });
}
