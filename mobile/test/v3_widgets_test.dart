import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modahouse/core/theme.dart';
import 'package:modahouse/core/token_storage.dart';
import 'package:modahouse/l10n/strings.dart';
import 'package:modahouse/models/models.dart';
import 'package:modahouse/screens/create_screen.dart';
import 'package:modahouse/state/providers.dart';
import 'package:modahouse/state/shop_state.dart';
import 'package:modahouse/widgets/contact_sheet.dart';
import 'package:modahouse/widgets/pin_card.dart';
import 'package:modahouse/widgets/post_card.dart';
import 'package:modahouse/widgets/shop_ui.dart';
import 'package:modahouse/widgets/video_view.dart';

const _author = {
  'id': 13,
  'username': 'aysoltan.style',
  'name': 'Aýsoltan',
  'avatarUrl': '',
};

class _NoStories extends StoriesNotifier {
  @override
  Future<List<StoryGroup>> build() async => const [];
}

Widget _app(Widget child) => ProviderScope(
  overrides: [
    networkImagesProvider.overrideWithValue(false),
    tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
    storiesProvider.overrideWith(_NoStories.new),
    categoriesProvider.overrideWith(
      (ref) async => const [Category(slug: 'toy', name: 'Toý köýnekleri')],
    ),
  ],
  child: MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('Instagram post: header, likes, caption, comments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final pin = Pin.fromJson({
      'id': 7,
      'title': 'Toý köýnegi',
      'description': 'Täze model #toýköýnek',
      'category': 'toy',
      'imageUrl': '/a.jpg',
      'width': 600,
      'height': 750,
      'author': _author,
      'likesCount': 1234,
      'commentsCount': 5,
      'latestComments': [
        {'id': 1, 'text': 'Örän owadan!', 'author': _author},
      ],
    });
    await tester.pumpWidget(_app(PostCard(pin: pin)));
    await tester.pump();
    expect(find.text('Aýsoltan'), findsOneWidget);
    expect(find.text('Toý köýnekleri'), findsOneWidget);
    expect(find.text(S.likesCount('1 234')), findsOneWidget);
    expect(find.text(S.allComments(5)), findsOneWidget);
    expect(find.byTooltip(S.postOptions), findsOneWidget);
    expect(find.byTooltip(S.like), findsOneWidget);
    expect(find.byTooltip(S.saveAction), findsOneWidget);
    expect(
      find.textContaining('Örän owadan!', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('#toýköýnek', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('video card shows the play badge and the ⋯ button', (
    tester,
  ) async {
    final pin = Pin.fromJson({
      'id': 9,
      'title': 'Reel',
      'imageUrl': '/p.jpg',
      'width': 360,
      'height': 640,
      'author': _author,
      'mediaType': 'video',
      'images': [
        {
          'type': 'video',
          'url': '/v.webm',
          'posterUrl': '/p.jpg',
          'duration': 6.2,
        },
      ],
    });
    await tester.pumpWidget(
      _app(SizedBox(width: 180, child: PinCard(pin: pin))),
    );
    expect(find.byType(VideoBadge), findsOneWidget);
    expect(find.text('0:06'), findsOneWidget);
    expect(find.byTooltip(S.postOptions), findsOneWidget);
  });

  testWidgets('rent and custom prices', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            PriceText(price: 250, listingType: 'rent'),
            PriceText(price: 700, listingType: 'custom'),
          ],
        ),
      ),
    );
    expect(find.text('250 TMT ${S.perDay}'), findsOneWidget);
    expect(find.text(S.priceFromLine('700 TMT')), findsOneWidget);
  });

  testWidgets('listing type selector', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var type = ListingType.sale;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => ListingTypeSelector(
            value: type,
            onChanged: (t) => setState(() => type = t),
          ),
        ),
      ),
    );
    expect(find.text(S.typePost), findsOneWidget);
    expect(find.text(S.typeCustom), findsOneWidget);
    await tester.tap(find.text(S.typeRent));
    await tester.pump();
    expect(type, ListingType.rent);
    expect(tester.takeException(), isNull);
  });

  testWidgets('social buttons for a business', (tester) async {
    const b = Business(
      phone: '+993 65 000000',
      instagram: 'shop',
      telegram: 'shop',
      website: 'https://shop.tm',
    );
    await tester.pumpWidget(_app(const SocialButtons(business: b)));
    // Phone is a separate "Jaň et" button, not a social icon.
    expect(find.byTooltip(S.instagram), findsOneWidget);
    expect(find.byTooltip(S.telegram), findsOneWidget);
    expect(find.byTooltip(S.website), findsOneWidget);
    expect(find.byTooltip(S.call), findsNothing);
  });
}
