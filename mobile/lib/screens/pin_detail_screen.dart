import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../widgets/app_image.dart';
import '../widgets/avatar.dart';
import '../widgets/cart_flow.dart';
import '../widgets/contact_sheet.dart';
import '../widgets/follow_button.dart';
import '../widgets/pin_grid.dart';
import '../widgets/pin_menu.dart';
import '../widgets/product_sections.dart';
import '../widgets/save_sheet.dart';
import '../widgets/share_sheet.dart';
import '../widgets/shop_ui.dart';
import '../widgets/states.dart';
import '../widgets/top_actions.dart';
import '../widgets/video_view.dart';

class PinDetailScreen extends ConsumerStatefulWidget {
  const PinDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<PinDetailScreen> createState() => _PinDetailScreenState();
}

class _PinDetailScreenState extends ConsumerState<PinDetailScreen> {
  Object? _error;
  bool _loaded = false;
  Profile? _author;
  bool _likeBusy = false;
  bool _deleting = false;
  bool _viewCounted = false;
  String _color = '';
  String _size = '';
  int _qty = 1;
  bool _cartBusy = false;

  /// The carousel item on screen ("Ýükle" in ⋯ downloads this one).
  int _index = 0;
  late final PagedController<Comment> _comments;
  late final PagedController<Pin> _similar;

  int get id => widget.id;

  @override
  void initState() {
    super.initState();
    _comments = PagedController(
      (page) => ref.read(commentsRepositoryProvider).list(id, page),
    );
    _similar = PagedController(
      (page) => ref.read(pinsRepositoryProvider).similar(id, page),
    );
    _load();
  }

  @override
  void dispose() {
    _comments.dispose();
    _similar.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final pin = await ref.read(pinsRepositoryProvider).get(id);
      if (!mounted) return;
      ref.read(pinUpdatesProvider.notifier).updated(pin);
      final product = pin.product;
      setState(() {
        _loaded = true;
        if (product != null) {
          if (product.colors.length == 1) _color = product.colors.first.name;
          if (product.sizes.length == 1) _size = product.sizes.first;
        }
      });
      unawaited(_loadAuthor(pin.author.username));
      unawaited(_countView());
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadAuthor(String username) async {
    try {
      final profile = await ref.read(usersRepositoryProvider).profile(username);
      if (mounted) setState(() => _author = profile);
    } catch (_) {
      // The author row still works without the follower count.
    }
  }

  /// `POST /pins/:id/view` once per opening (the server dedupes per day).
  Future<void> _countView() async {
    if (_viewCounted) return;
    _viewCounted = true;
    try {
      final n = await ref.read(pinsRepositoryProvider).view(id);
      if (!mounted) return;
      final current = ref.read(pinUpdatesProvider).updated[id];
      if (current != null) {
        _publish(current.copyWith(viewsCount: n));
      }
    } catch (_) {
      // Views are best effort.
    }
  }

  bool _optionsChosen(Product product) {
    final ok =
        (product.colors.isEmpty || _color.isNotEmpty) &&
        (product.sizes.isEmpty || _size.isNotEmpty);
    if (!ok) showSnack(S.chooseOptions, error: true);
    return ok;
  }

  Future<void> _addToCart(Pin pin) async {
    final product = pin.product!;
    if (_cartBusy || !_requireLogin() || !_optionsChosen(product)) return;
    setState(() => _cartBusy = true);
    await addToCart(
      context,
      ref,
      pin,
      color: _color,
      size: _size,
      quantity: _qty,
    );
    if (mounted) setState(() => _cartBusy = false);
  }

  void _buyNow(Pin pin) {
    final product = pin.product!;
    if (!_requireLogin() || !_optionsChosen(product)) return;
    context.push(
      '/checkout',
      extra: CheckoutArgs(
        pin: pin,
        buyNow: BuyNow(
          pinId: pin.id,
          color: _color,
          size: _size,
          quantity: _qty,
        ),
      ),
    );
  }

  void _publish(Pin pin) => ref.read(pinUpdatesProvider.notifier).updated(pin);

  bool _requireLogin() {
    if (ref.read(authProvider).isLoggedIn) return true;
    context.push('/login?from=${Uri.encodeComponent('/pin/$id')}');
    return false;
  }

  Future<void> _toggleLike(Pin pin) async {
    if (_likeBusy || !_requireLogin()) return;
    final was = pin.liked;
    // Optimistic update, rolled back on error.
    _publish(
      pin.copyWith(
        liked: !was,
        likesCount: math.max(0, pin.likesCount + (was ? -1 : 1)),
      ),
    );
    setState(() => _likeBusy = true);
    try {
      final repo = ref.read(pinsRepositoryProvider);
      final res = was ? await repo.unlike(id) : await repo.like(id);
      final current = ref.read(pinUpdatesProvider).updated[id] ?? pin;
      _publish(current.copyWith(liked: res.liked, likesCount: res.likesCount));
    } catch (e) {
      final current = ref.read(pinUpdatesProvider).updated[id] ?? pin;
      _publish(current.copyWith(liked: was, likesCount: pin.likesCount));
      showError(e);
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  Future<void> _share(Pin pin) => showShareSheet(context, pin);

  Future<void> _openLink(String link) async {
    final uri = Uri.tryParse(link);
    var ok = false;
    if (uri != null) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok) showSnack(S.cannotOpenLink, error: true);
  }

  Future<void> _edit() async {
    final updated = await context.push<Pin>('/pin/$id/edit');
    if (updated != null) _publish(updated);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: S.deletePinTitle,
      text: S.deletePinText,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(pinsRepositoryProvider).delete(id);
      ref.read(pinUpdatesProvider.notifier).deleted(id);
      ref.read(boardsVersionProvider.notifier).bump();
      showSnack(S.pinDeleted);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } catch (e) {
      showError(e);
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = ref.watch(pinUpdatesProvider.select((u) => u.updated[id]));
    final me = ref.watch(authProvider).user;

    if (!_loaded || pin == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error == null
            ? const LoadingView()
            : (_error is ApiException && (_error as ApiException).isNotFound)
            ? EmptyView(
                icon: Icons.image_not_supported_outlined,
                title: S.pinNotFound,
                text: S.pinNotFoundText,
                action: FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text(S.tabHome),
                ),
              )
            : ErrorView(error: _error!, onRetry: _load),
      );
    }

    final isOwner = me != null && me.id == pin.author.id;
    if (pin.product != null) return _productScaffold(pin, me, isOwner);
    return Scaffold(
      body: RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: () async {
          await Future.wait([_load(), _comments.refresh(), _similar.refresh()]);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _hero(pin, isOwner)),
            SliverToBoxAdapter(child: _body(pin, me, isOwner)),
            SliverToBoxAdapter(child: _moreIdeasHeading()),
            PinGridSliver(
              controller: _similar,
              empty: const EmptyView(title: S.noSimilar, compact: true),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(Pin pin, bool isOwner) {
    final p = AppPalette.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width, 720.0) - 16;
    final height = math.min(width / pin.aspectRatio, size.height * 0.72);
    final top = MediaQuery.paddingOf(context).top;
    final gallery = pin.gallery;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top + 8, 8, 0),
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (gallery.length > 1)
                  PageView.builder(
                    key: const Key('pin-carousel'),
                    itemCount: gallery.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => gallery[i].isVideo
                        ? AutoVideo(
                            url: gallery[i].url,
                            posterUrl: gallery[i].posterUrl,
                            color: gallery[i].color,
                            active: i == _index,
                            semanticLabel: pin.title,
                          )
                        : AppImage(
                            gallery[i].url,
                            placeholder: parseHexColor(
                              gallery[i].color,
                              p.surface,
                            ),
                            semanticLabel: i == 0 ? pin.title : null,
                          ),
                  )
                else if (pin.isVideo)
                  AutoVideo(
                    url: pin.gallery.first.url,
                    posterUrl: pin.gallery.first.posterUrl,
                    color: pin.color,
                    semanticLabel: pin.title,
                  )
                else
                  AppImage(
                    pin.imageUrl,
                    placeholder: parseHexColor(pin.color, p.surface),
                    semanticLabel: pin.title,
                  ),
                if (gallery.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          S.imageIndex(_index + 1, gallery.length),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: S.back,
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(Pin pin, Me? me, bool isOwner) {
    final p = AppPalette.of(context);
    final cats = ref.watch(categoriesProvider).value;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppPalette.gutter,
            8,
            AppPalette.gutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pinterest: ♡ count, 💬 count, share, ⋯ | big red "Sakla".
              Row(
                children: [
                  _LikeButton(
                    pin: pin,
                    busy: _likeBusy,
                    onTap: () => _toggleLike(pin),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 22,
                          color: p.text,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${pin.commentsCount}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('pin-share'),
                    tooltip: S.share,
                    onPressed: () => _share(pin),
                    icon: const Icon(Icons.share_outlined),
                  ),
                  _moreIcon(pin),
                  const Spacer(),
                  _saveButton(pin),
                ],
              ),
              const SizedBox(height: 10),
              _authorRow(pin, isOwner, compact: true),
              const SizedBox(height: 12),
              if (pin.category.isNotEmpty)
                InkWell(
                  onTap: () => context.go(
                    '/search?category=${Uri.encodeComponent(pin.category)}',
                  ),
                  child: Text(
                    categoryName(pin.category, cats).toUpperCase(),
                    style: const TextStyle(
                      color: AppPalette.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                pin.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              if (pin.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  pin.description,
                  style: const TextStyle(fontSize: 16, height: 1.45),
                ),
              ],
              if (pin.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in pin.tags)
                      Material(
                        color: p.surface,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () =>
                              context.go('/search?q=${Uri.encodeComponent(t)}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            child: Text(
                              '#$t',
                              style: TextStyle(
                                color: p.muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (pin.link.isNotEmpty) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _openLink(pin.link),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(S.openLink),
                ),
              ],
              const SizedBox(height: 24),
              _CommentsSection(
                pin: pin,
                controller: _comments,
                loggedIn: me != null,
                onCountChanged: (delta) {
                  final current =
                      ref.read(pinUpdatesProvider).updated[id] ?? pin;
                  _publish(
                    current.copyWith(
                      commentsCount: math.max(0, current.commentsCount + delta),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreButton(Pin pin) => _deleting
      ? const RoundIconButton(
          icon: Icons.hourglass_top_rounded,
          tooltip: S.deleting,
          onPressed: null,
        )
      : RoundIconButton(
          icon: Icons.more_horiz_rounded,
          tooltip: S.postOptions,
          onPressed: () => _openMenu(pin),
        );

  void _openMenu(Pin pin) => showPinMenu(
    context,
    ref,
    pin,
    index: _index,
    onEdit: _edit,
    onDelete: _delete,
  );

  /// "⋯" in the action row under the image (Pinterest).
  Widget _moreIcon(Pin pin) => IconButton(
    key: const Key('pin-more'),
    tooltip: _deleting ? S.deleting : S.postOptions,
    onPressed: _deleting ? null : () => _openMenu(pin),
    icon: _deleting
        ? const Spinner(size: 18)
        : const Icon(Icons.more_horiz_rounded, size: 28),
  );

  /// The big red "Sakla" pill (black "Saklandy" once saved).
  Widget _saveButton(Pin pin) {
    final p = AppPalette.of(context);
    return FilledButton(
      key: const Key('pin-save'),
      style: FilledButton.styleFrom(
        backgroundColor: pin.isSaved ? p.text : AppPalette.accent,
        foregroundColor: pin.isSaved ? p.bg : Colors.white,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
      ),
      onPressed: () => showSaveSheet(context, ref, pin),
      child: Text(pin.isSaved ? S.saved : S.saveAction),
    );
  }

  /// "Başga gyzykly postlar" above the masonry, left-aligned like Pinterest.
  Widget _moreIdeasHeading() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppPalette.gutter,
          28,
          AppPalette.gutter,
          12,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            S.moreIdeas,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ),
  );

  Widget _productScaffold(Pin pin, Me? me, bool isOwner) {
    final product = pin.product!;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: () async {
          await Future.wait([_load(), _comments.refresh(), _similar.refresh()]);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ProductGallery(
                    pin: pin,
                    onIndexChanged: (i) => setState(() => _index = i),
                    overlay: [
                      Positioned(
                        left: 12,
                        top: top + 10,
                        child: RoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: S.back,
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/'),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: top + 10,
                        child: Row(
                          children: [
                            RoundIconButton(
                              icon: pin.liked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              tooltip: pin.liked ? S.unlike : S.like,
                              color: pin.liked ? AppPalette.accent : null,
                              onPressed: _likeBusy
                                  ? null
                                  : () => _toggleLike(pin),
                            ),
                            const SizedBox(width: 8),
                            RoundIconButton(
                              icon: Icons.ios_share_rounded,
                              tooltip: S.share,
                              onPressed: () => _share(pin),
                            ),
                            const SizedBox(width: 8),
                            _moreButton(pin),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _productBody(pin, product, me, isOwner)),
            SliverToBoxAdapter(child: _moreIdeasHeading()),
            PinGridSliver(
              controller: _similar,
              empty: const EmptyView(title: S.noSimilar, compact: true),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
      bottomNavigationBar: isOwner ? null : _buyBar(pin, product),
    );
  }

  Widget _productBody(Pin pin, Product product, Me? me, bool isOwner) {
    final p = AppPalette.of(context);
    final cats = ref.watch(categoriesProvider).value;
    const gap = SizedBox(height: 18);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
    Widget infoChip(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: p.text),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
    void openShop() =>
        context.push('/user/${Uri.encodeComponent(pin.author.username)}');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppPalette.gutter,
            14,
            AppPalette.gutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (product.badge != ProductBadge.none) ...[
                    ProductBadgeChip(badge: product.badge),
                    const SizedBox(width: 8),
                  ],
                  if (pin.category.isNotEmpty)
                    Flexible(
                      child: Text(
                        categoryName(pin.category, cats).toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                pin.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: openShop,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      UserAvatar(user: pin.author, size: 24),
                      const SizedBox(width: 8),
                      Flexible(
                        child: UserName(
                          user: pin.author,
                          style: TextStyle(
                            color: p.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (pin.reviewsCount > 0) ...[
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: AppPalette.gold,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${formatRating(pin.rating)} (${pin.reviewsCount})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              PriceText(
                price: product.price,
                oldPrice: product.oldPrice,
                size: 28,
                showDiscount: true,
                listingType: product.listingType,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (product.type == ListingType.rent) ...[
                    infoChip(
                      Icons.account_balance_wallet_outlined,
                      product.deposit > 0
                          ? S.depositValue(formatPrice(product.deposit))
                          : S.noDeposit,
                    ),
                    if (product.minDays > 0)
                      infoChip(
                        Icons.event_available_outlined,
                        S.minDaysValue(product.minDays),
                      ),
                  ],
                  if (product.type == ListingType.custom &&
                      product.readyDays > 0)
                    infoChip(
                      Icons.content_cut_rounded,
                      S.readyIn(product.readyDays),
                    ),
                  if (product.isSale && product.deliveryDays > 0)
                    infoChip(
                      Icons.local_shipping_outlined,
                      S.deliveryIn(product.deliveryDays),
                    ),
                  if (product.type != ListingType.custom &&
                      product.returnDays > 0)
                    infoChip(
                      Icons.verified_user_outlined,
                      S.returnShort(product.returnDays),
                    ),
                  if (pin.viewsCount > 0)
                    infoChip(
                      Icons.visibility_outlined,
                      S.viewsCount(compactCount(pin.viewsCount)),
                    ),
                  if (pin.ordersCount > 0)
                    infoChip(
                      Icons.shopping_bag_outlined,
                      S.soldCount(compactCount(pin.ordersCount)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _LikeButton(
                    pin: pin,
                    busy: _likeBusy,
                    onTap: () => _toggleLike(pin),
                  ),
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 22,
                    color: p.text,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${pin.commentsCount}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    key: const Key('find-similar'),
                    tooltip: S.menuSimilar,
                    onPressed: () => context.push('/visual/pin/${pin.id}'),
                    icon: const Icon(Icons.image_search_rounded),
                  ),
                  const Spacer(),
                  _saveButton(pin),
                ],
              ),
              if (product.colors.isNotEmpty) ...[
                gap,
                label(_color.isEmpty ? S.color : '${S.color}: $_color'),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final c in product.colors)
                      ColorSwatchButton(
                        option: c,
                        selected: c.name == _color,
                        onTap: () => setState(() => _color = c.name),
                      ),
                  ],
                ),
              ],
              if (product.sizes.isNotEmpty) ...[
                gap,
                label(_size.isEmpty ? S.size : '${S.size}: $_size'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sz in product.sizes)
                      SizeChip(
                        label: sz,
                        selected: sz == _size,
                        onTap: () => setState(() => _size = sz),
                      ),
                  ],
                ),
              ],
              gap,
              ProductInfoGrid(product: product),
              if (product.isSale) ...[
                const SizedBox(height: 14),
                const HowToOrderCard(),
              ],
              if (pin.description.isNotEmpty) ...[
                gap,
                Text(
                  pin.description,
                  style: const TextStyle(fontSize: 15.5, height: 1.5),
                ),
              ],
              if (pin.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in pin.tags)
                      ActionChip(
                        label: Text('#$t'),
                        onPressed: () =>
                            context.go('/search?q=${Uri.encodeComponent(t)}'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              _authorRow(pin, isOwner),
              const SizedBox(height: 24),
              ReviewsSection(key: ValueKey('reviews-${pin.id}'), pin: pin),
              const SizedBox(height: 24),
              _CommentsSection(
                pin: pin,
                controller: _comments,
                loggedIn: me != null,
                onCountChanged: (delta) {
                  final current =
                      ref.read(pinUpdatesProvider).updated[id] ?? pin;
                  _publish(
                    current.copyWith(
                      commentsCount: math.max(0, current.commentsCount + delta),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buyBar(Pin pin, Product product) {
    final p = AppPalette.of(context);
    if (!product.isSale) return _contactBar(pin);
    final soldOut = !product.inStock;
    final maxQty = product.stock == null ? 99 : product.stock!.clamp(1, 99);
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              QuantityStepper(
                value: _qty,
                max: maxQty,
                compact: true,
                enabled: !soldOut,
                onChanged: (v) => setState(() => _qty = v),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('buy-now'),
                  onPressed: soldOut ? null : () => _buyNow(pin),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                  label: Text(soldOut ? S.outOfStock : S.buyNow),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: S.addToCart,
                child: ExcludeSemantics(
                  child: Material(
                    color: p.surface,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const Key('add-to-cart'),
                      customBorder: const CircleBorder(),
                      onTap: soldOut || _cartBusy
                          ? null
                          : () => _addToCart(pin),
                      child: SizedBox.square(
                        dimension: 46,
                        child: _cartBusy
                            ? const Center(child: Spinner(size: 18))
                            : const Icon(
                                Icons.add_shopping_cart_rounded,
                                color: AppPalette.accent,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const CartButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Rent / custom listings: no cart; "Kärendä al" / "Sargyt et" open the
  /// contact sheet (phone, WhatsApp, Telegram, IMO, socials).
  Widget _contactBar(Pin pin) {
    final p = AppPalette.of(context);
    final product = pin.product!;
    final rent = product.type == ListingType.rent;
    void contact() => showContactSheet(
      context,
      shop: pin.author,
      business: _author?.business,
      title: pin.title,
    );
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('contact-primary'),
                  onPressed: contact,
                  icon: Icon(
                    rent
                        ? Icons.event_available_rounded
                        : Icons.content_cut_rounded,
                    size: 20,
                  ),
                  label: Text(rent ? S.rentNow : S.orderCustom),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: S.contact,
                excludeSemantics: true,
                onTap: contact,
                child: Material(
                  color: p.surface,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: contact,
                    child: const SizedBox.square(
                      dimension: 46,
                      child: Icon(Icons.chat_bubble_outline_rounded),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _authorRow(Pin pin, bool isOwner, {bool compact = false}) {
    final p = AppPalette.of(context);
    final author = _author;
    void open() =>
        context.push('/user/${Uri.encodeComponent(pin.author.username)}');
    return Row(
      children: [
        UserAvatar(user: pin.author, size: compact ? 36 : 48, onTap: open),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: open,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  author == null
                      ? '@${pin.author.username}'
                      : S.followersCount(compactCount(author.followersCount)),
                  style: TextStyle(color: p.muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        if (!isOwner && author != null)
          FollowButton(
            username: pin.author.username,
            isFollowing: author.isFollowing,
            small: true,
            onChanged: (following, profile) {
              setState(() {
                _author =
                    profile ??
                    author.copyWith(
                      isFollowing: following,
                      followersCount:
                          author.followersCount +
                          (following == author.isFollowing
                              ? 0
                              : (following ? 1 : -1)),
                    );
              });
            },
          ),
      ],
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.pin,
    required this.busy,
    required this.onTap,
  });

  final Pin pin;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = pin.liked ? AppPalette.accent : p.text;
    return Semantics(
      button: true,
      toggled: pin.liked,
      label: pin.liked ? S.unlike : S.like,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(
                  pin.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Text(
                  compactCount(pin.likesCount),
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({
    required this.pin,
    required this.controller,
    required this.loggedIn,
    required this.onCountChanged,
  });

  final Pin pin;
  final PagedController<Comment> controller;
  final bool loggedIn;
  final ValueChanged<int> onCountChanged;

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _text = TextEditingController();
  bool _sending = false;
  final Set<int> _deleting = {};

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final c = await ref
          .read(commentsRepositoryProvider)
          .add(widget.pin.id, text);
      widget.controller.setItems([...widget.controller.items, c]);
      widget.onCountChanged(1);
      _text.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Comment c) async {
    final ok = await confirmDialog(
      context,
      title: S.deleteComment,
      text: S.deleteCommentText,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting.add(c.id));
    try {
      await ref.read(commentsRepositoryProvider).delete(c.id);
      widget.controller.removeWhere((x) => x.id == c.id);
      widget.onCountChanged(-1);
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _deleting.remove(c.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final count = widget.pin.commentsCount;
    final ctrl = widget.controller;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count > 0 ? S.commentsCount(count) : S.comments,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (!ctrl.loaded && ctrl.loading)
            Text(
              S.commentsLoading,
              style: TextStyle(color: p.muted, fontSize: 14),
            )
          else if (ctrl.error != null && ctrl.items.isEmpty)
            Row(
              children: [
                Flexible(
                  child: Text(
                    errorMessage(ctrl.error),
                    style: const TextStyle(color: AppPalette.danger),
                  ),
                ),
                TextButton(onPressed: ctrl.refresh, child: const Text(S.retry)),
              ],
            )
          else if (ctrl.items.isEmpty)
            Text(S.noComments, style: TextStyle(color: p.muted, fontSize: 14))
          else
            for (final c in ctrl.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(
                      user: c.author,
                      size: 32,
                      onTap: () => context.push(
                        '/user/${Uri.encodeComponent(c.author.username)}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: c.author.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: '  ${timeAgo(c.createdAt)}',
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.text,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    if (c.canDelete)
                      IconButton(
                        tooltip: S.deleteComment,
                        visualDensity: VisualDensity.compact,
                        onPressed: _deleting.contains(c.id)
                            ? null
                            : () => _delete(c),
                        icon: _deleting.contains(c.id)
                            ? const Spinner(size: 16)
                            : Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: p.muted,
                              ),
                      ),
                  ],
                ),
              ),
          if (ctrl.items.isNotEmpty && ctrl.hasMore)
            TextButton(
              onPressed: ctrl.loading ? null : ctrl.loadMore,
              child: Text(ctrl.loading ? S.loading : S.moreComments),
            ),
          const SizedBox(height: 8),
          Divider(color: p.border, height: 1),
          const SizedBox(height: 12),
          if (widget.loggedIn)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    enabled: !_sending,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: S.addComment,
                      counterText: '',
                      filled: true,
                      fillColor: p.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: p.border, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: p.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: AppPalette.accent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _text.text.trim().isEmpty || _sending
                      ? null
                      : _send,
                  child: _sending
                      ? const Spinner(size: 18, color: Colors.white)
                      : const Text(S.send),
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: () => context.push(
                '/login?from=${Uri.encodeComponent('/pin/${widget.pin.id}')}',
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text(S.loginToComment),
            ),
        ],
      ),
    );
  }
}
