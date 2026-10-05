import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modahouse/core/api_client.dart';
import 'package:modahouse/core/api_exception.dart';
import 'package:modahouse/core/theme.dart';
import 'package:modahouse/core/token_storage.dart';
import 'package:modahouse/data/auth_repository.dart';
import 'package:modahouse/l10n/strings.dart';
import 'package:modahouse/models/models.dart';
import 'package:modahouse/screens/auth_screens.dart';
import 'package:modahouse/state/auth.dart';
import 'package:modahouse/state/providers.dart';
import 'package:modahouse/widgets/pin_card.dart';

final _pin = Pin.fromJson({
  'id': 7,
  'title': 'Güýz üçin gatlakly geýim',
  'imageUrl': '/uploads/seed/pin-01.svg',
  'width': 600,
  'height': 840,
  'color': '#f2d0b6',
  'author': {
    'id': 1,
    'username': 'aylar.studio',
    'name': 'Aýlar Studio',
    'avatarUrl': '',
  },
});

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(ApiClient(baseUrl: 'http://test/api'));

  final calls = <String>[];

  @override
  Future<AuthResponse> login(String login, String password) async {
    calls.add('$login:$password');
    if (password != 'modahouse123') {
      throw const ApiException('Ulanyjy ady ýa-da parol nädogry', 401);
    }
    return AuthResponse.fromJson({
      'token': 'jwt-token',
      'user': {
        'id': 1,
        'username': login,
        'name': 'Aýlar Studio',
        'email': 'a@modahouse.tm',
      },
    });
  }
}

Widget _app(Widget child, {List overrides = const []}) => ProviderScope(
  overrides: [
    networkImagesProvider.overrideWithValue(false),
    tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
    ...overrides.cast(),
  ],
  child: MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: child),
  ),
);

void main() {
  group('PinCard', () {
    testWidgets('shows title, author and keeps the image aspect ratio', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(SizedBox(width: 180, child: PinCard(pin: _pin))),
      );
      expect(find.text('Güýz üçin gatlakly geýim'), findsOneWidget);
      expect(find.text('Aýlar Studio'), findsOneWidget);
      // Letter avatar (no avatarUrl).
      expect(find.text('A'), findsOneWidget);
      final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(ratio.aspectRatio, closeTo(600 / 840, 1e-9));
      // Placeholder uses the pin color.
      final boxes = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
      expect(boxes.any((b) => b.color.toARGB32() == 0xFFF2D0B6), isTrue);
    });

    testWidgets('tap, long-press and author tap callbacks', (tester) async {
      var taps = 0, longPresses = 0, authorTaps = 0;
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 180,
            child: PinCard(
              pin: _pin,
              onTap: () => taps++,
              onLongPress: () => longPresses++,
              onAuthorTap: () => authorTaps++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AspectRatio));
      await tester.longPress(find.byType(AspectRatio));
      await tester.tap(find.text('Aýlar Studio'));
      await tester.pump();
      expect(taps, 1);
      expect(longPresses, 1);
      expect(authorTaps, 1);
    });
  });

  group('LoginForm', () {
    late _FakeAuthRepository repo;
    setUp(() => repo = _FakeAuthRepository());

    Future<void> pumpForm(WidgetTester tester, VoidCallback onSuccess) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(child: LoginForm(onSuccess: onSuccess)),
          overrides: [authRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pump();
    }

    testWidgets('validates empty fields', (tester) async {
      await pumpForm(tester, () {});
      expect(find.text(S.demoHint), findsOneWidget);
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pump();
      expect(find.text(S.loginRequired), findsOneWidget);
      expect(find.text(S.passwordRequired), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('shows the server message on wrong password', (tester) async {
      var success = 0;
      await pumpForm(tester, () => success++);
      await tester.enterText(
        find.byKey(const Key('login-field')),
        'aylar.studio',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('password-field')),
          matching: find.byType(TextField),
        ),
        'nope',
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Ulanyjy ady ýa-da parol nädogry'), findsOneWidget);
      expect(success, 0);
    });

    testWidgets('demo hint fills the form and login succeeds', (tester) async {
      var success = 0;
      await pumpForm(tester, () => success++);
      await tester.tap(find.text(S.demoHint));
      await tester.pump();
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(repo.calls, ['aylar.studio:modahouse123']);
      expect(success, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoginForm)),
      );
      expect(container.read(authProvider).isLoggedIn, isTrue);
      expect(container.read(authProvider).token, 'jwt-token');
      expect(await container.read(tokenStorageProvider).read(), 'jwt-token');
    });
  });
}
