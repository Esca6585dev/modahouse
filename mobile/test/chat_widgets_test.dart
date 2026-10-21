import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modahouse/core/theme.dart';
import 'package:modahouse/core/token_storage.dart';
import 'package:modahouse/l10n/strings.dart';
import 'package:modahouse/models/models.dart';
import 'package:modahouse/state/providers.dart';
import 'package:modahouse/widgets/chat_widgets.dart';
import 'package:modahouse/widgets/top_actions.dart';
import 'package:modahouse/state/chat_state.dart';

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

const _shop = UserBrief(
  id: 2,
  username: 'ak.gelin',
  name: 'Ak Gelin',
  isBusiness: true,
  verified: true,
);
const _me = UserBrief(id: 1, username: 'aylar.studio', name: 'Aýlar Studio');

Message _m({
  int id = 1,
  bool mine = false,
  MessageKind kind = MessageKind.text,
  String text = 'Salam!',
  bool read = false,
  bool deleted = false,
  Attachment? attachment,
  PinPreview? pin,
  MessageStatus status = MessageStatus.sent,
  String clientId = '',
  OutgoingFile? file,
  double? progress,
}) => Message(
  id: id,
  chatId: 5,
  sender: mine ? _me : _shop,
  kind: kind,
  text: text,
  mine: mine,
  read: read,
  deleted: deleted,
  attachment: attachment,
  pin: pin,
  status: status,
  clientId: clientId,
  file: file,
  progress: progress,
  createdAt: DateTime(2026, 10, 18, 14, 5),
);

/// A 1×1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  group('chat list tile', () {
    final now = DateTime(2026, 10, 18, 15);

    testWidgets('name, badge, preview, time and unread pill', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          ChatTile(
            chat: Chat(
              id: 5,
              other: _shop,
              lastMessage: _m(kind: MessageKind.image, text: ''),
              unreadCount: 3,
            ),
            now: now,
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.text('Ak Gelin'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
      expect(find.text(S.photoPreview), findsOneWidget);
      expect(find.text('55 min'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byType(ChatTile));
      expect(taps, 1);
    });

    testWidgets('my last message: "Siz: …" with read ticks', (tester) async {
      await tester.pumpWidget(
        _app(
          ChatTile(
            chat: Chat(
              id: 5,
              other: _shop,
              lastMessage: _m(mine: true, text: 'Bolýar', read: true),
            ),
            now: now,
            onTap: () {},
          ),
        ),
      );
      expect(find.text(S.youPrefix('Bolýar')), findsOneWidget);
      expect(find.byKey(const Key('ticks-sent-read')), findsOneWidget);
      expect(find.byType(UnreadPill), findsNothing);
    });

    testWidgets('typing replaces the preview', (tester) async {
      await tester.pumpWidget(
        _app(
          ChatTile(
            chat: Chat(id: 5, other: _shop, lastMessage: _m()),
            typing: true,
            now: now,
            onTap: () {},
          ),
        ),
      );
      expect(find.text(S.typing), findsOneWidget);
      expect(find.text('Salam!'), findsNothing);
    });
  });

  group('message bubbles', () {
    testWidgets('mine is brand red on the right, theirs gray on the left', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ListView(
            children: [
              MessageBubble(message: _m(id: 1)),
              MessageBubble(message: _m(id: 2, mine: true, text: 'Bolýar')),
            ],
          ),
        ),
      );
      BoxDecoration deco(int id) =>
          tester.widget<Container>(find.byKey(Key('bubble-$id'))).decoration!
              as BoxDecoration;
      expect(deco(2).color, AppPalette.accent);
      expect(deco(1).color, AppPalette.light.surface);
      final mineText = tester.widget<Text>(find.text('Bolýar'));
      expect(mineText.style!.color, Colors.white);
      final left = tester.getTopLeft(find.byKey(const Key('bubble-1'))).dx;
      final right = tester.getTopRight(find.byKey(const Key('bubble-2'))).dx;
      expect(left, lessThan(30));
      expect(right, greaterThan(760));
      expect(find.text('14:05'), findsNWidgets(2));
    });

    testWidgets('ticks: pending, sent, read, failed with retry', (
      tester,
    ) async {
      var retried = 0;
      await tester.pumpWidget(
        _app(
          ListView(
            children: [
              MessageBubble(
                message: _m(
                  id: 0,
                  mine: true,
                  status: MessageStatus.pending,
                  clientId: 'p',
                ),
              ),
              MessageBubble(message: _m(id: 2, mine: true)),
              MessageBubble(message: _m(id: 3, mine: true, read: true)),
              MessageBubble(
                message: _m(
                  id: 0,
                  mine: true,
                  status: MessageStatus.failed,
                  clientId: 'f',
                ),
                onRetry: () => retried++,
              ),
            ],
          ),
        ),
      );
      expect(find.byKey(const Key('ticks-pending')), findsOneWidget);
      expect(find.byKey(const Key('ticks-sent')), findsOneWidget);
      expect(find.byKey(const Key('ticks-sent-read')), findsOneWidget);
      expect(find.byKey(const Key('ticks-failed')), findsOneWidget);
      expect(find.text('${S.notSent} · ${S.retrySend}'), findsOneWidget);
      await tester.tap(find.byKey(const Key('retry-f')));
      expect(retried, 1);
    });

    testWidgets('image: thumbnail opens the viewer; upload progress', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        _app(
          ListView(
            children: [
              MessageBubble(
                message: _m(
                  id: 7,
                  kind: MessageKind.image,
                  text: '',
                  attachment: const Attachment(
                    url: '/api/chat-files/a.jpg?sig=x',
                    name: 'a.jpg',
                    mimeType: 'image/jpeg',
                    width: 800,
                    height: 600,
                  ),
                ),
                onOpenImage: () => opened++,
              ),
              MessageBubble(
                message: _m(
                  id: 0,
                  mine: true,
                  kind: MessageKind.image,
                  text: '',
                  status: MessageStatus.pending,
                  clientId: 'up',
                  progress: 0.4,
                  file: OutgoingFile(
                    bytes: _png,
                    name: 'surat.png',
                    mimeType: 'image/png',
                    width: 1,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('image-7')));
      expect(opened, 1);
      final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(progress.value, 0.4);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('file: icon, name, size; tap opens', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _app(
          MessageBubble(
            message: _m(
              id: 8,
              kind: MessageKind.file,
              text: '',
              attachment: const Attachment(
                url: '/api/chat-files/olcheg.pdf',
                name: 'olcheg.pdf',
                size: 1468006,
                mimeType: 'application/pdf',
              ),
            ),
            onOpenFile: () => opened++,
          ),
        ),
      );
      expect(find.text('olcheg.pdf'), findsOneWidget);
      expect(find.text('1,4 MB'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      await tester.tap(find.byKey(const Key('file-8')));
      expect(opened, 1);
    });

    testWidgets('shared post card opens the post', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _app(
          MessageBubble(
            message: _m(
              id: 9,
              kind: MessageKind.pin,
              text: 'Şu köýnek barmy?',
              pin: const PinPreview(
                id: 42,
                title: 'Ak toý köýnegi',
                price: 450,
                listingType: 'rent',
              ),
            ),
            onOpenPin: () => opened++,
          ),
        ),
      );
      expect(find.text('Ak toý köýnegi'), findsOneWidget);
      expect(find.text('450 TMT ${S.perDay}'), findsOneWidget);
      expect(find.text('Şu köýnek barmy?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pin-42')));
      expect(opened, 1);
    });

    testWidgets('deleted: "Bu habar pozuldy", no long press', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _app(
          MessageBubble(
            message: _m(id: 4, mine: true).asDeleted(),
            onLongPress: () => pressed++,
          ),
        ),
      );
      expect(find.text(S.messageDeleted), findsOneWidget);
      expect(find.text('Salam!'), findsNothing);
      await tester.longPress(find.byKey(const Key('bubble-4')));
      expect(pressed, 0);
    });
  });

  group('composer', () {
    testWidgets('sends text and clears; send disabled when empty', (
      tester,
    ) async {
      final sent = <ComposerDraft>[];
      var typing = 0;
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.bottomCenter,
            child: ChatComposer(onSend: sent.add, onTyping: () => typing++),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('composer-send')));
      expect(sent, isEmpty);
      await tester.enterText(find.byKey(const Key('composer-field')), 'Salam');
      await tester.pump();
      expect(typing, 1);
      await tester.tap(find.byKey(const Key('composer-send')));
      await tester.pump();
      expect(sent.single.text, 'Salam');
      expect(find.text('Salam'), findsNothing);
    });

    testWidgets('a prefilled post is previewed and sent with the text', (
      tester,
    ) async {
      final sent = <ComposerDraft>[];
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.bottomCenter,
            child: ChatComposer(
              onSend: sent.add,
              initialText: 'Salam! Bu barada…',
              initialPin: const PinPreview(id: 42, title: 'Ak köýnek'),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('composer-preview')), findsOneWidget);
      expect(find.text('Ak köýnek'), findsOneWidget);
      await tester.tap(find.byKey(const Key('composer-send')));
      await tester.pump();
      expect(sent.single.pin!.id, 42);
      expect(sent.single.text, 'Salam! Bu barada…');
      expect(find.byKey(const Key('composer-preview')), findsNothing);
    });

    testWidgets('attach menu: picked photo previewed then sent', (
      tester,
    ) async {
      final sent = <ComposerDraft>[];
      AttachSource? asked;
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.bottomCenter,
            child: ChatComposer(
              onSend: sent.add,
              onAttach: (s) async {
                asked = s;
                return OutgoingFile(
                  bytes: _png,
                  name: 'surat.png',
                  mimeType: 'image/png',
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('composer-attach')));
      await tester.pumpAndSettle();
      expect(find.text(S.camera), findsOneWidget);
      expect(find.text(S.fileLabel), findsOneWidget);
      await tester.tap(find.byKey(const Key('attach-gallery')));
      await tester.pumpAndSettle();
      expect(asked, AttachSource.gallery);
      expect(find.byKey(const Key('composer-preview')), findsOneWidget);
      await tester.tap(find.byKey(const Key('composer-send')));
      await tester.pump();
      expect(sent.single.file!.name, 'surat.png');
    });

    testWidgets('blocked chat shows a notice', (tester) async {
      await tester.pumpWidget(_app(const BlockedNotice()));
      expect(find.text(S.chatBlocked), findsOneWidget);
    });
  });

  testWidgets('paper plane badge shows unread messages', (tester) async {
    await tester.pumpWidget(
      _app(
        const ChatsButton(),
        overrides: [chatUnreadProvider.overrideWithBuild((ref, _) => 4)],
      ),
    );
    expect(find.byTooltip('${S.chats} (4)'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });
}
