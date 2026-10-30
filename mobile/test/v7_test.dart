import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:modahouse/core/api_client.dart';
import 'package:modahouse/core/theme.dart';
import 'package:modahouse/core/token_storage.dart';
import 'package:modahouse/data/auth_repository.dart';
import 'package:modahouse/data/business_repository.dart';
import 'package:modahouse/data/pins_repository.dart';
import 'package:modahouse/data/users_repository.dart';
import 'package:modahouse/l10n/strings.dart';
import 'package:modahouse/models/models.dart';
import 'package:modahouse/screens/interests_screen.dart';
import 'package:modahouse/screens/settings_screen.dart';
import 'package:modahouse/state/interests.dart';
import 'package:modahouse/state/providers.dart';
import 'package:modahouse/widgets/shop_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers by path with JSON, recording every request.
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
    final body = routes[key];
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      body == null ? 204 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_Net net) => ApiClient(
  dio: Dio(BaseOptions(baseUrl: 'http://test/api'))..httpClientAdapter = net,
  token: () => 't',
);

const _crafts = [
  Category(slug: 'tailor', name: 'Tikinçi'),
  Category(slug: 'lashes', name: 'Kirpikçi'),
];

class _MemoryPrompt extends InterestsPromptStore {
  _MemoryPrompt(this.shown);
  bool shown;

  @override
  Future<bool> wasShown(int userId) async => shown;
}

void main() {
  group('v7 models', () {
    test('category on brief, profile, me and business card', () {
      final brief = UserBrief.fromJson({
        'id': 1,
        'username': 'a',
        'name': 'A',
        'category': 'lashes',
      });
      expect(brief.category, 'lashes');
      expect(UserBrief.fromJson({'id': 1, 'username': 'a'}).category, '');
      final me = Me.fromJson({
        'id': 2,
        'username': 'me',
        'name': 'Me',
        'category': 'tailor',
        'email': 'me@x.tm',
      });
      expect(me.category, 'tailor');
      expect(me.copyWith(isFollowing: true).category, 'tailor');
      final card = BusinessCard.fromJson({
        'id': 3,
        'username': 'n',
        'isBusiness': false,
        'category': 'nails',
      });
      expect(card.category, 'nails');
      expect(card.isBusiness, isFalse);
    });

    test('interests parse', () {
      final i = Interests.fromJson({
        'items': [
          {'kind': 'category', 'key': 'toy', 'name': 'Toý', 'score': 12.5},
          {'kind': 'tag', 'key': 'kürte', 'name': 'kürte', 'score': 3},
        ],
        'picked': true,
      });
      expect(i.picked, isTrue);
      expect(i.items, hasLength(2));
      expect(i.items.first.score, 12.5);
      expect(i.items.last.isTag, isTrue);
      expect(Interests.fromJson({}).picked, isFalse);
    });
  });

  group('v7 repositories', () {
    test('home feed asks for feed=foryou', () async {
      final net = _Net({
        'GET /api/pins': {'items': [], 'page': 1, 'limit': 24},
      });
      final repo = PinsRepository(_client(net));
      await repo.list(forYou: true);
      expect(net.requests.last.uri.queryParameters['feed'], 'foryou');
      await repo.list(following: true, forYou: true);
      expect(net.requests.last.uri.queryParameters['feed'], 'following');
      await repo.list();
      expect(net.requests.last.uri.queryParameters.containsKey('feed'), false);
    });

    test('interests, craft and masters endpoints', () async {
      final net = _Net({
        'GET /api/me/interests': {'items': [], 'picked': false},
        'PUT /api/me/interests': {
          'items': [
            {'kind': 'category', 'key': 'toy', 'name': 'Toý', 'score': 12},
          ],
          'picked': true,
        },
        'DELETE /api/me/interests': null,
        'PUT /api/me': {'id': 1, 'username': 'me', 'category': ''},
        'GET /api/masters': {
          'items': [
            {'id': 4, 'username': 'lash', 'category': 'lashes'},
          ],
          'page': 1,
          'limit': 24,
        },
        'GET /api/profile-categories': [
          {'slug': 'tailor', 'name': 'Tikinçi'},
        ],
      });
      final client = _client(net);
      final users = UsersRepository(client);
      expect((await users.interests()).picked, isFalse);
      final picked = await users.pickInterests(['toy']);
      expect(picked.picked, isTrue);
      expect(net.requests.last.data, {
        'categories': ['toy'],
      });
      await users.resetInterests();
      expect(net.requests.last.method, 'DELETE');

      final me = await AuthRepository(client).updateMe(category: '');
      expect(me.category, '');
      expect(net.requests.last.data, {'category': ''});

      final biz = BusinessRepository(client);
      final masters = await biz.masters(category: 'lashes');
      expect(net.requests.last.uri.queryParameters['category'], 'lashes');
      expect(masters.items.single.category, 'lashes');
      expect((await biz.profileCategories()).single.name, 'Tikinçi');
    });

    test('prompt only when never shown and nothing picked', () async {
      final net = _Net({
        'GET /api/me/interests': {'items': [], 'picked': false},
      });
      final users = UsersRepository(_client(net));
      expect(
        await shouldPromptInterests(users, 1, store: _MemoryPrompt(false)),
        isTrue,
      );
      expect(
        await shouldPromptInterests(users, 1, store: _MemoryPrompt(true)),
        isFalse,
      );
      // Offline / old server: never ask.
      final old = UsersRepository(_client(_Net({})));
      expect(
        await shouldPromptInterests(old, 1, store: _MemoryPrompt(false)),
        isFalse,
      );
    });
  });

  group('v7 widgets', () {
    Widget app(Widget child) => ProviderScope(
      overrides: [
        networkImagesProvider.overrideWithValue(false),
        tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        profileCategoriesProvider.overrideWith((ref) async => _crafts),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

    testWidgets('craft picker: "Ýok" for personal accounts only', (
      tester,
    ) async {
      String? picked;
      await tester.pumpWidget(
        app(CraftPicker(value: '', onChanged: (v) => picked = v)),
      );
      await tester.pump();
      expect(find.text(S.craftNone), findsOneWidget);
      expect(find.text('Kirpikçi'), findsOneWidget);
      await tester.tap(find.byKey(const Key('craft-lashes')));
      expect(picked, 'lashes');

      await tester.pumpWidget(
        app(CraftPicker(value: 'tailor', allowNone: false, onChanged: (_) {})),
      );
      await tester.pump();
      expect(find.text(S.craftNone), findsNothing);
      expect(find.text(S.craftBusinessHelp), findsOneWidget);
    });

    testWidgets('craft badge shows the craft name', (tester) async {
      await tester.pumpWidget(app(const CraftBadge(slug: 'lashes')));
      await tester.pump();
      expect(find.text('Kirpikçi'), findsOneWidget);
    });

    testWidgets('interests screen: pick at least one, then save', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final net = _Net({
        'PUT /api/me/interests': {'items': [], 'picked': true},
      });
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          GoRoute(
            path: '/interests',
            builder: (_, _) => const InterestsPickScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
            usersRepositoryProvider.overrideWithValue(
              UsersRepository(_client(net)),
            ),
            categoriesProvider.overrideWith(
              (ref) async => const [
                Category(slug: 'toy', name: 'Toý köýnekleri'),
                Category(slug: 'kurte', name: 'Kürteler'),
              ],
            ),
          ],
          child: MaterialApp.router(
            theme: buildTheme(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      unawaited(router.push('/interests'));
      await tester.pumpAndSettle();
      expect(find.text(S.interestsTitle), findsOneWidget);
      expect(find.text(S.interestsSkip), findsOneWidget);
      final button = find.byKey(const Key('interests-continue'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.tap(find.text('Kürteler'));
      await tester.pump();
      expect(find.text(S.interestsContinue(1)), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(net.requests.single.data, {
        'categories': ['kurte'],
      });
      expect(find.text('home'), findsOneWidget);
    });
  });
}
