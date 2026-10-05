import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/paged_controller.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import '../widgets/avatar.dart';
import '../widgets/board_form.dart';
import '../widgets/pin_grid.dart';
import '../widgets/states.dart';

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  Board? _board;
  Object? _error;
  bool _busy = false;
  final Set<int> _removing = {};
  late final PagedController<Pin> _pins;

  @override
  void initState() {
    super.initState();
    _pins = PagedController(
      (page) => ref.read(boardsRepositoryProvider).pins(widget.id, page),
    );
    _load();
  }

  @override
  void dispose() {
    _pins.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final b = await ref.read(boardsRepositoryProvider).get(widget.id);
      if (mounted) setState(() => _board = b);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _edit(Board board) async {
    final updated = await showBoardForm(context, board: board);
    if (updated == null || !mounted) return;
    setState(() => _board = updated);
    showSnack(S.boardUpdated);
  }

  Future<void> _delete(Board board) async {
    final ok = await confirmDialog(
      context,
      title: S.deleteBoard,
      text: S.deleteBoardText,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(boardsRepositoryProvider).delete(board.id);
      ref.read(boardsVersionProvider.notifier).bump();
      showSnack(S.boardDeleted);
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go('/profile');
    } catch (e) {
      showError(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Pin pin) async {
    final board = _board;
    if (board == null || _removing.contains(pin.id)) return;
    final before = _pins.items;
    // Optimistic removal, restored on error.
    setState(() {
      _removing.add(pin.id);
      _board = board.copyWith(
        pinsCount: board.pinsCount > 0 ? board.pinsCount - 1 : 0,
      );
    });
    _pins.removeWhere((p) => p.id == pin.id);
    try {
      final updated = await ref
          .read(boardsRepositoryProvider)
          .unsavePin(board.id, pin.id);
      if (updated != null) {
        ref.read(pinUpdatesProvider.notifier).updated(updated);
      }
      ref.read(boardsVersionProvider.notifier).bump();
      showSnack(S.removedFromBoard);
    } catch (e) {
      _pins.setItems(before);
      if (mounted) setState(() => _board = board);
      showError(e);
    } finally {
      if (mounted) setState(() => _removing.remove(pin.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;
    final board = _board;

    if (board == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error == null
            ? const LoadingView()
            : (_error is ApiException && (_error as ApiException).isNotFound)
            ? const EmptyView(
                icon: Icons.dashboard_outlined,
                title: S.boardNotFound,
                text: S.boardNotFoundText,
              )
            : ErrorView(error: _error!, onRetry: _load),
      );
    }

    final isOwner = me != null && me.id == board.owner.id;
    final p = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              tooltip: S.boardOptions,
              enabled: !_busy,
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (v) => v == 'edit' ? _edit(board) : _delete(board),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text(S.editBoard),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: AppPalette.danger,
                    ),
                    title: Text(
                      S.deleteBoard,
                      style: TextStyle(color: AppPalette.danger),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: () => Future.wait([_load(), _pins.refresh()]),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppPalette.gutter,
                  0,
                  AppPalette.gutter,
                  24,
                ),
                child: Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          board.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        if (board.isPrivate)
                          Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  size: 14,
                                  color: p.muted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  S.privateBoard,
                                  style: TextStyle(
                                    color: p.muted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (board.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        board.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => context.push(
                        '/user/${Uri.encodeComponent(board.owner.username)}',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(user: board.owner, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              board.owner.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      S.pinsCount('${board.pinsCount}'),
                      style: TextStyle(color: p.muted),
                    ),
                  ],
                ),
              ),
            ),
            PinGridSliver(
              controller: _pins,
              empty: const EmptyView(
                icon: Icons.push_pin_outlined,
                title: S.boardEmptyTitle,
                text: S.boardEmptyText,
                compact: true,
              ),
              actionBuilder: isOwner
                  ? (pin) => RoundIconButton(
                      icon: Icons.close_rounded,
                      size: 34,
                      tooltip: S.removeFromBoard,
                      onPressed: _removing.contains(pin.id)
                          ? null
                          : () => _remove(pin),
                    )
                  : null,
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.paddingOf(context).bottom + 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
