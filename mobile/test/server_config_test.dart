import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modahouse/config.dart';
import 'package:modahouse/core/api_client.dart';
import 'package:modahouse/core/server_config.dart';
import 'package:modahouse/core/snack.dart';
import 'package:modahouse/core/theme.dart';
import 'package:modahouse/core/token_storage.dart';
import 'package:modahouse/data/auth_repository.dart';
import 'package:modahouse/l10n/strings.dart';
import 'package:modahouse/models/models.dart';
import 'package:modahouse/screens/auth_screens.dart';
import 'package:modahouse/screens/server_screen.dart';
import 'package:modahouse/state/providers.dart';
import 'package:modahouse/state/server.dart';

/// A fake network: `url → (status, body)`. Unknown URLs are "unreachable".
class _FakeNet implements HttpClientAdapter {
  _FakeNet(this.routes);

  final Map<String, (int, Object?)> routes;
  final requested = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requested.add(url);
    final r = routes[url];
    if (r == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'unreachable',
      );
    }
    final body = r.$2;
    return ResponseBody.fromString(
      body == null ? '' : (body is String ? body : jsonEncode(body)),
      r.$1,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ServerProbe _probe(_FakeNet net) =>
    ServerProbe(dio: Dio()..httpClientAdapter = net);

const _ok = (200, {'status': 'ok'});

(int, Object?) _config({String apiUrl = '', String webUrl = ''}) => (
  200,
  {
    'apiUrl': apiUrl,
    'webUrl': webUrl,
    'registrationOpen': true,
    'updatedAt': '2026-10-14T10:00:00Z',
  },
);

const _a = 'http://a.test:8080';
const _b = 'https://b.test';
const _def = 'http://default.test:8080';

Future<ServerResolution> _resolve(
  _FakeNet net, {
  String current = _a,
  String? configUrl,
}) => resolveServer(
  probe: _probe(net),
  current: current,
  currentSource: ServerSource.manual,
  buildDefault: _def,
  configUrl: configUrl,
);

void main() {
  tearDown(AppConfig.resetToDefaults);

  group('normalizeServerUrl', () {
    test('trims, drops trailing slashes and /api', () {
      expect(
        normalizeServerUrl('  https://api.modahouse.tm/  '),
        'https://api.modahouse.tm',
      );
      expect(
        normalizeServerUrl('https://api.modahouse.tm/api'),
        'https://api.modahouse.tm',
      );
      expect(
        normalizeServerUrl('https://api.modahouse.tm/api/'),
        'https://api.modahouse.tm',
      );
      expect(
        normalizeServerUrl('HTTP://Host.TM:8080/API//'),
        'http://host.tm:8080',
      );
      expect(
        normalizeServerUrl('http://10.0.2.2:8080'),
        'http://10.0.2.2:8080',
      );
      expect(
        normalizeServerUrl('https://x.tm/modahouse/api'),
        'https://x.tm/modahouse',
      );
      expect(normalizeServerUrl('http://[::1]:8080/'), 'http://[::1]:8080');
    });

    test('keeps /api for web addresses when asked', () {
      expect(
        normalizeServerUrl('https://modahouse.tm/api/', stripApi: false),
        'https://modahouse.tm/api',
      );
    });

    test('rejects addresses that are not absolute http(s) URLs', () {
      for (final bad in [
        null,
        '',
        '   ',
        'api.modahouse.tm',
        '192.168.1.10:8080',
        'ftp://x.tm',
        'https://',
        'http:///path',
        'https://x.tm?a=1',
        'https://x .tm',
        'javascript:alert(1)',
      ]) {
        expect(normalizeServerUrl(bad), isNull, reason: '$bad');
      }
    });
  });

  group('AppConfig', () {
    test('use() switches the API, images and links; reset restores', () {
      AppConfig.use(apiUrl: 'https://new.tm/api/', webUrl: 'https://web.tm/');
      expect(AppConfig.apiUrl, 'https://new.tm');
      expect(AppConfig.apiBase, 'https://new.tm/api');
      expect(resolveImageUrl('/uploads/x.jpg'), 'https://new.tm/uploads/x.jpg');
      expect(AppConfig.pinLink(5), 'https://web.tm/pin/5');
      expect(AppConfig.adminLink, 'https://web.tm/admin');
      // Invalid / empty values: API kept, web back to the build default.
      AppConfig.use(apiUrl: 'nonsense', webUrl: '');
      expect(AppConfig.apiUrl, 'https://new.tm');
      expect(AppConfig.webUrl, AppConfig.defaultWebUrl);
      AppConfig.resetToDefaults();
      expect(AppConfig.apiUrl, 'http://10.0.2.2:8080');
      expect(AppConfig.webUrl, 'https://modahouse.tm');
    });

    test('ApiClient sends requests to the current server', () async {
      final net = _FakeNet({
        '$_a/api/pins': (200, <String, Object?>{}),
        '$_b/api/pins': (200, <String, Object?>{}),
      });
      final client = ApiClient();
      client.dio.httpClientAdapter = net;
      AppConfig.use(apiUrl: _a);
      await client.get('/pins');
      AppConfig.use(apiUrl: _b);
      await client.get('/pins');
      expect(net.requested, ['$_a/api/pins', '$_b/api/pins']);
    });

    test('loadSavedServer applies the saved address', () async {
      final store = MemoryServerStore(
        const SavedServer(
          apiUrl: _b,
          source: ServerSource.remote,
          webUrl: 'https://web.tm',
        ),
      );
      expect(await loadSavedServer(store), ServerSource.remote);
      expect(AppConfig.apiUrl, _b);
      expect(AppConfig.webUrl, 'https://web.tm');
      expect(await loadSavedServer(MemoryServerStore()), ServerSource.build);
    });
  });

  group('resolveServer', () {
    test('switches when the new server answers health ok', () async {
      final net = _FakeNet({
        '$_a/api/config': _config(apiUrl: '$_b/api/', webUrl: 'https://w.tm'),
        '$_b/api/health': _ok,
      });
      final r = await _resolve(net);
      expect(r.apiUrl, _b);
      expect(r.source, ServerSource.remote);
      expect(r.reachable, isTrue);
      expect(r.webUrl, 'https://w.tm');
    });

    test('keeps the current server when the new one is broken', () async {
      final net = _FakeNet({
        '$_a/api/config': _config(apiUrl: 'https://typo.test'),
        // typo.test is unreachable.
      });
      final r = await _resolve(net);
      expect(r.apiUrl, _a);
      expect(r.source, ServerSource.manual);
      expect(r.reachable, isTrue);
      expect(net.requested, contains('https://typo.test/api/health'));
    });

    test(
      'keeps the current server when health is not {"status":"ok"}',
      () async {
        final net = _FakeNet({
          '$_a/api/config': _config(apiUrl: _b),
          '$_b/api/health': (200, {'status': 'down'}),
        });
        expect((await _resolve(net)).apiUrl, _a);
        final net2 = _FakeNet({
          '$_a/api/config': _config(apiUrl: _b),
          '$_b/api/health': (200, '<html>parked domain</html>'),
        });
        expect((await _resolve(net2)).apiUrl, _a);
      },
    );

    test('keeps the current server on empty, same or invalid apiUrl', () async {
      for (final api in ['', _a, '$_a/api', 'not a url']) {
        final net = _FakeNet({
          '$_a/api/config': _config(apiUrl: api),
          '$_a/api/health': _ok,
        });
        final r = await _resolve(net);
        expect(r.apiUrl, _a, reason: api);
        expect(r.reachable, isTrue);
      }
    });

    test('an old server without /config is kept', () async {
      final net = _FakeNet({
        '$_a/api/config': (404, {'error': 'Tapylmady'}),
        '$_a/api/health': _ok,
      });
      final r = await _resolve(net);
      expect(r.apiUrl, _a);
      expect(r.reachable, isTrue);
      expect(r.webUrl, isNull);
    });

    test(
      'falls back to the build default when current is unreachable',
      () async {
        final net = _FakeNet({'$_def/api/config': _config()});
        final r = await _resolve(net);
        expect(r.apiUrl, _def);
        expect(r.source, ServerSource.build);
        expect(r.reachable, isTrue);
      },
    );

    test('the build default can point to the new server', () async {
      final net = _FakeNet({
        '$_def/api/config': _config(apiUrl: _b),
        '$_b/api/health': _ok,
      });
      final r = await _resolve(net);
      expect(r.apiUrl, _b);
      expect(r.source, ServerSource.remote);
    });

    test('then tries the CONFIG_URL file', () async {
      const file = 'https://cdn.test/modahouse.json';
      final net = _FakeNet({
        file: (200, jsonEncode({'apiUrl': '$_b/', 'webUrl': ''})),
        '$_b/api/health': _ok,
      });
      final r = await _resolve(net, configUrl: file);
      expect(r.apiUrl, _b);
      expect(r.source, ServerSource.remote);
    });

    test('CONFIG_URL pointing to a dead server is ignored', () async {
      const file = 'https://cdn.test/modahouse.json';
      final net = _FakeNet({
        file: (200, {'apiUrl': 'https://dead.test'}),
      });
      final r = await _resolve(net, configUrl: file);
      expect(r.apiUrl, _a);
      expect(r.reachable, isFalse);
    });

    test('nothing reachable: stay where we are', () async {
      final r = await _resolve(_FakeNet({}));
      expect(r.apiUrl, _a);
      expect(r.source, ServerSource.manual);
      expect(r.reachable, isFalse);
    });
  });

  group('ServerNotifier', () {
    ProviderContainer container(_FakeNet net, MemoryServerStore store) {
      final c = ProviderContainer(
        overrides: [
          serverProbeProvider.overrideWithValue(_probe(net)),
          serverStoreProvider.overrideWithValue(store),
          tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('refresh switches, saves and rebuilds the API client', () async {
      final def = AppConfig.defaultApiUrl;
      final net = _FakeNet({
        '$def/api/config': _config(apiUrl: _b, webUrl: 'https://w.tm'),
        '$_b/api/health': _ok,
      });
      final store = MemoryServerStore();
      final c = container(net, store);
      final client = c.read(apiClientProvider);
      expect(
        await c.read(serverProvider.notifier).refresh(),
        RefreshResult.switched,
      );
      final s = c.read(serverProvider);
      expect(s.apiUrl, _b);
      expect(s.source, ServerSource.remote);
      expect(s.webUrl, 'https://w.tm');
      expect(s.reachable, isTrue);
      expect(AppConfig.apiUrl, _b);
      expect(AppConfig.pinLink(1), 'https://w.tm/pin/1');
      expect(store.saved?.apiUrl, _b);
      expect(store.saved?.webUrl, 'https://w.tm');
      expect(c.read(apiClientProvider), isNot(same(client)));
    });

    test('refresh is throttled on resume', () async {
      final def = AppConfig.defaultApiUrl;
      final net = _FakeNet({'$def/api/config': _config()});
      final c = container(net, MemoryServerStore());
      final n = c.read(serverProvider.notifier);
      expect(await n.refresh(), RefreshResult.unchanged);
      expect(await n.refresh(force: false), RefreshResult.skipped);
      expect(net.requested, ['$def/api/config']);
    });

    test('setManual validates, checks health and saves', () async {
      final net = _FakeNet({'$_a/api/health': _ok});
      final store = MemoryServerStore();
      final c = container(net, store);
      final n = c.read(serverProvider.notifier);
      expect(await n.setManual(' '), S.serverUrlRequired);
      expect(await n.setManual('a.test'), S.serverUrlInvalid);
      expect(await n.setManual('https://dead.test'), S.serverUnreachable);
      expect(c.read(serverProvider).apiUrl, AppConfig.defaultApiUrl);
      expect(await n.setManual('$_a/api/'), isNull);
      expect(c.read(serverProvider).apiUrl, _a);
      expect(c.read(serverProvider).source, ServerSource.manual);
      expect(store.saved?.source, ServerSource.manual);
      await n.resetToDefault();
      expect(c.read(serverProvider).apiUrl, AppConfig.defaultApiUrl);
      expect(c.read(serverProvider).source, ServerSource.build);
      expect(store.saved, isNull);
    });
  });

  test('Me.isAdmin', () {
    expect(Me.fromJson({'id': 1, 'username': 'a'}).isAdmin, isFalse);
    expect(
      Me.fromJson({'id': 1, 'username': 'a', 'isAdmin': true}).isAdmin,
      isTrue,
    );
    final res = AuthResponse.fromJson({
      'token': 't',
      'user': {'id': 2, 'username': 'b', 'isAdmin': true, 'email': 'b@x.tm'},
    });
    expect(res.user.isAdmin, isTrue);
  });

  group('widgets', () {
    Widget app(Widget child, List overrides) => ProviderScope(
      overrides: [
        networkImagesProvider.overrideWithValue(false),
        tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        scaffoldMessengerKey: rootMessengerKey,
        home: child,
      ),
    );

    testWidgets('Serwer screen: current address, errors, save and reset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final net = _FakeNet({'$_a/api/health': _ok});
      final store = MemoryServerStore();
      await tester.pumpWidget(
        app(const ServerScreen(), [
          serverProbeProvider.overrideWithValue(_probe(net)),
          serverStoreProvider.overrideWithValue(store),
        ]),
      );
      Future<void> tap(String key) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
      }

      String current() => tester
          .widget<SelectableText>(find.byKey(const Key('server-current')))
          .data!;
      expect(current(), AppConfig.defaultApiUrl);
      expect(find.text(S.serverSourceBuild), findsWidgets);
      expect(find.text(S.serverStatusUnknown), findsOneWidget);

      // Not a URL.
      await tester.enterText(find.byKey(const Key('server-field')), 'a.test');
      await tap('server-save');
      await tester.pumpAndSettle();
      expect(find.text(S.serverUrlInvalid), findsOneWidget);

      // Unreachable.
      await tester.enterText(
        find.byKey(const Key('server-field')),
        'https://dead.test',
      );
      await tap('server-save');
      await tester.pumpAndSettle();
      expect(find.text(S.serverUnreachable), findsOneWidget);
      expect(current(), AppConfig.defaultApiUrl);

      // Works.
      await tester.enterText(find.byKey(const Key('server-field')), '$_a/');
      await tap('server-save');
      await tester.pump();
      // Buttons are disabled while checking.
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('server-save')))
            .onPressed,
        isNull,
      );
      await tester.pumpAndSettle();
      expect(find.text(S.serverUnreachable), findsNothing);
      expect(find.text(S.serverSaved), findsOneWidget);
      expect(current(), _a);
      expect(find.text(S.serverSourceManual), findsOneWidget);
      expect(store.saved?.apiUrl, _a);

      // Back to the default.
      await tap('server-reset');
      await tester.pumpAndSettle();
      expect(current(), AppConfig.defaultApiUrl);
      expect(store.saved, isNull);
    });

    testWidgets('Täzeden barla reports an unreachable server', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(const ServerScreen(), [
          serverProbeProvider.overrideWithValue(_probe(_FakeNet({}))),
          serverStoreProvider.overrideWithValue(MemoryServerStore()),
        ]),
      );
      await tester.tap(find.byKey(const Key('server-recheck')));
      await tester.pumpAndSettle();
      expect(find.text(S.serverOffline), findsOneWidget);
      expect(find.text(S.serverStatusDown), findsOneWidget);
    });

    testWidgets(
      'register shows the server message when registration is closed',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);
        const closed = 'Täze hasaba alyş wagtlaýyn ýapyk';
        final dio = Dio(BaseOptions(baseUrl: 'http://x.test/api'))
          ..httpClientAdapter = _FakeNet({
            'http://x.test/api/auth/register': (403, {'error': closed}),
          });
        await tester.pumpWidget(
          app(const RegisterScreen(), [
            authRepositoryProvider.overrideWithValue(
              AuthRepository(ApiClient(dio: dio)),
            ),
          ]),
        );
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Aýna');
        await tester.enterText(fields.at(1), 'ayna.tm');
        await tester.enterText(fields.at(2), 'ayna@modahouse.tm');
        await tester.enterText(fields.at(3), 'modahouse123');
        await tester.tap(find.widgetWithText(FilledButton, S.register));
        await tester.pumpAndSettle();
        expect(find.text(closed), findsOneWidget);
      },
    );
  });
}
