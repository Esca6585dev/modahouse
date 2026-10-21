import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/api_exception.dart';
import '../core/chat_format.dart';
import '../core/download/download.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/chat_alerts.dart';
import '../state/chat_logic.dart';
import '../state/chat_state.dart';
import '../state/conversation.dart';
import '../state/providers.dart';
import '../state/realtime.dart';
import '../widgets/chat_launch.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/shop_ui.dart';
import '../widgets/states.dart';
import 'create_screen.dart' show pickImage;

/// MIME type from a file name (documents, audio, video, images).
String mimeForName(String name) {
  final ext = name.toLowerCase().split('.').last;
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'mp4' || 'm4v' => 'video/mp4',
    'webm' => 'video/webm',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt' => 'text/plain',
    'zip' => 'application/zip',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'ogg' => 'audio/ogg',
    _ => 'application/octet-stream',
  };
}

/// Documents allowed in chat (docs/API.md, v6).
const chatFileExtensions = [
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'txt',
  'zip',
  'mp3',
  'm4a',
  'ogg',
  'mp4',
  'webm',
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
];

Future<OutgoingFile?> _imageFile(Uint8List bytes, String name) async {
  var w = 0;
  var h = 0;
  try {
    final img = await decodeImageFromList(bytes);
    w = img.width;
    h = img.height;
    img.dispose();
  } catch (_) {}
  return OutgoingFile(
    bytes: bytes,
    name: name,
    mimeType: mimeForName(name).startsWith('image/')
        ? mimeForName(name)
        : 'image/jpeg',
    width: w,
    height: h,
  );
}

/// Camera / gallery (image_picker) or a document (file_picker).
Future<OutgoingFile?> pickChatFile(AttachSource source) async {
  switch (source) {
    case AttachSource.camera:
    case AttachSource.gallery:
      final picked = await pickImage(
        source == AttachSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
      if (picked == null) return null;
      return _imageFile(picked.bytes, picked.name);
    case AttachSource.file:
      try {
        final f = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: chatFileExtensions,
        );
        if (f == null) return null;
        final bytes = await f.readAsBytes();
        final mime = mimeForName(f.name);
        if (mime.startsWith('image/')) return await _imageFile(bytes, f.name);
        if (bytes.length > 20 * 1024 * 1024 && !mime.startsWith('video/')) {
          showSnack(S.fileTooLarge, error: true);
          return null;
        }
        return OutgoingFile(bytes: bytes, name: f.name, mimeType: mime);
      } catch (_) {
        showSnack(S.genericError, error: true);
        return null;
      }
  }
}

/// Opens an attachment link in the browser / a viewer app.
Future<void> openAttachment(Attachment a) async {
  final url = resolveImageUrl(a.url);
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) showSnack(S.cannotOpenLink, error: true);
}

// ---------------------------------------------------------------------------
// Chats list
// ---------------------------------------------------------------------------

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  bool _askPermission = false;

  static const _permissionKey = 'mh_chat_notif_asked';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(chatsProvider.notifier).refresh());
      unawaited(ref.read(chatUnreadProvider.notifier).refresh());
      unawaited(_checkPermission());
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        unawaited(ref.read(chatsProvider.notifier).loadMore());
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Android 13+: offer notifications politely, once, from this screen.
  Future<void> _checkPermission() async {
    final granted = await ref.read(localNotifierProvider).permissionGranted();
    if (granted != false || !mounted) return;
    var dismissed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      dismissed = prefs.getBool(_permissionKey) ?? false;
    } catch (_) {}
    if (!dismissed && mounted) setState(() => _askPermission = true);
  }

  Future<void> _answerPermission(bool allow) async {
    setState(() => _askPermission = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_permissionKey, true);
    } catch (_) {}
    if (allow) await ref.read(localNotifierProvider).requestPermission();
  }

  bool _matches(Chat c) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.other.name.toLowerCase().contains(q) ||
        c.other.username.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatsProvider);
    final typing = ref.watch(typingProvider);
    final p = AppPalette.of(context);
    final items = state.items.where(_matches).toList();

    Widget body;
    if (!state.loaded && state.items.isEmpty) {
      body = const LoadingView();
    } else if (state.error != null && state.items.isEmpty) {
      body = ErrorView(
        error: state.error!,
        onRetry: () => ref.read(chatsProvider.notifier).refresh(),
      );
    } else if (state.items.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          EmptyView(
            icon: Icons.send_outlined,
            title: S.chatsEmptyTitle,
            text: S.chatsEmptyText,
          ),
        ],
      );
    } else {
      body = ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.isEmpty ? 1 : items.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.search_off_rounded,
              title: S.chatSearchEmpty,
              compact: true,
            );
          }
          if (i >= items.length) return const OlderLoader();
          final c = items[i];
          return ChatTile(
            key: ValueKey('chat-${c.id}'),
            chat: c,
            typing: typing.contains(c.id),
            onTap: () =>
                context.push('/chats/${c.id}', extra: ChatLaunch(chat: c)),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(S.chats)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppPalette.gutter,
              4,
              AppPalette.gutter,
              8,
            ),
            child: TextField(
              key: const Key('chats-search'),
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: S.chatSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: p.surface,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: S.searchClear,
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          if (_askPermission)
            _PermissionCard(
              onAllow: () => _answerPermission(true),
              onLater: () => _answerPermission(false),
            ),
          Expanded(
            child: RefreshIndicator(
              color: AppPalette.accent,
              onRefresh: () async {
                await Future.wait([
                  ref.read(chatsProvider.notifier).refresh(),
                  ref.read(chatUnreadProvider.notifier).refresh(),
                ]);
              },
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.onAllow, required this.onLater});

  final VoidCallback onAllow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppPalette.gutter,
        0,
        AppPalette.gutter,
        8,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
      decoration: BoxDecoration(
        color: p.tint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: AppPalette.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      S.notifPermissionTitle,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.notifPermissionText,
                      style: TextStyle(color: p.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onLater,
                style: TextButton.styleFrom(foregroundColor: p.muted),
                child: const Text(S.notifLater),
              ),
              TextButton(onPressed: onAllow, child: const Text(S.notifAllow)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Conversation
// ---------------------------------------------------------------------------

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.chatId, this.launch});

  final int chatId;
  final ChatLaunch? launch;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  late final ConversationController _c;
  final _scroll = ScrollController();
  int _seenIncoming = 0;
  int _newBelow = 0;
  bool _nearBottom = true;

  int get chatId => widget.chatId;

  bool _visible() {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return (route?.isCurrent ?? true) &&
        ref.read(appLifecycleProvider) == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    final me = ref.read(authProvider).user;
    final chats = ref.read(chatsProvider.notifier);
    _c = ConversationController(
      chatId: chatId,
      repo: ref.read(chatsRepositoryProvider),
      me: me ?? const UserBrief(id: 0, username: '', name: ''),
      events: ref.read(realtimeHubProvider).events,
      initialChat: widget.launch?.chat ?? chats.byId(chatId),
      isVisible: _visible,
      onChatChanged: (c) {
        if (chats.byId(c.id) != null) {
          final old = chats.byId(c.id)!;
          chats.replace(c.copyWith(lastMessage: old.lastMessage));
        }
      },
      onRead: () {
        if (!mounted) return;
        chats.markRead(chatId);
        unawaited(ref.read(chatUnreadProvider.notifier).refresh());
      },
    )..onSent = (m) => _onSent(m);
    _c.addListener(_onChange);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeChatProvider.notifier).set(chatId);
      unawaited(ref.read(localNotifierProvider).cancelChat(chatId));
    });
    unawaited(_c.load());
  }

  @override
  void deactivate() {
    ref.read(activeChatProvider.notifier).leave(chatId);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    ref.read(activeChatProvider.notifier).set(chatId);
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSent(Message m) {
    final chats = ref.read(chatsProvider.notifier);
    final chat = chats.byId(chatId) ?? _c.chat;
    if (chat != null) {
      chats.put(chat.copyWith(lastMessage: m, updatedAt: m.createdAt));
    }
  }

  void _onChange() {
    if (!mounted) return;
    final err = _c.lastError;
    if (err != null) {
      _c.lastError = null;
      if (err is ApiException && err.statusCode == 403) {
        showSnack(S.chatBlocked, error: true);
      } else {
        showError(err);
      }
    }
    if (_c.incoming != _seenIncoming) {
      final added = _c.incoming - _seenIncoming;
      _seenIncoming = _c.incoming;
      if (_nearBottom) {
        _toBottom();
      } else {
        _newBelow += added;
      }
    }
    setState(() {});
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final near = pos.pixels < 160;
    if (near != _nearBottom) {
      setState(() {
        _nearBottom = near;
        if (near) _newBelow = 0;
      });
    }
    if (pos.extentAfter < 600) unawaited(_c.loadOlder());
  }

  void _toBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (animate) {
        unawaited(
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        );
      } else {
        _scroll.jumpTo(0);
      }
    });
    if (_newBelow != 0) setState(() => _newBelow = 0);
  }

  void _send(ComposerDraft d) {
    if (d.file != null) {
      _c.sendFile(d.file!, caption: d.text);
    } else {
      _c.sendText(d.text, pin: d.pin);
    }
    _toBottom();
  }

  Future<void> _actions(Message m) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.text.isNotEmpty)
              ListTile(
                key: const Key('message-copy'),
                leading: const Icon(Icons.copy_rounded),
                title: const Text(S.copy),
                onTap: () => Navigator.of(ctx).pop('copy'),
              ),
            if (m.mine && m.isFailed)
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text(S.retrySend),
                onTap: () => Navigator.of(ctx).pop('retry'),
              ),
            if (m.mine)
              ListTile(
                key: const Key('message-delete'),
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppPalette.danger,
                ),
                title: const Text(
                  S.delete,
                  style: TextStyle(color: AppPalette.danger),
                ),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.text));
        showSnack(S.messageCopied);
      case 'retry':
        _c.retry(m);
      case 'delete':
        if (m.isLocal) {
          _c.discard(m);
          return;
        }
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(S.deleteMessageTitle),
            content: const Text(S.deleteMessageText),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(S.cancel),
              ),
              FilledButton(
                key: const Key('message-delete-confirm'),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(S.delete),
              ),
            ],
          ),
        );
        if (ok != true) return;
        try {
          await _c.delete(m);
        } catch (e) {
          showError(e);
        }
    }
  }

  void _openImage(Message m) {
    final a = m.attachment;
    if (a == null) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImageViewerScreen(
            url: a.url,
            onSave: () async {
              try {
                final media = await ref.read(mediaLoaderProvider)(
                  resolveImageUrl(a.url),
                );
                await saveFile(
                  media.bytes,
                  a.name.isEmpty ? 'modahouse.jpg' : a.name,
                  media.mimeType,
                );
                showSnack(S.imageSaved);
              } catch (_) {
                showSnack(S.genericError, error: true);
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appLifecycleProvider, (_, s) {
      if (s == AppLifecycleState.resumed) _c.markRead();
    });
    final chat = _c.chat;
    final typing = ref.watch(typingProvider.select((s) => s.contains(chatId)));
    final p = AppPalette.of(context);
    final msgs = _c.messages;

    Widget list;
    if (!_c.loaded && msgs.isEmpty) {
      list = _c.error != null
          ? ErrorView(error: _c.error!, onRetry: _c.load)
          : const LoadingView();
    } else {
      final count = msgs.length + (_c.hasMore ? 1 : 0);
      list = ListView.builder(
        key: const Key('messages'),
        controller: _scroll,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: count,
        itemBuilder: (context, i) {
          if (i >= msgs.length) return const OlderLoader();
          final idx = msgs.length - 1 - i;
          final m = msgs[idx];
          final older = idx > 0 ? msgs[idx - 1] : null;
          final newer = idx < msgs.length - 1 ? msgs[idx + 1] : null;
          final created = m.createdAt;
          final newDay =
              created != null &&
              (older?.createdAt == null ||
                  dayOf(older!.createdAt!) != dayOf(created));
          return Column(
            key: ValueKey(m.clientId.isNotEmpty ? m.clientId : 'id${m.id}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (newDay) DateSeparator(label: dayLabel(created)),
              MessageBubble(
                message: m,
                first: newDay || older == null || !sameGroup(older, m),
                last: newer == null || !sameGroup(m, newer),
                onLongPress: () => _actions(m),
                onRetry: () => _c.retry(m),
                onOpenImage: () => _openImage(m),
                onOpenFile: m.attachment == null
                    ? null
                    : () => openAttachment(m.attachment!),
                onOpenPin: m.pin == null
                    ? null
                    : () => context.push('/pin/${m.pin!.id}'),
              ),
            ],
          );
        },
      );
      if (msgs.isEmpty && chat != null) {
        list = Stack(
          children: [
            list,
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChatAvatar(user: chat.other, size: 84),
                  const SizedBox(height: 12),
                  UserName(
                    user: chat.other,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '@${chat.other.username}',
                    style: TextStyle(color: p.muted),
                  ),
                ],
              ),
            ),
          ],
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Navigator.of(context).canPop() ? 0 : AppPalette.gutter,
        title: chat == null
            ? const SizedBox.shrink()
            : Semantics(
                button: true,
                label: chat.other.displayName,
                child: InkWell(
                  onTap: () => context.push('/user/${chat.other.username}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        ChatAvatar(user: chat.other, size: 38),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              UserName(
                                user: chat.other,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 150),
                                child: Text(
                                  typing ? S.typing : '@${chat.other.username}',
                                  key: ValueKey(typing),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: typing
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: typing ? AppPalette.accent : p.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: list),
                if (_newBelow > 0 || (!_nearBottom && _c.loaded))
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _newBelow > 0
                          ? Semantics(
                              button: true,
                              label: S.newMessages,
                              excludeSemantics: true,
                              onTap: _toBottom,
                              child: Material(
                                key: const Key('new-messages-chip'),
                                color: AppPalette.accent,
                                shape: const StadiumBorder(),
                                elevation: 3,
                                child: InkWell(
                                  customBorder: const StadiumBorder(),
                                  onTap: _toBottom,
                                  child: const Padding(
                                    padding: EdgeInsets.fromLTRB(16, 9, 12, 9),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          S.newMessages,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_downward_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Material(
                              color: p.card,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _toBottom,
                                child: const SizedBox.square(
                                  dimension: 40,
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
          if (chat?.blocked ?? false)
            const BlockedNotice()
          else
            ChatComposer(
              initialText: widget.launch?.draft ?? '',
              initialPin: widget.launch?.pin,
              onSend: _send,
              onTyping: _c.typed,
              onAttach: pickChatFile,
            ),
        ],
      ),
    );
  }
}
