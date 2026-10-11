import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_exception.dart';
import '../core/format.dart';
import '../core/labels.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../data/pins_repository.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/paged_controller.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import '../widgets/app_image.dart';
import '../widgets/board_card.dart';
import '../widgets/board_form.dart';
import '../widgets/follow_button.dart';
import '../widgets/pin_grid.dart';
import '../widgets/shop_ui.dart';
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
        body: const LoginPrompt(
          text: S.loginPromptProfile,
          from: '/profile',
          icon: Icons.person_outline_rounded,
        ),
      );
    }
    return ProfileView(
      key: ValueKey('me-${me.username}-${me.isBusiness}'),
      username: me.username,
      isTab: true,
    );
  }
}

/// `/user/:username` (`?tab=products` opens the shop's products).
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key, required this.username, this.initialTab});

  final String username;
  final String? initialTab;

  @override
  Widget build(BuildContext context) => ProfileView(
    key: ValueKey('u-$username'),
    username: username,
    initialTab: initialTab,
  );
}

enum ProfileTab { products, pins, boards }

/// Opens a phone/SMS/web link; shows a message when nothing can handle it.
Future<void> launchExternal(Uri uri, {String error = S.cannotOpenLink}) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) showSnack(error, error: true);
}

/// "City, address" without repeating the city when the address has it.
String shopLocation(Business b) {
  if (b.address.isEmpty) return b.city;
  if (b.city.isEmpty || b.address.contains(b.city)) return b.address;
  return '${b.city}, ${b.address}';
}

/// `tel:` URI for a phone like "+993 61 234567".
Uri telUri(String phone) =>
    Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({
    super.key,
    required this.username,
    this.isTab = false,
    this.initialTab,
  });

  final String username;
  final bool isTab;
  final String? initialTab;

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  Profile? _profile;
  Object? _error;
  ProfileTab? _tab;
  PagedController<Pin>? _products;
  PagedController<Pin>? _pins;
  List<Board>? _boards;
  Object? _boardsError;

  String get username => widget.username;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBoards();
  }

  @override
  void dispose() {
    _products?.dispose();
    _pins?.dispose();
    super.dispose();
  }

  void _setupFeeds(Profile p) {
    if (_pins != null) return;
    final pins = ref.read(pinsRepositoryProvider);
    final users = ref.read(usersRepositoryProvider);
    if (p.isBusiness) {
      _products = PagedController(
        (page) =>
            pins.list(author: username, type: PinType.products, page: page),
      );
      _pins = PagedController(
        (page) => pins.list(author: username, type: PinType.ideas, page: page),
      );
    } else {
      _pins = PagedController((page) => users.pins(username, page));
    }
    _tab ??= p.isBusiness
        ? (widget.initialTab == 'boards'
              ? ProfileTab.boards
              : ProfileTab.products)
        : (widget.initialTab == 'boards' ? ProfileTab.boards : ProfileTab.pins);
  }

  Future<void> _loadProfile() async {
    setState(() => _error = null);
    try {
      final p = await ref.read(usersRepositoryProvider).profile(username);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _setupFeeds(p);
      });
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
    await Future.wait([
      _loadProfile(),
      _loadBoards(),
      if (_pins != null) _pins!.refresh(),
      if (_products != null) _products!.refresh(),
    ]);
  }

  Future<void> _createBoard() async {
    final board = await showBoardForm(context);
    if (board == null) return;
    showSnack(S.boardCreated);
    await _loadBoards();
  }

  Future<void> _share(Profile profile) async {
    final text = '${profile.displayName} (@${profile.username}) · ${S.appName}';
    try {
      final res = await SharePlus.instance.share(ShareParams(text: text));
      if (res.status == ShareResultStatus.unavailable) {
        throw Exception('unavailable');
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      showSnack(S.linkCopied);
    }
  }

  void _contact(Profile profile) {
    final b = profile.business;
    if (b == null) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (b.phone.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.call_outlined),
                title: const Text(S.call),
                subtitle: Text(b.phone),
                onTap: () {
                  Navigator.pop(ctx);
                  launchExternal(telUri(b.phone), error: S.cannotCall);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: const Text(S.sendSms),
                subtitle: Text(b.phone),
                onTap: () {
                  Navigator.pop(ctx);
                  launchExternal(
                    Uri(
                      scheme: 'sms',
                      path: b.phone.replaceAll(RegExp(r'[^0-9+]'), ''),
                    ),
                  );
                },
              ),
            ],
            if (b.instagram.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text(S.openInstagram),
                subtitle: Text('@${b.instagram.replaceFirst('@', '')}'),
                onTap: () {
                  Navigator.pop(ctx);
                  launchExternal(
                    Uri.https(
                      'instagram.com',
                      '/${b.instagram.replaceFirst('@', '')}',
                    ),
                  );
                },
              ),
            if (b.address.isNotEmpty || b.city.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text(S.copyAddress),
                subtitle: Text(shopLocation(b)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: shopLocation(b)));
                  showSnack(S.addressCopied);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(boardsVersionProvider, (_, _) => _loadBoards());
    ref.listen(pinUpdatesProvider.select((u) => u.created), (_, _) {
      _pins?.refresh();
      _products?.refresh();
      _loadProfile();
    });
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
            ? const EmptyView(
                icon: Icons.person_off_outlined,
                title: S.userNotFound,
              )
            : ErrorView(error: _error!, onRetry: _loadProfile),
      );
    }

    final tabs = [
      if (profile.isBusiness) ProfileTab.products,
      ProfileTab.pins,
      ProfileTab.boards,
    ];
    final tab = tabs.contains(_tab) ? _tab! : tabs.first;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: canPop,
        titleSpacing: canPop ? 0 : AppPalette.gutter,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                profile.username,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
            if (profile.verified) ...[
              const SizedBox(width: 6),
              const VerifiedIcon(size: 18),
            ],
          ],
        ),
        actions: [
          if (profile.isMe) ...[
            IconButton(
              tooltip: S.create,
              onPressed: () => context.go('/create'),
              icon: const Icon(Icons.add_box_outlined),
            ),
            IconButton(
              tooltip: S.settings,
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.menu_rounded),
            ),
          ] else
            IconButton(
              tooltip: S.shareProfile,
              onPressed: () => _share(profile),
              icon: const Icon(Icons.ios_share_rounded),
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
            SliverToBoxAdapter(child: _tabBar(tabs, tab)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ..._tabSlivers(profile, tab),
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

  Widget _count(String value, String label, {VoidCallback? onTap}) => Expanded(
    child: Semantics(
      button: onTap != null,
      label: '$value $label',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppPalette.of(context).muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _header(Profile profile) {
    final p = AppPalette.of(context);
    final enc = Uri.encodeComponent(profile.username);
    final b = profile.business;
    Widget info(IconData icon, String text, {Color? color}) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? p.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.5, color: p.text, height: 1.3),
            ),
          ),
        ],
      ),
    );
    final buttonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppPalette.gutter,
        4,
        AppPalette.gutter,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: profile.hasStory,
                label: profile.displayName,
                child: StoryAvatar(
                  user: profile,
                  size: 88,
                  hasStory: profile.hasStory,
                  seen: profile.storySeen,
                  onTap: profile.hasStory
                      ? () async {
                          await context.push('/stories/$enc');
                          if (mounted) {
                            setState(
                              () =>
                                  _profile = profile.copyWith(storySeen: true),
                            );
                          }
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              _count(compactCount(profile.pinsCount), S.posts),
              _count(
                compactCount(profile.followersCount),
                S.followers,
                onTap: () => context.push('/user/$enc/followers'),
              ),
              _count(
                compactCount(profile.followingCount),
                S.followingTitle,
                onTap: () => context.push('/user/$enc/following'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          UserName(
            user: profile,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (b != null && b.category != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                businessCategoryLabel(b.category),
                style: TextStyle(color: p.muted, fontSize: 13.5),
              ),
            ),
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(profile.bio, style: const TextStyle(height: 1.4)),
          ],
          if (b != null) ...[
            const SizedBox(height: 4),
            if (b.city.isNotEmpty || b.address.isNotEmpty)
              info(Icons.location_on_outlined, shopLocation(b)),
            if (b.workingHours.isNotEmpty)
              info(Icons.schedule_rounded, b.workingHours),
            if (b.phone.isNotEmpty) info(Icons.call_outlined, b.phone),
            if (b.reviewsCount > 0 || b.ordersCount > 0)
              info(
                Icons.star_rounded,
                [
                  if (b.reviewsCount > 0)
                    '${formatRating(b.rating)} · ${S.reviewsCount(b.reviewsCount)}',
                  if (b.ordersCount > 0)
                    S.soldCount(compactCount(b.ordersCount)),
                ].join(' · '),
                color: AppPalette.gold,
              ),
          ],
          const SizedBox(height: 14),
          if (profile.isMe)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: buttonStyle,
                    onPressed: () => context.push('/settings'),
                    child: const Text(S.editProfile),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: profile.isBusiness
                      ? ElevatedButton.icon(
                          style: buttonStyle,
                          onPressed: () => context.push('/business'),
                          icon: const Icon(Icons.insights_rounded, size: 18),
                          label: const Text(S.dashboard),
                        )
                      : ElevatedButton(
                          style: buttonStyle,
                          onPressed: () => context.push('/orders'),
                          child: const Text(S.myOrders),
                        ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: FollowButton(
                    username: profile.username,
                    isFollowing: profile.isFollowing,
                    small: true,
                    onChanged: (following, updated) {
                      setState(() {
                        _profile =
                            updated ??
                            profile.copyWith(
                              isFollowing: following,
                              followersCount: math.max(
                                0,
                                profile.followersCount +
                                    (following == profile.isFollowing
                                        ? 0
                                        : (following ? 1 : -1)),
                              ),
                            );
                      });
                    },
                  ),
                ),
                if (b != null && b.phone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: buttonStyle,
                      onPressed: () =>
                          launchExternal(telUri(b.phone), error: S.cannotCall),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text(S.call),
                    ),
                  ),
                ],
                if (b != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: buttonStyle,
                      onPressed: () => _contact(profile),
                      child: const Text(S.contact),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _tabBar(List<ProfileTab> tabs, ProfileTab active) {
    final p = AppPalette.of(context);
    (IconData, String) meta(ProfileTab t) => switch (t) {
      ProfileTab.products => (Icons.grid_view_rounded, S.tabProducts),
      ProfileTab.pins => (Icons.dashboard_outlined, S.tabPins),
      ProfileTab.boards => (Icons.bookmarks_outlined, S.tabBoards),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: Semantics(
                button: true,
                selected: t == active,
                label: meta(t).$2,
                excludeSemantics: true,
                onTap: () => setState(() => _tab = t),
                child: InkWell(
                  onTap: () => setState(() => _tab = t),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: t == active ? p.text : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          meta(t).$1,
                          size: 20,
                          color: t == active ? p.text : p.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          meta(t).$2,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: t == active ? p.text : p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _tabSlivers(Profile profile, ProfileTab tab) {
    switch (tab) {
      case ProfileTab.products:
        return [
          ProductGridSliver(
            controller: _products!,
            empty: EmptyView(
              icon: Icons.shopping_bag_outlined,
              title: S.noProductsTitle,
              text: profile.isMe ? S.noProductsText : S.noShopProducts,
              compact: true,
              action: profile.isMe
                  ? FilledButton(
                      onPressed: () => context.go('/create'),
                      child: const Text(S.addProduct),
                    )
                  : null,
            ),
          ),
        ];
      case ProfileTab.pins:
        return [
          PinGridSliver(
            controller: _pins!,
            empty: EmptyView(
              icon: Icons.image_outlined,
              title: S.noPinsTitle,
              text: profile.isMe ? S.noOwnPinsText : S.noUserPinsText,
              compact: true,
              action: profile.isMe
                  ? FilledButton(
                      onPressed: () => context.go('/create'),
                      child: const Text(S.createPin),
                    )
                  : null,
            ),
          ),
        ];
      case ProfileTab.boards:
        return _boardSlivers(profile);
    }
  }

  List<Widget> _boardSlivers(Profile profile) {
    final boards = _boards;
    final slivers = <Widget>[];
    if (profile.isMe) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppPalette.gutter,
              0,
              AppPalette.gutter,
              16,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _createBoard,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(S.newBoard),
              ),
            ),
          ),
        ),
      );
    }
    if (_boardsError != null && boards == null) {
      slivers.add(
        SliverToBoxAdapter(
          child: ErrorView(
            error: _boardsError!,
            onRetry: _loadBoards,
            compact: true,
          ),
        ),
      );
    } else if (boards == null) {
      slivers.add(const SliverToBoxAdapter(child: LoadingView()));
    } else if (boards.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: EmptyView(
            icon: Icons.dashboard_outlined,
            title: S.noBoardsTitle,
            text: profile.isMe ? S.noOwnBoardsText : S.noUserBoardsText,
            compact: true,
          ),
        ),
      );
    } else {
      slivers.add(
        BoardGridSliver(
          boards: boards,
          onTap: (b) => context.push('/board/${b.id}'),
        ),
      );
    }
    return slivers;
  }
}

/// Two-column grid of product tiles (shop profile "Harytlar" tab).
class ProductGridSliver extends ConsumerWidget {
  const ProductGridSliver({
    super.key,
    required this.controller,
    required this.empty,
  });

  final PagedController<Pin> controller;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates = ref.watch(pinUpdatesProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items
            .where((p) => !updates.deleted.contains(p.id))
            .map(updates.resolve)
            .where((p) => p.product != null)
            .toList();
        if (!controller.loaded && controller.error == null) {
          return const PinGridSkeleton();
        }
        if (controller.error != null && items.isEmpty) {
          return SliverToBoxAdapter(
            child: ErrorView(
              error: controller.error!,
              onRetry: controller.refresh,
            ),
          );
        }
        if (items.isEmpty) return SliverToBoxAdapter(child: empty);
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppPalette.gutter),
          sliver: SliverLayoutBuilder(
            builder: (context, c) {
              final columns = math.max(2, (c.crossAxisExtent / 240).floor());
              const spacing = 10.0;
              final w = (c.crossAxisExtent - spacing * (columns - 1)) / columns;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: 16,
                  mainAxisExtent: w * 1.25 + 62,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  if (i >= items.length - 4 &&
                      controller.hasMore &&
                      !controller.loading) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => controller.loadMore(),
                    );
                  }
                  return ProductGridTile(pin: items[i]);
                }, childCount: items.length),
              );
            },
          ),
        );
      },
    );
  }
}

class ProductGridTile extends StatelessWidget {
  const ProductGridTile({super.key, required this.pin});

  final Pin pin;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final product = pin.product!;
    return Semantics(
      button: true,
      label: '${pin.title}, ${formatPrice(product.price)}',
      excludeSemantics: true,
      onTap: () => context.push('/pin/${pin.id}'),
      child: GestureDetector(
        onTap: () => context.push('/pin/${pin.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppPalette.radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(
                      pin.imageUrl,
                      placeholder: parseHexColor(pin.color, p.surface),
                    ),
                    if (product.badge != ProductBadge.none)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: ProductBadgeChip(
                          badge: product.badge,
                          small: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pin.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 3),
            PriceText(
              price: product.price,
              oldPrice: product.oldPrice,
              listingType: product.listingType,
            ),
          ],
        ),
      ),
    );
  }
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
            (context, i) =>
                BoardCard(board: boards[i], onTap: () => onTap(boards[i])),
            childCount: boards.length,
          ),
        );
      },
    ),
  );
}
