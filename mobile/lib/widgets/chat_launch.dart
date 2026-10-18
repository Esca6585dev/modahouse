import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/snack.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/chat_state.dart';
import '../state/providers.dart';

/// What to open a conversation with: the chat (to show it at once), a
/// prefilled message and a post to attach.
class ChatLaunch {
  const ChatLaunch({this.chat, this.draft = '', this.pin});

  final Chat? chat;
  final String draft;
  final PinPreview? pin;
}

/// The post as a chat attachment.
PinPreview pinPreviewOf(Pin pin) => PinPreview(
  id: pin.id,
  title: pin.title,
  imageUrl: pin.imageUrl,
  width: pin.width,
  height: pin.height,
  color: pin.color,
  price: pin.product?.price ?? 0,
  listingType: pin.product?.type.name ?? '',
);

/// Opens (or creates) the chat with [username] and shows it. Asks to log in
/// first when needed.
Future<void> openChatWith(
  BuildContext context,
  String username, {
  String draft = '',
  PinPreview? pin,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final router = GoRouter.of(context);
  if (!container.read(authProvider).isLoggedIn) {
    final here = GoRouterState.of(context).uri.toString();
    unawaited(router.push('/login?from=${Uri.encodeComponent(here)}'));
    return;
  }
  try {
    final chat = await container.read(chatsRepositoryProvider).open(username);
    container.read(chatsProvider.notifier).put(chat);
    unawaited(
      router.push(
        '/chats/${chat.id}',
        extra: ChatLaunch(chat: chat, draft: draft, pin: pin),
      ),
    );
  } on ApiException catch (e) {
    showSnack(e.statusCode == 403 ? S.chatBlocked : e.message, error: true);
  } catch (e) {
    showError(e);
  }
}
