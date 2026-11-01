import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/format.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import 'states.dart';

/// "Öňe çykar" for the owner on the pin detail screen, with the running
/// boost's end date.
class BoostSection extends ConsumerWidget {
  const BoostSection({super.key, required this.pin});

  final Pin pin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    // The server sends it to the owner only while the boost runs.
    final until = pin.boostedUntil;
    return Container(
      key: const Key('boost-section'),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: p.tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up_rounded, color: AppPalette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              until != null
                  ? S.boostedUntil(formatDateTime(until))
                  : S.boostText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: until != null ? FontWeight.w700 : FontWeight.w500,
                color: until != null ? p.text : p.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const Key('boost-button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: () => showBoostSheet(context, pin),
            child: const Text(S.boost),
          ),
        ],
      ),
    );
  }
}

Future<void> showBoostSheet(BuildContext context, Pin pin) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BoostSheet(pin: pin),
    );

/// Boost options (days + teňňe from `GET /me/coins`) as tappable tiles;
/// `POST /pins/:id/boost`. When teňňe are short (402) it offers
/// "Teňňelerim".
class BoostSheet extends ConsumerStatefulWidget {
  const BoostSheet({super.key, required this.pin});

  final Pin pin;

  @override
  ConsumerState<BoostSheet> createState() => _BoostSheetState();
}

class _BoostSheetState extends ConsumerState<BoostSheet> {
  CoinsInfo? _info;
  Object? _error;
  int? _busyDays;
  String? _short;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final info = await ref.read(coinsRepositoryProvider).mine();
      if (mounted) setState(() => _info = info);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _syncBalance(int balance) {
    final me = ref.read(authProvider).user;
    if (me != null && me.coins != balance) {
      ref.read(authProvider.notifier).setUser(me.withCoins(balance));
    }
  }

  Future<void> _boost(BoostOption o) async {
    if (_busyDays != null) return;
    setState(() {
      _busyDays = o.days;
      _short = null;
    });
    try {
      final res = await ref
          .read(pinsRepositoryProvider)
          .boost(widget.pin.id, o.days);
      final current =
          ref.read(pinUpdatesProvider).updated[widget.pin.id] ?? widget.pin;
      ref
          .read(pinUpdatesProvider.notifier)
          .updated(current.copyWith(boostedUntil: res.boostedUntil));
      _syncBalance(res.balance);
      showSnack(S.boostDone(formatDateTime(res.boostedUntil)));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (e is ApiException && e.statusCode == 402) {
        if (mounted) setState(() => _short = e.message);
      } else {
        showError(e);
      }
    } finally {
      if (mounted) setState(() => _busyDays = null);
    }
  }

  void _openCoins() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/coins');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final info = _info;
    final Widget content;
    if (_error != null) {
      content = ErrorView(error: _error!, onRetry: _load, compact: true);
    } else if (info == null) {
      content = const Padding(
        padding: EdgeInsets.all(32),
        child: LoadingView(),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.toll_rounded, size: 18, color: p.muted),
              const SizedBox(width: 6),
              Text('${S.coinsBalance}: ', style: TextStyle(color: p.muted)),
              Text(
                S.coinsCount(info.balance),
                key: const Key('boost-balance'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final o in info.boostOptions)
                _BoostTile(
                  option: o,
                  busy: _busyDays == o.days,
                  affordable: o.coins <= info.balance,
                  onTap: _busyDays == null ? () => _boost(o) : null,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            S.boostExtendNote,
            style: TextStyle(color: p.muted, fontSize: 12.5),
          ),
          if (_short != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('boost-short'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppPalette.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _short!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('boost-buy-coins'),
                    onPressed: _openCoins,
                    child: const Text(S.myCoins),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S.boostTitle,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(S.boostText, style: TextStyle(color: p.muted)),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }
}

class _BoostTile extends StatelessWidget {
  const _BoostTile({
    required this.option,
    required this.onTap,
    this.busy = false,
    this.affordable = true,
  });

  final BoostOption option;
  final VoidCallback? onTap;
  final bool busy;
  final bool affordable;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      width: 96,
      child: Semantics(
        button: true,
        label: '${S.boostDays(option.days)}, ${S.coinsCount(option.coins)}',
        excludeSemantics: true,
        child: Material(
          key: Key('boost-${option.days}'),
          color: p.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: affordable
                  ? AppPalette.accent.withValues(alpha: 0.6)
                  : p.border,
              width: 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: busy
                  ? const SizedBox(height: 40, child: Center(child: Spinner()))
                  : Column(
                      children: [
                        Text(
                          S.boostDays(option.days),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          S.coinsCount(option.coins),
                          style: TextStyle(
                            color: affordable ? AppPalette.accent : p.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
