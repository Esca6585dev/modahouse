import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modahouse/core/theme.dart';
import 'package:modahouse/core/token_storage.dart';
import 'package:modahouse/l10n/strings.dart';
import 'package:modahouse/models/models.dart';
import 'package:modahouse/screens/orders_screens.dart';
import 'package:modahouse/screens/top_screen.dart';
import 'package:modahouse/state/providers.dart';
import 'package:modahouse/widgets/brand.dart';
import 'package:modahouse/widgets/pin_card.dart';
import 'package:modahouse/widgets/shop_ui.dart';

const _shop = {
  'id': 9,
  'username': 'gyzyl.guyze',
  'name': 'Gyzyl Güýze',
  'avatarUrl': '',
  'isBusiness': true,
  'verified': true,
};

Widget _app(Widget child) => ProviderScope(
  overrides: [
    networkImagesProvider.overrideWithValue(false),
    tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
  ],
  child: MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('product card: badge, price, old price and cart button', (
    tester,
  ) async {
    final pin = Pin.fromJson({
      'id': 31,
      'title': 'Zarif köýnek',
      'imageUrl': '/x.svg',
      'width': 600,
      'height': 800,
      'author': _shop,
      'product': {'price': 450, 'oldPrice': 520, 'badge': 'hit'},
    });
    await tester.pumpWidget(
      _app(SizedBox(width: 180, child: PinCard(pin: pin))),
    );
    expect(find.text('Zarif köýnek'), findsOneWidget);
    expect(find.text('450 TMT'), findsOneWidget);
    final old = tester.widget<Text>(find.text('520 TMT'));
    expect(old.style?.decoration, TextDecoration.lineThrough);
    expect(find.text(S.badgeHit), findsOneWidget);
    expect(find.byIcon(Icons.add_shopping_cart_rounded), findsOneWidget);
    expect(find.byType(VerifiedIcon), findsOneWidget);
  });

  testWidgets('Top 10 card shows rank, score, stats and buttons', (
    tester,
  ) async {
    final entry = TopEntry.fromJson({
      'rank': 1,
      'score': 96,
      'views': 12450,
      'likes': 3280,
      'orders': 620,
      'moreCount': 5,
      'business': {
        ..._shop,
        'category': 'dress',
        'rating': 4.8,
        'reviewsCount': 128,
        'covers': ['/a.svg', '/b.svg', '/c.svg', '/d.svg'],
      },
    });
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        Padding(
          padding: const EdgeInsets.all(16),
          child: TopEntryCard(entry: entry),
        ),
      ),
    );
    expect(find.text('Gyzyl Güýze'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('96/100'), findsOneWidget);
    expect(find.text(S.totalScore), findsOneWidget);
    expect(find.text('12 450'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
    expect(find.text('(128)'), findsOneWidget);
    expect(find.text(S.viewProfile), findsOneWidget);
    expect(find.text(S.viewDresses), findsOneWidget);
    final err = tester.takeException();
    if (err != null) debugPrint(err.toString());
    expect(err, isNull);
  });

  testWidgets('order timeline marks the reached steps', (tester) async {
    await tester.pumpWidget(
      _app(const OrderTimeline(status: OrderStatus.shipped)),
    );
    expect(find.text(S.statusNew), findsOneWidget);
    expect(find.text(S.statusDelivered), findsOneWidget);
    // new, confirmed and shipped are checked.
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    await tester.pumpWidget(
      _app(const OrderTimeline(status: OrderStatus.cancelled)),
    );
    expect(find.text(S.statusCancelled), findsOneWidget);
  });

  testWidgets('price text, stepper and wordmark', (tester) async {
    var qty = 1;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              const PriceText(price: 1250),
              QuantityStepper(
                value: qty,
                max: 3,
                onChanged: (v) => setState(() => qty = v),
              ),
              const LogoWordmark(height: 40),
            ],
          ),
        ),
      ),
    );
    expect(find.text('1 250 TMT'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(qty, 3);
    expect(find.bySemanticsLabel(S.appName), findsOneWidget);
  });
}
