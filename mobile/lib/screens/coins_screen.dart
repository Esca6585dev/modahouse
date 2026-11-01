import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/providers.dart';
import '../widgets/states.dart';

/// `GET /me/coins`.
final myCoinsProvider = FutureProvider.autoDispose<CoinsInfo>(
  (ref) => ref.watch(coinsRepositoryProvider).mine(),
);

String coinRequestStatusLabel(CoinRequestStatus s) => switch (s) {
  CoinRequestStatus.pending => S.coinRequestPending,
  CoinRequestStatus.approved => S.coinRequestApproved,
  CoinRequestStatus.rejected => S.coinRequestRejected,
};

String coinKindLabel(String kind) => switch (kind) {
  'topup' => S.coinKindTopup,
  'boost' => S.coinKindBoost,
  'prize' => S.coinKindPrize,
  'admin' => S.coinKindAdmin,
  _ => kind,
};

/// "Teňňelerim": balance, how to pay, packages to request, requests and
/// history. There is no online payment: the user pays the way an admin
/// set, sends a request and the admin approves it.
class CoinsScreen extends ConsumerWidget {
  const CoinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(myCoinsProvider);
    // Keep the balance on the signed-in account in step.
    ref.listen(myCoinsProvider, (_, next) {
      final info = next.value;
      final me = ref.read(authProvider).user;
      if (info != null && me != null && me.coins != info.balance) {
        ref.read(authProvider.notifier).setUser(me.withCoins(info.balance));
      }
    });

    final Widget body;
    if (coins.hasError && !coins.hasValue) {
      body = ErrorView(
        error: coins.error!,
        onRetry: () => ref.invalidate(myCoinsProvider),
      );
    } else if (!coins.hasValue) {
      body = const LoadingView();
    } else {
      final info = coins.value!;
      body = ListView(
        padding: const EdgeInsets.fromLTRB(
          AppPalette.gutter,
          8,
          AppPalette.gutter,
          32,
        ),
        children: [
          _BalanceCard(info: info),
          const SizedBox(height: 14),
          _PaymentCard(info: info),
          const SizedBox(height: 20),
          const _Heading(S.coinPackages),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final pkg in info.packages)
                CoinPackageTile(
                  package: pkg,
                  onTap: () => _request(context, ref, pkg),
                ),
            ],
          ),
          if (info.requests.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _Heading(S.coinRequests),
            for (final r in info.requests) _RequestRow(request: r),
          ],
          const SizedBox(height: 22),
          const _Heading(S.coinHistory),
          if (info.history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                S.coinHistoryEmpty,
                style: TextStyle(color: AppPalette.of(context).muted),
              ),
            )
          else
            for (final t in info.history) _HistoryRow(tx: t),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text(S.myCoins)),
      body: RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: () => ref.refresh(myCoinsProvider.future),
        child: body,
      ),
    );
  }

  Future<void> _request(
    BuildContext context,
    WidgetRef ref,
    CoinPackage pkg,
  ) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => CoinRequestDialog(package: pkg),
    );
    if (note == null) return;
    try {
      await ref.read(coinsRepositoryProvider).request(pkg.coins, note: note);
      showSnack(S.coinRequestSent);
      ref.invalidate(myCoinsProvider);
    } catch (e) {
      showError(e);
    }
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
    ),
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.info});

  final CoinsInfo info;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppPalette.cardRadius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD7263D), Color(0xFF8A1424)],
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.toll_rounded,
            color: AppPalette.gold,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.coinsBalance,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
              Text(
                S.coinsCount(info.balance),
                key: const Key('coins-balance'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                ),
              ),
              Text(
                S.coinRate(info.rate),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The admin's payment instructions, shown prominently.
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.info});

  final CoinsInfo info;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final text = info.paymentInfo.trim();
    return Container(
      key: const Key('coins-payment'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppPalette.accent,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  S.coinsHowToPay,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              if (text.isNotEmpty)
                IconButton(
                  tooltip: S.copy,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    showSnack(S.paymentInfoCopied);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            text.isEmpty ? S.coinsHowToPayEmpty : text,
            style: TextStyle(
              fontSize: text.isEmpty ? 14 : 16,
              fontWeight: text.isEmpty ? FontWeight.w500 : FontWeight.w700,
              height: 1.4,
              color: text.isEmpty ? p.muted : p.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(S.coinsSteps, style: TextStyle(color: p.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

/// A package: teňňe and the price in manat.
class CoinPackageTile extends StatelessWidget {
  const CoinPackageTile({
    super.key,
    required this.package,
    required this.onTap,
  });

  final CoinPackage package;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      width: 104,
      child: Semantics(
        button: true,
        label: '${S.coinsCount(package.coins)}, ${S.manat(package.price)}',
        excludeSemantics: true,
        child: Material(
          key: Key('coin-package-${package.coins}'),
          color: p.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: p.border, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  const Icon(Icons.toll_rounded, color: AppPalette.gold),
                  const SizedBox(height: 4),
                  Text(
                    '${package.coins}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    S.manat(package.price),
                    style: const TextStyle(
                      color: AppPalette.accent,
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

/// Confirms a package with an optional note; pops the note (or null).
class CoinRequestDialog extends StatefulWidget {
  const CoinRequestDialog({super.key, required this.package});

  final CoinPackage package;

  @override
  State<CoinRequestDialog> createState() => _CoinRequestDialogState();
}

class _CoinRequestDialogState extends State<CoinRequestDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.buyCoinsTitle(widget.package.coins)),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.buyCoinsText(widget.package.price)),
        const SizedBox(height: 12),
        TextField(
          key: const Key('coin-note'),
          controller: _note,
          maxLength: 300,
          maxLines: 2,
          minLines: 1,
          decoration: const InputDecoration(
            labelText: S.coinNote,
            hintText: S.coinNoteHint,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.of(context).text,
        ),
        child: const Text(S.cancel),
      ),
      FilledButton(
        key: const Key('coin-request-send'),
        onPressed: () => Navigator.of(context).pop(_note.text),
        child: const Text(S.sendRequest),
      ),
    ],
  );
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request});

  final CoinRequest request;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final r = request;
    final color = switch (r.status) {
      CoinRequestStatus.pending => AppPalette.gold,
      CoinRequestStatus.approved => p.success,
      CoinRequestStatus.rejected => AppPalette.danger,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(switch (r.status) {
        CoinRequestStatus.pending => Icons.hourglass_top_rounded,
        CoinRequestStatus.approved => Icons.check_circle_rounded,
        CoinRequestStatus.rejected => Icons.cancel_rounded,
      }, color: color),
      title: Text(
        '${S.coinsCount(r.coins)} · ${S.manat(r.price)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          formatDateTime(r.decidedAt ?? r.createdAt),
          if (r.note.isNotEmpty) r.note,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          coinRequestStatusLabel(r.status),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.tx});

  final CoinTx tx;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final plus = tx.amount >= 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: p.surface,
        child: Icon(
          switch (tx.kind) {
            'boost' => Icons.trending_up_rounded,
            'prize' => Icons.workspace_premium_rounded,
            'admin' => Icons.admin_panel_settings_outlined,
            _ => Icons.add_card_rounded,
          },
          color: p.text,
          size: 20,
        ),
      ),
      title: Text(
        tx.note.isEmpty ? coinKindLabel(tx.kind) : tx.note,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${coinKindLabel(tx.kind)} · ${formatDateTime(tx.createdAt)}',
      ),
      trailing: Text(
        '${plus ? '+' : ''}${tx.amount}',
        style: TextStyle(
          color: plus ? p.success : AppPalette.danger,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}
