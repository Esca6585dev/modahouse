import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/providers.dart';
import '../widgets/app_image.dart';
import '../widgets/states.dart';

/// Every contest, running first.
final contestsProvider = FutureProvider.autoDispose<List<Contest>>(
  (ref) => ref.watch(contestsRepositoryProvider).list(),
);

/// Running contests (the banner on the Top 10 screen).
final activeContestsProvider = FutureProvider.autoDispose<List<Contest>>(
  (ref) =>
      ref.watch(contestsRepositoryProvider).list(status: ContestStatus.active),
);

String contestStatusLabel(ContestStatus s) => switch (s) {
  ContestStatus.active => S.contestActive,
  ContestStatus.upcoming => S.contestUpcoming,
  ContestStatus.finished => S.contestFinished,
};

/// "Gutarýar / Başlanýar / Gutardy: `date`".
String contestTimeLine(Contest c) => switch (c.status) {
  ContestStatus.active => S.contestEnds(formatDateTime(c.endsAt)),
  ContestStatus.upcoming => S.contestStarts(formatDateTime(c.startsAt)),
  ContestStatus.finished => S.contestEnded(formatDateTime(c.endsAt)),
};

/// Prize in words plus the teňňe the winner gets.
String contestPrizeLine(Contest c) => [
  if (c.prize.isNotEmpty) c.prize,
  if (c.prizeCoins > 0) '+${S.coinsCount(c.prizeCoins)}',
].join(' · ');

/// "Dowam edýär" (green) / "Ýakynda" (gold) / "Tamamlandy" (grey).
class ContestStatusBadge extends StatelessWidget {
  const ContestStatusBadge({super.key, required this.status});

  final ContestStatus status;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = switch (status) {
      ContestStatus.active => p.success,
      ContestStatus.upcoming => AppPalette.gold,
      ContestStatus.finished => p.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            contestStatusLabel(status),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// A red banner on the Top 10 screen while a contest is running.
class ActiveContestBanner extends ConsumerWidget {
  const ActiveContestBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(activeContestsProvider).value ?? const <Contest>[];
    if (list.isEmpty) return const SizedBox.shrink();
    final c = list.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppPalette.gutter,
        10,
        AppPalette.gutter,
        0,
      ),
      child: Material(
        key: const Key('active-contest-banner'),
        color: AppPalette.of(context).tint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(
            list.length == 1 ? '/contests/${c.id}' : '/contests',
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.how_to_vote_rounded,
                  color: AppPalette.accent,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.contestActiveBanner(c.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      Text(
                        [
                          contestPrizeLine(c),
                          contestTimeLine(c),
                        ].where((e) => e.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppPalette.of(context).muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Ýaryşlar": every contest with its status, prize and end time.
class ContestsScreen extends ConsumerWidget {
  const ContestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contests = ref.watch(contestsProvider);
    final Widget body;
    if (contests.hasError && !contests.hasValue) {
      body = ErrorView(
        error: contests.error!,
        onRetry: () => ref.invalidate(contestsProvider),
      );
    } else if (!contests.hasValue) {
      body = const LoadingView();
    } else if (contests.value!.isEmpty) {
      body = ListView(
        children: const [
          EmptyView(
            icon: Icons.how_to_vote_outlined,
            title: S.contestsEmpty,
            text: S.contestsEmptyText,
          ),
        ],
      );
    } else {
      final list = contests.value!;
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppPalette.gutter,
          8,
          AppPalette.gutter,
          24,
        ),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => ContestCard(contest: list[i]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text(S.contests)),
      body: RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: () => ref.refresh(contestsProvider.future),
        child: body,
      ),
    );
  }
}

class ContestCard extends StatelessWidget {
  const ContestCard({super.key, required this.contest});

  final Contest contest;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = contest;
    final prize = contestPrizeLine(c);
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppPalette.cardRadius),
        side: BorderSide(color: p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppPalette.cardRadius),
        onTap: () => context.push('/contests/${c.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ContestStatusBadge(status: c.status),
                  const Spacer(),
                  Text(
                    '${S.entriesCount(c.entriesCount)} · '
                    '${S.votesCount(c.votesCount)}',
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                c.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              if (prize.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.card_giftcard_rounded,
                      size: 17,
                      color: AppPalette.accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        prize,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: p.muted),
                  const SizedBox(width: 6),
                  Text(
                    contestTimeLine(c),
                    style: TextStyle(color: p.muted, fontSize: 13),
                  ),
                ],
              ),
              if (c.isFinished && c.winner != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_rounded,
                      size: 17,
                      color: AppPalette.gold,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${S.contestWinner}: '
                        '${c.winner!.pin.author.displayName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One contest: description, prize, ranked entries with votes, "Ses ber",
/// "Gatnaş" / "Çykmak" and the winner once finished.
class ContestDetailScreen extends ConsumerStatefulWidget {
  const ContestDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ContestDetailScreen> createState() =>
      _ContestDetailScreenState();
}

class _ContestDetailScreenState extends ConsumerState<ContestDetailScreen> {
  ContestDetail? _detail;
  Object? _error;
  bool _busy = false;
  int? _voting;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(contestsRepositoryProvider).get(widget.id);
      if (mounted) {
        setState(() {
          _detail = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  bool _requireLogin() {
    if (ref.read(authProvider).isLoggedIn) return true;
    context.push(
      '/login?from=${Uri.encodeComponent('/contests/${widget.id}')}',
    );
    return false;
  }

  void _changed() {
    ref.invalidate(contestsProvider);
    ref.invalidate(activeContestsProvider);
  }

  Future<void> _vote(ContestEntry e) async {
    if (_voting != null || !_requireLogin()) return;
    final ok = await confirmDialog(
      context,
      title: S.voteConfirmTitle,
      text: S.voteConfirmText,
      confirm: S.vote,
      danger: false,
    );
    if (!ok || !mounted) return;
    setState(() => _voting = e.pin.id);
    try {
      await ref.read(contestsRepositoryProvider).vote(widget.id, e.pin.id);
      showSnack(S.voteDone);
      _changed();
      await _load();
    } catch (err) {
      // One vote per user, own posts, new accounts: the server explains.
      showError(err);
    } finally {
      if (mounted) setState(() => _voting = null);
    }
  }

  Future<void> _enter(Contest c) async {
    if (_busy || !_requireLogin()) return;
    final me = ref.read(authProvider).user;
    if (me == null) return;
    final pin = await showModalBottomSheet<Pin>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ContestPostPicker(username: me.username, contest: c),
    );
    if (pin == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(contestsRepositoryProvider).enter(widget.id, pin.id);
      showSnack(S.contestEntered);
      _changed();
      await _load();
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    final ok = await confirmDialog(
      context,
      title: S.leaveContestConfirm,
      text: S.leaveContestText,
      confirm: S.leaveContest,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(contestsRepositoryProvider).leave(widget.id);
      showSnack(S.contestLeft);
      _changed();
      await _load();
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(S.contests)),
        body: _error == null
            ? const LoadingView()
            : ErrorView(error: _error!, onRetry: _load),
      );
    }
    final c = d.contest;
    final me = ref.watch(authProvider).user;
    final p = AppPalette.of(context);
    final cats = ref.watch(categoriesProvider).value;
    final prize = contestPrizeLine(c);

    return Scaffold(
      appBar: AppBar(title: Text(c.title)),
      body: RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppPalette.gutter,
                8,
                AppPalette.gutter,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ContestStatusBadge(status: c.status),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            contestTimeLine(c),
                            style: TextStyle(color: p.muted, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      c.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    if (c.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        c.description,
                        style: const TextStyle(fontSize: 15, height: 1.45),
                      ),
                    ],
                    if (prize.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.tint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.card_giftcard_rounded,
                              color: AppPalette.accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    S.contestPrize,
                                    style: TextStyle(
                                      color: p.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    prize,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (c.category.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        S.contestCategoryOnly(categoryName(c.category, cats)),
                        style: TextStyle(color: p.muted, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${S.entriesCount(c.entriesCount)} · '
                      '${S.votesCount(c.votesCount)}',
                      style: TextStyle(color: p.muted, fontSize: 13),
                    ),
                    if (c.isFinished && c.winner != null) ...[
                      const SizedBox(height: 14),
                      _WinnerCard(entry: c.winner!),
                    ],
                    if (!c.isFinished) ...[
                      const SizedBox(height: 14),
                      if (c.entered)
                        OutlinedButton.icon(
                          key: const Key('contest-leave'),
                          onPressed: _busy ? null : _leave,
                          icon: const Icon(Icons.logout_rounded, size: 19),
                          label: const Text(S.leaveContest),
                        )
                      else
                        FilledButton.icon(
                          key: const Key('contest-enter'),
                          onPressed: _busy ? null : () => _enter(c),
                          icon: _busy
                              ? const Spinner(size: 18, color: Colors.white)
                              : const Icon(Icons.add_rounded, size: 20),
                          label: const Text(S.enterContest),
                        ),
                    ],
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            if (d.entries.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyView(
                  icon: Icons.photo_library_outlined,
                  title: S.contestNoEntries,
                  text: S.contestNoEntriesText,
                  compact: true,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppPalette.gutter,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.56,
                  ),
                  itemCount: d.entries.length,
                  itemBuilder: (_, i) {
                    final e = d.entries[i];
                    final own =
                        e.pin.id == c.myEntryPinId ||
                        (me != null && e.pin.author.id == me.id);
                    return ContestEntryTile(
                      entry: e,
                      own: own,
                      myVote: c.myVotePinId == e.pin.id,
                      voteButton: ContestVoteButton(
                        pinId: e.pin.id,
                        isMyVote: c.myVotePinId == e.pin.id,
                        busy: _voting == e.pin.id,
                        onPressed:
                            c.isActive && !c.voted && !own && _voting == null
                            ? () => _vote(e)
                            : null,
                      ),
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 24 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.entry});

  final ContestEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pin = entry.pin;
    return Material(
      key: const Key('contest-winner'),
      color: Color.alphaBlend(AppPalette.gold.withValues(alpha: 0.12), p.card),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppPalette.gold.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/pin/${pin.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 72,
                  child: AppImage(
                    pin.imageUrl,
                    cacheWidth: 56,
                    placeholder: parseHexColor(pin.color, p.surface),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: AppPalette.gold,
                          size: 20,
                        ),
                        SizedBox(width: 4),
                        Text(
                          S.contestWinner,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pin.author.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${pin.title} · ${S.votesCount(entry.votes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One ranked post: image with the place, votes and the vote button.
class ContestEntryTile extends StatelessWidget {
  const ContestEntryTile({
    super.key,
    required this.entry,
    required this.voteButton,
    this.own = false,
    this.myVote = false,
  });

  final ContestEntry entry;
  final Widget voteButton;
  final bool own;
  final bool myVote;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pin = entry.pin;
    final medal = switch (entry.rank) {
      1 => AppPalette.gold,
      2 => AppPalette.silver,
      3 => AppPalette.bronze,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/pin/${pin.id}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppPalette.radius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(
                    pin.imageUrl,
                    cacheWidth: 240,
                    placeholder: parseHexColor(pin.color, p.surface),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: medal ?? Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '${entry.rank}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (own || myVote)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: own ? AppPalette.accent : p.success,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          own ? S.yourEntry : S.yourVote,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          pin.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '@${pin.author.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.muted, fontSize: 12),
              ),
            ),
            Icon(Icons.how_to_vote_outlined, size: 14, color: p.muted),
            const SizedBox(width: 3),
            Text(
              '${entry.votes}',
              semanticsLabel: S.votesCount(entry.votes),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        voteButton,
      ],
    );
  }
}

/// "Ses ber": red while a vote can be given, green "Siziň sesiňiz" on the
/// post I voted for, disabled otherwise (already voted, own post, not
/// running).
class ContestVoteButton extends StatelessWidget {
  const ContestVoteButton({
    super.key,
    required this.pinId,
    required this.onPressed,
    this.isMyVote = false,
    this.busy = false,
  });

  final int pinId;
  final VoidCallback? onPressed;
  final bool isMyVote;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final style = FilledButton.styleFrom(
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
    );
    if (isMyVote) {
      return FilledButton.icon(
        key: Key('vote-$pinId'),
        style: style.copyWith(
          backgroundColor: WidgetStatePropertyAll(p.success),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
        ),
        onPressed: null,
        icon: const Icon(Icons.check_rounded, size: 18),
        label: const Text(S.voted),
      );
    }
    return FilledButton(
      key: Key('vote-$pinId'),
      style: style,
      onPressed: busy ? null : onPressed,
      child: busy
          ? const Spinner(size: 16, color: Colors.white)
          : const Text(S.vote),
    );
  }
}

/// Bottom sheet listing my posts (of the contest's category when set);
/// pops the chosen [Pin].
class ContestPostPicker extends ConsumerStatefulWidget {
  const ContestPostPicker({
    super.key,
    required this.username,
    required this.contest,
  });

  final String username;
  final Contest contest;

  @override
  ConsumerState<ContestPostPicker> createState() => _ContestPostPickerState();
}

class _ContestPostPickerState extends ConsumerState<ContestPostPicker> {
  List<Pin>? _pins;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final page = await ref
          .read(usersRepositoryProvider)
          .pins(widget.username, 1, limit: 60);
      final cat = widget.contest.category;
      if (!mounted) return;
      setState(
        () => _pins = [
          for (final pin in page.items)
            if (cat.isEmpty || pin.category == cat) pin,
        ],
      );
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pins = _pins;
    final cats = ref.watch(categoriesProvider).value;
    final cat = widget.contest.category;
    final Widget body;
    if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load, compact: true);
    } else if (pins == null) {
      body = const Padding(padding: EdgeInsets.all(32), child: LoadingView());
    } else if (pins.isEmpty) {
      body = const EmptyView(
        icon: Icons.photo_library_outlined,
        title: S.noPostsForContest,
        compact: true,
      );
    } else {
      body = GridView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: pins.length,
        itemBuilder: (context, i) {
          final pin = pins[i];
          return Semantics(
            button: true,
            label: pin.title,
            excludeSemantics: true,
            child: GestureDetector(
              key: Key('contest-pick-${pin.id}'),
              onTap: () => Navigator.of(context).pop(pin),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppImage(
                  pin.imageUrl,
                  cacheWidth: 130,
                  placeholder: parseHexColor(pin.color, p.surface),
                ),
              ),
            ),
          );
        },
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              S.pickPostForContest,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (cat.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                S.contestCategoryOnly(categoryName(cat, cats)),
                style: TextStyle(color: p.muted),
              ),
            ),
          Flexible(child: body),
        ],
      ),
    );
  }
}
