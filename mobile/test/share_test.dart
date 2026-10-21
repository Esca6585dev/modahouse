import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:modahouse/config.dart';
import 'package:modahouse/core/share_links.dart';
import 'package:modahouse/core/snack.dart';
import 'package:modahouse/core/theme.dart';
import 'package:modahouse/core/token_storage.dart';
import 'package:modahouse/l10n/strings.dart';
import 'package:modahouse/models/models.dart';
import 'package:modahouse/state/providers.dart';
import 'package:modahouse/widgets/pin_menu.dart';
import 'package:modahouse/widgets/share_sheet.dart';

final _pin = Pin.fromJson({
  'id': 42,
  'title': 'Toý köýnegi',
  'imageUrl': '/uploads/a.jpg',
  'width': 600,
  'height': 800,
  'color': '#f2d0b6',
  'images': [
    {'url': '/uploads/a.jpg', 'width': 600, 'height': 800},
    {'url': '/uploads/b.jpg', 'width': 600, 'height': 800},
  ],
  'author': {'id': 3, 'username': 'ak.gelin', 'name': 'Ak Gelin'},
});

/// A 1×1 transparent PNG (stands in for the JPEG share card).
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// The card skeleton shimmers forever, so pumpAndSettle would never return.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('URL builders', () {
    setUp(
      () => AppConfig.use(
        apiUrl: 'https://api.moda.tm/',
        webUrl: 'https://moda.tm',
      ),
    );
    tearDown(AppConfig.resetToDefaults);

    test('download URL carries the media index', () {
      expect(
        AppConfig.pinDownloadUrl(42),
        'https://api.moda.tm/api/pins/42/download?index=0',
      );
      expect(
        AppConfig.pinDownloadUrl(42, index: 2),
        'https://api.moda.tm/api/pins/42/download?index=2',
      );
      expect(
        AppConfig.pinDownloadUrl(42, index: -1),
        'https://api.moda.tm/api/pins/42/download?index=0',
      );
    });

    test('share card URL follows the current server', () {
      expect(
        AppConfig.pinShareCardUrl(42),
        'https://api.moda.tm/api/pins/42/share-card',
      );
      AppConfig.use(apiUrl: 'http://10.0.0.5:8092');
      expect(
        AppConfig.pinShareCardUrl(7),
        'http://10.0.0.5:8092/api/pins/7/share-card',
      );
    });

    test('WhatsApp and Telegram share links', () {
      final link = AppConfig.pinLink(42);
      expect(link, 'https://moda.tm/pin/42');
      expect(
        whatsappShareUri(link, text: 'Toý köýnegi').toString(),
        'https://wa.me/?text=To%C3%BD%20k%C3%B6%C3%BDnegi%0A'
        'https%3A%2F%2Fmoda.tm%2Fpin%2F42',
      );
      expect(
        whatsappShareUri(link).queryParameters['text'],
        'https://moda.tm/pin/42',
      );
      final tg = telegramShareUri(link, text: 'Toý köýnegi & ak');
      expect(tg.host, 't.me');
      expect(tg.path, '/share/url');
      expect(tg.queryParameters['url'], 'https://moda.tm/pin/42');
      expect(tg.queryParameters['text'], 'Toý köýnegi & ak');
      expect(
        telegramShareUri(link).toString(),
        'https://t.me/share/url?url=https%3A%2F%2Fmoda.tm%2Fpin%2F42',
      );
      expect(pinShareText(_pin), 'Toý köýnegi\nhttps://moda.tm/pin/42');
    });

    test('file names', () {
      expect(pinDownloadFileName(42, 1, 'image/jpeg'), 'modahouse-42-1.jpg');
      expect(
        pinDownloadFileName(42, 0, 'video/mp4; codecs=avc1'),
        'modahouse-42-0.mp4',
      );
      expect(pinDownloadFileName(5, 0, ''), 'modahouse-5-0.jpg');
      expect(pinShareCardFileName(42), 'modahouse-42-card.jpg');
    });
  });

  group('ShareSheet', () {
    late List<String> requested;
    late Completer<FetchedMedia> card;
    late List<String> clipboard;

    setUp(() {
      AppConfig.use(apiUrl: 'https://api.moda.tm', webUrl: 'https://moda.tm');
      requested = [];
      clipboard = [];
    });
    tearDown(AppConfig.resetToDefaults);

    Future<void> pump(WidgetTester tester, Widget home) async {
      // Created inside the test's fake-async zone so completing it is seen.
      card = Completer();
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkImagesProvider.overrideWithValue(false),
            tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
            mediaLoaderProvider.overrideWithValue((url) {
              requested.add(url);
              if (url.contains('/share-card')) return card.future;
              return Future.value(FetchedMedia(_png, 'image/png'));
            }),
          ],
          child: MaterialApp.router(
            scaffoldMessengerKey: rootMessengerKey,
            theme: buildTheme(Brightness.light),
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => Scaffold(body: home),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('shows the card preview and every share target', (
      tester,
    ) async {
      await pump(tester, ShareSheet(pin: _pin));
      // The preview asks for the branded card of this post.
      expect(requested, ['https://api.moda.tm/api/pins/42/share-card']);
      expect(
        ShareSheet(pin: Pin.fromJson({'id': 9})).cardUrl,
        'https://api.moda.tm/api/pins/9/share-card',
      );
      expect(
        find.byKey(
          const ValueKey(
            'share-card:https://api.moda.tm/api/pins/42/share-card',
          ),
        ),
        findsOneWidget,
      );
      // Shimmer while the server renders the card.
      expect(find.bySemanticsLabel(S.shareCardLoading), findsOneWidget);
      expect(find.byKey(const Key('share-card-image')), findsNothing);

      card.complete(FetchedMedia(_png, 'image/jpeg'));
      await _settle(tester);
      expect(find.byKey(const Key('share-card-image')), findsOneWidget);
      expect(find.bySemanticsLabel(S.shareCardLoading), findsNothing);

      expect(find.text(S.shareSheetTitle), findsOneWidget);
      for (final t in ShareTarget.values) {
        expect(find.byKey(Key('share-${t.name}')), findsOneWidget);
      }
      for (final label in [
        S.menuCopyLink,
        S.whatsapp,
        S.telegram,
        S.instagram,
        S.shareWithImage,
        S.menuDownload,
        S.shareMore,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('error state offers a retry', (tester) async {
      await pump(tester, ShareSheet(pin: _pin));
      card.completeError(Exception('500'));
      await _settle(tester);
      expect(find.text(S.shareCardFailed), findsOneWidget);
      card = Completer()..complete(FetchedMedia(_png, 'image/jpeg'));
      await tester.tap(find.text(S.retry));
      await _settle(tester);
      expect(requested.length, 2);
      expect(find.byKey(const Key('share-card-image')), findsOneWidget);
    });

    testWidgets('copy link closes the sheet and copies the post link', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showShareSheet(context, _pin),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(find.byType(ShareSheet), findsOneWidget);
      await tester.tap(find.byKey(const Key('share-copy')));
      await _settle(tester);
      expect(find.byType(ShareSheet), findsNothing);
      expect(clipboard, ['https://moda.tm/pin/42']);
      expect(find.text(S.linkCopied), findsOneWidget);
    });

    testWidgets('⋯ → Ýükle downloads the watermarked carousel item', (
      tester,
    ) async {
      await pump(
        tester,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showPinMenu(context, ref, _pin, index: 1),
            child: const Text('menu'),
          ),
        ),
      );
      await tester.tap(find.text('menu'));
      await _settle(tester);
      await tester.tap(find.text(S.menuDownload));
      await _settle(tester);
      expect(requested, ['https://api.moda.tm/api/pins/42/download?index=1']);
    });

    testWidgets('⋯ → Paýlaş opens the share sheet', (tester) async {
      await pump(
        tester,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showPinMenu(context, ref, _pin),
            child: const Text('menu'),
          ),
        ),
      );
      await tester.tap(find.text('menu'));
      await _settle(tester);
      await tester.tap(find.text(S.menuShare));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ShareSheet), findsOneWidget);
      expect(requested, ['https://api.moda.tm/api/pins/42/share-card']);
    });
  });
}
