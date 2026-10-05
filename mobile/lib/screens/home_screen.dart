import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/paged_controller.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import '../widgets/category_chips.dart';
import '../widgets/pin_grid.dart';
import '../widgets/states.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _category;
  bool _following = false;
  late PagedController<Pin> _feed = _makeFeed();
  final _scroll = ScrollController();

  PagedController<Pin> _makeFeed() {
    final repo = ref.read(pinsRepositoryProvider);
    final category = _category;
    final following = _following;
    return PagedController(
      (page) => repo.list(category: category, following: following, page: page),
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

  @override
  Widget build(BuildContext context) {
    // Viewer-specific fields change with the account: reload the feed.
    ref.listen(currentUserIdProvider, (prev, next) {
      if (prev == next) return;
      if (next == null) _following = false;
      _reset();
    });
    ref.listen(
      pinUpdatesProvider.select((u) => u.created),
      (_, _) => _feed.refresh(),
    );
    final loggedIn = ref.watch(authProvider.select((s) => s.isLoggedIn));
    final p = AppPalette.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppPalette.accent,
          onRefresh: () {
            if (ref.read(categoriesProvider).hasError) {
              ref.invalidate(categoriesProvider);
            }
            return _feed.refresh();
          },
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppPalette.gutter,
                    12,
                    AppPalette.gutter,
                    12,
                  ),
                  child: Row(
                    children: [
                      const LogoMark(),
                      const SizedBox(width: 8),
                      const Text(
                        S.appName,
                        style: TextStyle(
                          color: AppPalette.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: S.tabSearch,
                        onPressed: () => context.go('/search'),
                        icon: Icon(Icons.search_rounded, color: p.muted),
                      ),
                    ],
                  ),
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
              if (loggedIn)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppPalette.gutter,
                      12,
                      AppPalette.gutter,
                      0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FeedToggle(
                        following: _following,
                        onChanged: (v) {
                          if (v == _following) return;
                          _following = v;
                          _reset();
                        },
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              PinGridSliver(
                controller: _feed,
                empty: _following
                    ? EmptyView(
                        icon: Icons.people_outline_rounded,
                        title: S.emptyFollowingTitle,
                        text: S.emptyFollowingText,
                        action: FilledButton(
                          onPressed: () {
                            _following = false;
                            _reset();
                          },
                          child: const Text(S.browseIdeas),
                        ),
                      )
                    : const EmptyView(
                        icon: Icons.image_outlined,
                        title: S.emptyFeedTitle,
                        text: S.emptyFeedText,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Saňa" / "Yzarlanýanlar" segmented switch.
class FeedToggle extends StatelessWidget {
  const FeedToggle({
    super.key,
    required this.following,
    required this.onChanged,
  });

  final bool following;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget item(String label, bool active, VoidCallback onTap) => Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? p.bg : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: active ? p.text : p.muted,
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(S.feedForYou, !following, () => onChanged(false)),
          const SizedBox(width: 4),
          item(S.feedFollowing, following, () => onChanged(true)),
        ],
      ),
    );
  }
}
