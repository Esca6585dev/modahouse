import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/chat_logic.dart';
import '../state/chat_state.dart';
import '../state/providers.dart';
import 'chat_widgets.dart';
import 'shop_ui.dart';
import 'states.dart';

/// "Habar bilen ugrat": pick recent chats (or search people) and send them
/// the post.
Future<void> showSendToChatSheet(BuildContext context, Pin pin) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SendToChatSheet(pin: pin),
    );

enum _SendState { idle, sending, sent }

class SendToChatSheet extends ConsumerStatefulWidget {
  const SendToChatSheet({super.key, required this.pin});

  final Pin pin;

  @override
  ConsumerState<SendToChatSheet> createState() => _SendToChatSheetState();
}

class _SendToChatSheetState extends ConsumerState<SendToChatSheet> {
  final _search = TextEditingController();
  final _note = TextEditingController();
  String _query = '';
  Timer? _debounce;
  List<UserBrief> _people = const [];
  bool _searching = false;

  /// Keyed by username.
  final _state = <String, _SendState>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(chatsProvider.notifier).ensureLoaded());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onQuery(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      setState(() => _people = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final r = await ref.read(pinsRepositoryProvider).search(q);
        if (!mounted || _query.trim() != q) return;
        setState(() => _people = r.users);
      } catch (_) {
        // Chats still filter locally.
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _send(UserBrief user, {Chat? chat}) async {
    if (_state[user.username] != null) return;
    setState(() => _state[user.username] = _SendState.sending);
    final repo = ref.read(chatsRepositoryProvider);
    try {
      final target = chat ?? await repo.open(user.username);
      final m = await repo.sendText(
        target.id,
        text: _note.text.trim(),
        pinId: widget.pin.id,
        clientId: newClientId(),
      );
      if (!mounted) return;
      ref
          .read(chatsProvider.notifier)
          .put(target.copyWith(lastMessage: m, updatedAt: m.createdAt));
      setState(() => _state[user.username] = _SendState.sent);
    } catch (e) {
      if (!mounted) return;
      setState(() => _state.remove(user.username));
      if (e is ApiException && e.statusCode == 403) {
        showSnack(S.chatBlocked, error: true);
      } else {
        showError(e);
      }
    }
  }

  bool _matches(UserBrief u) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return u.name.toLowerCase().contains(q) ||
        u.username.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final chats = ref.watch(chatsProvider);
    final me = ref.watch(currentUserIdProvider);
    final mine = chats.items.where((c) => _matches(c.other)).toList();
    final known = {for (final c in chats.items) c.other.username};
    final people = _people
        .where((u) => !known.contains(u.username) && u.id != me)
        .toList();
    final height = MediaQuery.sizeOf(context).height * 0.75;

    Widget row(UserBrief u, {Chat? chat}) {
      final st = _state[u.username] ?? _SendState.idle;
      return ListTile(
        key: ValueKey('send-to-${u.username}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: ChatAvatar(user: u, size: 44),
        title: UserName(
          user: u,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('@${u.username}', style: TextStyle(color: p.muted)),
        trailing: SizedBox(
          width: 104,
          child: st == _SendState.sent
              ? OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(S.sentDone),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                )
              : FilledButton(
                  key: ValueKey('send-button-${u.username}'),
                  onPressed: st == _SendState.sending
                      ? null
                      : () => _send(u, chat: chat),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: st == _SendState.sending
                      ? const Spinner(size: 16, color: Colors.white)
                      : const Text(S.sendTo),
                ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    S.sendToTitle,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('send-to-search'),
              controller: _search,
              onChanged: _onQuery,
              decoration: InputDecoration(
                hintText: S.chatSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                filled: true,
                fillColor: p.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: !chats.loaded && chats.items.isEmpty
                ? const LoadingView()
                : ListView(
                    children: [
                      for (final c in mine) row(c.other, chat: c),
                      for (final u in people) row(u),
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Spinner(size: 20)),
                        ),
                      if (mine.isEmpty && people.isEmpty && !_searching)
                        EmptyView(
                          icon: Icons.send_outlined,
                          title: _query.isEmpty
                              ? S.chatsEmptyTitle
                              : S.chatSearchEmpty,
                          compact: true,
                        ),
                    ],
                  ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  10 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: TextField(
                  key: const Key('send-to-note'),
                  controller: _note,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: S.addMessageHint,
                    isDense: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
