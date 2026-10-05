import 'dart:math' as math;

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
import '../state/paged_controller.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import '../widgets/avatar.dart';
import '../widgets/board_card.dart';
import '../widgets/board_form.dart';
import '../widgets/follow_button.dart';
import '../widgets/pin_grid.dart';
import '../widgets/states.dart';

/// The "Profil" tab: the logged-in user's own profile.
class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).user;
    if (me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(S.tabProfile)),
        body: const LoginPrompt(text: S.loginPromptProfile, from: '/profile', icon: Icons.person_outline_rounded),
      );
    }
    return ProfileView(key: ValueKey('me-${me.username}'), username: me.username, isTab: true);
  }
}

/// `/user/:username`.
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context) => ProfileView(key: ValueKey('u-$username'), username: username);
}

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key, required this.username, this.isTab = false});

  final String username;
  final bool isTab;

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  Profile? _profile;
  Object? _error;
  int _tab = 0;
  late final PagedController<Pin> _pins;
  List<Board>? _boards;
  Object? _boardsError;

  String get username => widget.username;

  @override
  void initState() {
    super.initState();
    _pins = PagedController((page) => ref.read(usersRepositoryProvider).pins(username, page));
    _loadProfile();
    _loadBoards();
  }

  @override
  void dispose() {
    _pins.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _error = null);
    try {
      final p = await ref.read(usersRepositoryProvider).profile(username);
      if (mounted) setState(() => _profile = p);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadBoards() async {
    setState(() => _boardsError = null);
    try {
      final b = await ref.read(usersRepositoryProvider).boards(username);
      if (mounted) setState(() => _boards = b);
    } catch (e) {
      if (mounted) setState(() => _boardsError = e);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadProfile(), _loadBoards(), _pins.refresh()]);
  }

  Future<void> _createBoard() async {
    final board = await showBoardForm(context);
    if (board == null) return;
    showSnack(S.boardCreated);
    await _loadBoards();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(boardsVersionProvider, (_, _) => _loadBoards());
    ref.listen(pinUpdatesProvider.select((u) => u.created), (_, _) {
      _pins.refresh();
      _loadProfile();
    });
    // A pin was deleted somewhere: refresh the counters and board covers.
    ref.listen(pinUpdatesProvider.select((u) => u.deleted.length), (_, _) {
      _loadProfile();
      _loadBoards();
    });
    ref.listen(authProvider.select((s) => s.user), (prev, next) {
      if (prev != next && next?.username == username) _loadProfile();
    });

    final profile = _profile;
    final canPop = context.canPop() && !widget.isTab;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: widget.isTab ? const Text(S.tabProfile) : null),
        body: _error == null
            ? const LoadingView()
            : (_error is ApiException && (_error as ApiException).isNotFound)
                ? const EmptyView(icon: Icons.person_off_outlined, title: S.userNotFound)
                : ErrorView(error: _error!, onRetry: _loadProfile),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: canPop,
        actions: [
          if (profile.isMe)
            IconButton(
              tooltip: S.settings,
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(profile)),
            SliverToBoxAdapter(child: _tabs()),
            if (_tab == 0)
              PinGridSliver(
                controller: _pins,
                empty: EmptyView(
                  icon: Icons.image_outlined,
                  title: S.noPinsTitle,
                  text: profile.isMe ? S.noOwnPinsText : S.noUserPinsText,
                  compact: true,
                  action: profile.isMe
                      ? FilledButton(onPressed: () => context.go('/create'), child: const Text(S.createPin))
                      : null,
                ),
              )
            else
              ..._boardSlivers(profile),
            SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }

  Widget _header(Profile profile) {
    final p = AppPalette.of(context);
    final enc = Uri.encodeComponent(profile.username);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppPalette.gutter, 0, AppPalette.gutter, 8),
      child: Column(
        children: [
          UserAvatar(user: profile, size: 104),
          const SizedBox(height: 12),
          Text(
            profile.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text('@${profile.username}', style: TextStyle(color: p.muted, fontSize: 15)),
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(profile.bio, textAlign: TextAlign.center, style: const TextStyle(height: 1.4)),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatButton(
                text: S.followersCount(compactCount(profile.followersCount)),
                onTap: () => context.push('/user/$enc/followers'),
              ),
              Text(' · ', style: TextStyle(color: p.muted)),
              _StatButton(
                text: S.followingCount(compactCount(profile.followingCount)),
                onTap: () => context.push('/user/$enc/following'),
              ),
              Text(' · ', style: TextStyle(color: p.muted)),
              Text(S.pinsCount(compactCount(profile.pinsCount)), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          if (profile.isMe)
            ElevatedButton(onPressed: () => context.push('/settings'), child: const Text(S.editProfile))
          else
            FollowButton(
              username: profile.username,
              isFollowing: profile.isFollowing,
              onChanged: (following, updated) {
                setState(() {
                  _profile = updated ??
                      profile.copyWith(
                        isFollowing: following,
                        followersCount: math.max(
                          0,
                          profile.followersCount + (following == profile.isFollowing ? 0 : (following ? 1 : -1)),
                        ),
                      );
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _tabs() {
    final p = AppPalette.of(context);
    Widget tab(String label, int index) {
      final active = _tab == index;
      return Semantics(
        button: true,
        selected: active,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _tab = index),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: active ? p.text : p.muted)),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 3,
                  width: active ? 40 : 0,
                  decoration: BoxDecoration(color: p.text, borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [tab(S.tabCreated, 0), const SizedBox(width: 8), tab(S.tabSaved, 1)],
      ),
    );
  }

  List<Widget> _boardSlivers(Profile profile) {
    final boards = _boards;
    final slivers = <Widget>[];
    if (profile.isMe) {
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppPalette.gutter, 0, AppPalette.gutter, 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _createBoard,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(S.newBoard),
            ),
          ),
        ),
      ));
    }
    if (_boardsError != null && boards == null) {
      slivers.add(SliverToBoxAdapter(child: ErrorView(error: _boardsError!, onRetry: _loadBoards, compact: true)));
    } else if (boards == null) {
      slivers.add(const SliverToBoxAdapter(child: LoadingView()));
    } else if (boards.isEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: EmptyView(
          icon: Icons.dashboard_outlined,
          title: S.noBoardsTitle,
          text: profile.isMe ? S.noOwnBoardsText : S.noUserBoardsText,
          compact: true,
        ),
      ));
    } else {
      slivers.add(BoardGridSliver(
        boards: boards,
        onTap: (b) => context.push('/board/${b.id}'),
      ));
    }
    return slivers;
  }
}

class _StatButton extends StatelessWidget {
  const _StatButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
}

/// Responsive 2+ column grid of [BoardCard]s.
class BoardGridSliver extends StatelessWidget {
  const BoardGridSliver({super.key, required this.boards, required this.onTap});

  final List<Board> boards;
  final ValueChanged<Board> onTap;

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppPalette.gutter),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final width = constraints.crossAxisExtent;
            final columns = math.max(2, (width / 260).floor());
            final tile = (width - spacing * (columns - 1)) / columns;
            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: spacing,
                mainAxisSpacing: 20,
                mainAxisExtent: tile * 2 / 3 + 50,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => BoardCard(board: boards[i], onTap: () => onTap(boards[i])),
                childCount: boards.length,
              ),
            );
          },
        ),
      );
}
