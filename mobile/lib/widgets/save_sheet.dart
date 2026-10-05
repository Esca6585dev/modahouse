import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import 'app_image.dart';
import 'states.dart';

/// Opens the "save to board" bottom sheet. Logged-out users go to login.
Future<void> showSaveSheet(
  BuildContext context,
  WidgetRef ref,
  Pin pin, {
  ValueChanged<Pin>? onChanged,
}) async {
  if (!ref.read(authProvider).isLoggedIn) {
    await context.push('/login?from=${Uri.encodeComponent('/pin/${pin.id}')}');
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SaveSheet(pin: pin, onChanged: onChanged),
  );
}

class SaveSheet extends ConsumerStatefulWidget {
  const SaveSheet({super.key, required this.pin, this.onChanged});

  final Pin pin;
  final ValueChanged<Pin>? onChanged;

  @override
  ConsumerState<SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends ConsumerState<SaveSheet> {
  List<Board>? _boards;
  Object? _loadError;
  late Set<int> _saved;
  late Pin _pin;
  int? _busyId;
  bool _busyNew = false;
  bool _creating = false;
  String? _error;
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pin = ref.read(pinUpdatesProvider).resolve(widget.pin);
    _saved = {..._pin.savedBoardIds};
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _boards = null;
    });
    try {
      final boards = await ref.read(boardsRepositoryProvider).mine();
      if (mounted) setState(() => _boards = boards);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  void _publish(Pin updated) {
    _pin = updated;
    ref.read(pinUpdatesProvider.notifier).updated(updated);
    ref.read(boardsVersionProvider.notifier).bump();
    widget.onChanged?.call(updated);
  }

  void _bumpCount(int boardId, int delta) {
    final boards = _boards;
    if (boards == null) return;
    _boards = [
      for (final b in boards)
        b.id == boardId
            ? b.copyWith(
                pinsCount: (b.pinsCount + delta).clamp(0, 1 << 30),
                covers: delta > 0
                    ? [
                        _pin.imageUrl,
                        ...b.covers.where((c) => c != _pin.imageUrl),
                      ].take(3).toList()
                    : b.covers.where((c) => c != _pin.imageUrl).toList(),
              )
            : b,
    ];
  }

  Future<void> _toggle(Board board) async {
    if (_busyId != null || _busyNew) return;
    final wasIn = _saved.contains(board.id);
    // Optimistic update, rolled back on error.
    setState(() {
      _error = null;
      _busyId = board.id;
      wasIn ? _saved.remove(board.id) : _saved.add(board.id);
      _bumpCount(board.id, wasIn ? -1 : 1);
    });
    final repo = ref.read(boardsRepositoryProvider);
    try {
      final res = wasIn
          ? await repo.unsavePin(board.id, _pin.id)
          : await repo.savePin(board.id, _pin.id);
      final updated = res ?? _pin.copyWith(savedBoardIds: _saved.toList());
      if (!mounted) return;
      setState(() => _saved = {...updated.savedBoardIds});
      _publish(updated);
      showSnack('${wasIn ? S.removedFrom : S.savedTo} ${board.name}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        wasIn ? _saved.add(board.id) : _saved.remove(board.id);
        _bumpCount(board.id, wasIn ? 1 : -1);
        _error = errorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _createAndSave() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busyNew || _busyId != null) return;
    setState(() {
      _busyNew = true;
      _error = null;
    });
    try {
      final board = await ref.read(boardsRepositoryProvider).create(name: name);
      final updated = await ref
          .read(boardsRepositoryProvider)
          .savePin(board.id, _pin.id);
      if (!mounted) return;
      setState(() {
        _boards = [
          board.copyWith(pinsCount: 1, covers: [_pin.imageUrl]),
          ...?_boards,
        ];
        _saved = {...updated.savedBoardIds};
        _creating = false;
        _name.clear();
      });
      _publish(updated);
      showSnack('${S.savedTo} ${board.name}');
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busyNew = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final boards = _boards;

    Widget list;
    if (_loadError != null) {
      list = ErrorView(error: _loadError!, onRetry: _load, compact: true);
    } else if (boards == null) {
      list = ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: const [
          Skeleton(height: 56, radius: 12),
          SizedBox(height: 8),
          Skeleton(height: 56, radius: 12),
        ],
      );
    } else if (boards.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          S.noBoards,
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted),
        ),
      );
    } else {
      list = ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: boards.length,
        itemBuilder: (context, i) => _BoardRow(
          board: boards[i],
          saved: _saved.contains(boards[i].id),
          busy: _busyId == boards[i].id,
          onTap: () => _toggle(boards[i]),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                S.chooseBoard,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
            Flexible(child: list),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppPalette.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Divider(height: 17, color: p.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: _creating ? _newBoardForm() : _newBoardButton(p),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newBoardButton(AppPalette p) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => setState(() => _creating = true),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 12),
          const Text(
            S.newBoard,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    ),
  );

  Widget _newBoardForm() => Padding(
    padding: const EdgeInsets.all(4),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _name,
            autofocus: true,
            enabled: !_busyNew,
            textInputAction: TextInputAction.done,
            maxLength: 60,
            decoration: const InputDecoration(
              hintText: S.newBoardName,
              counterText: '',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _createAndSave(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _name.text.trim().isEmpty || _busyNew || _busyId != null
              ? null
              : _createAndSave,
          child: _busyNew
              ? const Spinner(size: 18, color: Colors.white)
              : const Text(S.create),
        ),
      ],
    ),
  );
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({
    required this.board,
    required this.saved,
    required this.busy,
    required this.onTap,
  });

  final Board board;
  final bool saved;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.square(
                dimension: 48,
                child: board.covers.isEmpty
                    ? ColoredBox(
                        color: p.surface2,
                        child: Icon(Icons.dashboard_outlined, color: p.muted),
                      )
                    : AppImage(board.covers.first, placeholder: p.surface2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      board.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (board.isPrivate) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.lock_rounded, size: 15, color: p.muted),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: saved ? p.text : AppPalette.accent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: busy
                  ? Spinner(size: 16, color: saved ? p.bg : Colors.white)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (saved) ...[
                          Icon(Icons.check_rounded, size: 16, color: p.bg),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          saved ? S.saved : S.saveAction,
                          style: TextStyle(
                            color: saved ? p.bg : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
