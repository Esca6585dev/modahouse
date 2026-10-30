import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/pins_repository.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/paged_controller.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import '../state/prefs.dart';
import '../state/server.dart';
import '../state/shop_state.dart';
import '../widgets/category_chips.dart';
import '../widgets/pin_grid.dart';
import '../widgets/states.dart';
import '../widgets/stories_row.dart';
import '../widgets/top_actions.dart';

/// Home feed modes: "Saňa", "Yzarlanýanlar", "Harytlar".
enum FeedMode { forYou, following, products }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _category;
  FeedMode _mode = FeedMode.forYou;
  late PagedController<Pin> _feed = _makeFeed();
  final _scroll = ScrollController();

  PagedController<Pin> _makeFeed() {
    final repo = ref.read(pinsRepositoryProvider);
    final category = _category;
    final mode = _mode;
    final posts = ref.read(feedViewProvider) == FeedView.instagram;
    // Signed-in users get the personal ranking (`feed=foryou`); guests keep
    // the newest-first feed.
    final personal =
        mode == FeedMode.forYou && ref.read(authProvider).isLoggedIn;
    return PagedController(
      (page) => repo.list(
        category: category,
        following: mode == FeedMode.following,
        forYou: personal,
        type: mode == FeedMode.products ? PinType.products : PinType.any,
        withComments: posts,
        page: page,
      ),
    );
  }

  void _reset() {
    final old = _feed;
    setState(() => _feed = _makeFeed());
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _feed.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _setMode(FeedMode m) {
    if (m == _mode) return;
    _mode = m;
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    // Viewer-specific fields change with the account: reload the feed.
    ref.listen(currentUserIdProvider, (prev, next) {
      if (prev == next) return;
      if (next == null && _mode == FeedMode.following) _mode = FeedMode.forYou;
      _reset();
    });
    ref.listen(
      pinUpdatesProvider.select((u) => u.created),
      (_, _) => _feed.refresh(),
    );
    ref.listen(feedViewProvider, (prev, next) {
      if (prev != next) _reset();
    });
    // Moved to another server (admin panel or Sazlamalar → Serwer).
    ref.listen(serverProvider.select((s) => s.apiUrl), (prev, next) {
      if (prev != next) _reset();
    });
    final loggedIn = ref.watch(authProvider.select((s) => s.isLoggedIn));
    final view = ref.watch(feedViewProvider);
    final p = AppPalette.of(context);
    final empty = switch (_mode) {
      FeedMode.following => EmptyView(
        icon: Icons.people_outline_rounded,
        title: S.emptyFollowingTitle,
        text: S.emptyFollowingText,
        action: FilledButton(
          onPressed: () => _setMode(FeedMode.forYou),
          child: const Text(S.browseIdeas),
        ),
      ),
      FeedMode.products => const EmptyView(
        icon: Icons.shopping_bag_outlined,
        title: S.emptyProductsTitle,
        text: S.emptyProductsText,
      ),
      FeedMode.forYou => const EmptyView(
        icon: Icons.image_outlined,
        title: S.emptyFeedTitle,
        text: S.emptyFeedText,
      ),
    };

    return Scaffold(
      body: RefreshIndicator(
        color: AppPalette.accent,
        edgeOffset: 64,
        onRefresh: () {
          if (ref.read(categoriesProvider).hasError) {
            ref.invalidate(categoriesProvider);
          }
          ref.read(storiesProvider.notifier).reload();
          return _feed.refresh();
        },
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              toolbarHeight: 60,
              titleSpacing: AppPalette.gutter,
              title: const LogoWordmark(height: 42),
              actions: [
                IconButton(
                  key: const Key('feed-view-toggle'),
                  tooltip: view == FeedView.pinterest
                      ? S.viewInstagram
                      : S.viewPinterest,
                  onPressed: () => ref
                      .read(feedViewProvider.notifier)
                      .set(
                        view == FeedView.pinterest
                            ? FeedView.instagram
                            : FeedView.pinterest,
                      ),
                  icon: Icon(
                    view == FeedView.pinterest
                        ? Icons.view_agenda_outlined
                        : Icons.dashboard_outlined,
                  ),
                ),
                IconButton(
                  tooltip: S.top10Title,
                  onPressed: () => context.push('/top'),
                  icon: const Icon(Icons.emoji_events_outlined),
                ),
                const NotificationsButton(),
                const ChatsButton(),
                const CartButton(),
                const SizedBox(width: 6),
              ],
            ),
            const SliverToBoxAdapter(child: StoriesRow()),
            SliverToBoxAdapter(child: Divider(color: p.border, height: 1)),
            SliverToBoxAdapter(
              child: FeedTabs(
                mode: _mode,
                showFollowing: loggedIn,
                onChanged: _setMode,
              ),
            ),
            SliverToBoxAdapter(
              child: CategoryChips(
                selected: _category,
                onSelected: (c) {
                  if (c == _category) return;
                  _category = c;
                  _reset();
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            if (view == FeedView.instagram)
              PostListSliver(controller: _feed, empty: empty)
            else
              PinGridSliver(controller: _feed, empty: empty),
          ],
        ),
      ),
    );
  }
}

/// "Saňa" / "Yzarlanýanlar" / "Harytlar" tabs (Pinterest-style underline).
class FeedTabs extends StatelessWidget {
  const FeedTabs({
    super.key,
    required this.mode,
    required this.onChanged,
    this.showFollowing = true,
  });

  final FeedMode mode;
  final ValueChanged<FeedMode> onChanged;
  final bool showFollowing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget tab(String label, FeedMode m) {
      final active = m == mode;
      return Semantics(
        button: true,
        selected: active,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(m),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 15.5,
                    color: active ? p.text : p.muted,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 3,
                  width: active ? 28 : 0,
                  decoration: BoxDecoration(
                    color: p.text,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          tab(S.feedForYou, FeedMode.forYou),
          if (showFollowing) tab(S.feedFollowing, FeedMode.following),
          tab(S.feedProducts, FeedMode.products),
        ],
      ),
    );
  }
}
