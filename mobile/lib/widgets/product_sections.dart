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
import '../state/pin_updates.dart';
import '../state/providers.dart';
import 'app_image.dart';
import 'avatar.dart';
import 'shop_ui.dart';
import 'states.dart';
import 'video_view.dart';

/// Swipeable image carousel with a "1/5" counter and a thumbnails strip.
class ProductGallery extends StatefulWidget {
  const ProductGallery({
    super.key,
    required this.pin,
    this.overlay = const [],
    this.height,
    this.onIndexChanged,
  });

  final Pin pin;

  /// Called with the carousel item now on screen.
  final ValueChanged<int>? onIndexChanged;

  /// Buttons placed over the image (back, like, menu).
  final List<Widget> overlay;
  final double? height;

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) => _pages.animateToPage(
    i,
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final images = widget.pin.gallery;
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width, 720.0);
    final ratio = images.first.aspectRatio.clamp(0.6, 1.2);
    final height = widget.height ?? math.min(width / ratio, size.height * 0.56);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pages,
                itemCount: images.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  widget.onIndexChanged?.call(i);
                },
                itemBuilder: (context, i) => images[i].isVideo
                    ? AutoVideo(
                        url: images[i].url,
                        posterUrl: images[i].posterUrl,
                        color: images[i].color,
                        active: i == _index,
                        semanticLabel: widget.pin.title,
                      )
                    : AppImage(
                        images[i].url,
                        placeholder: parseHexColor(images[i].color, p.surface),
                        semanticLabel: i == 0 ? widget.pin.title : null,
                      ),
              ),
              if (images.length > 1)
                Positioned(
                  left: 14,
                  bottom: 14,
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
                      S.imageIndex(_index + 1, images.length),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              if (images.length > 1)
                Positioned(
                  bottom: 18,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < images.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _index ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ...widget.overlay,
            ],
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                AppPalette.gutter,
                10,
                AppPalette.gutter,
                4,
              ),
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Semantics(
                button: true,
                selected: i == _index,
                label: S.imageIndex(i + 1, images.length),
                child: GestureDetector(
                  onTap: () => _go(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 56,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: i == _index
                            ? AppPalette.accent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: AppImage(
                        images[i].stillUrl,
                        cacheWidth: 56,
                        placeholder: parseHexColor(images[i].color, p.surface),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Material, stock, delivery and return info as a 2x2 grid.
class ProductInfoGrid extends StatelessWidget {
  const ProductInfoGrid({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final stock = product.stock;
    Widget cell(
      IconData icon,
      String title,
      String value, {
      Color? color,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: p.text),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: p.muted, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: color ?? p.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final material = cell(
      Icons.layers_outlined,
      S.material,
      product.material.isEmpty ? S.notSpecified : product.material,
    );
    final returns = cell(
      Icons.autorenew_rounded,
      S.returnTitle,
      product.returnDays > 0 ? S.returnWithin(product.returnDays) : S.noReturn,
    );
    final delivery = cell(
      Icons.local_shipping_outlined,
      S.deliveryTime,
      product.deliveryDays > 0 ? S.days(product.deliveryDays) : S.notSpecified,
    );
    final cells = switch (product.type) {
      ListingType.rent => [
        material,
        cell(
          Icons.account_balance_wallet_outlined,
          S.depositLabel.replaceAll(' (TMT)', ''),
          product.deposit > 0 ? formatPrice(product.deposit) : S.noDeposit,
        ),
        cell(
          Icons.event_available_outlined,
          S.minDaysLabel,
          product.minDays > 0 ? S.days(product.minDays) : S.notSpecified,
        ),
        returns,
      ],
      ListingType.custom => [
        material,
        cell(
          Icons.content_cut_rounded,
          S.readyDaysLabel.replaceAll(' (gün)', ''),
          product.readyDays > 0 ? S.days(product.readyDays) : S.notSpecified,
        ),
        delivery,
        cell(
          Icons.straighten_rounded,
          S.size,
          product.sizes.isEmpty ? S.notSpecified : product.sizes.join(', '),
        ),
      ],
      _ => [
        material,
        cell(
          Icons.inventory_2_outlined,
          S.stock,
          stock == null
              ? S.available
              : stock > 0
              ? S.inStock(stock)
              : S.outOfStock,
          color: product.inStock ? p.success : AppPalette.danger,
        ),
        delivery,
        returns,
      ],
    };
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cells[0]),
              const SizedBox(width: 8),
              Expanded(child: cells[2]),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cells[1]),
              const SizedBox(width: 8),
              Expanded(child: cells[3]),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Nädip sargyt etmeli?" card with three numbered steps.
class HowToOrderCard extends StatelessWidget {
  const HowToOrderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget step(int n, String title, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppPalette.accent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$n',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: TextStyle(color: p.muted, fontSize: 13, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
    return SectionCard(
      color: p.tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                color: AppPalette.accent,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      S.howToOrder,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                      ),
                    ),
                    Text(
                      S.howToOrderSub,
                      style: TextStyle(color: p.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          step(1, S.step1Title, S.step1Text),
          const SizedBox(height: 14),
          step(2, S.step2Title, S.step2Text),
          const SizedBox(height: 14),
          step(3, S.step3Title, S.step3Text),
        ],
      ),
    );
  }
}

/// Reviews: rating summary, list and the "Syn ýaz" form for buyers.
class ReviewsSection extends ConsumerStatefulWidget {
  const ReviewsSection({super.key, required this.pin});

  final Pin pin;

  @override
  ConsumerState<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends ConsumerState<ReviewsSection> {
  ReviewsPage? _first;
  final List<Review> _items = [];
  bool _hasMore = false;
  int _page = 1;
  bool _loading = false;
  Object? _error;
  bool _writing = false;
  int _rating = 0;
  final _text = TextEditingController();
  bool _sending = false;
  String? _formError;

  int get pinId => widget.pin.id;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load(int page) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(reviewsRepositoryProvider).list(pinId, page);
      if (!mounted) return;
      setState(() {
        if (page == 1) {
          _first = res;
          _items
            ..clear()
            ..addAll(res.items);
        } else {
          _items.addAll(res.items);
        }
        _hasMore = res.hasMore;
        _page = page;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _publishSummary(ReviewsPage res) {
    final current = ref.read(pinUpdatesProvider).updated[pinId] ?? widget.pin;
    ref
        .read(pinUpdatesProvider.notifier)
        .updated(
          current.copyWith(rating: res.rating, reviewsCount: res.reviewsCount),
        );
  }

  Future<void> _send() async {
    if (_rating == 0) {
      setState(() => _formError = S.ratingRequired);
      return;
    }
    setState(() {
      _sending = true;
      _formError = null;
    });
    try {
      await ref
          .read(reviewsRepositoryProvider)
          .add(pinId, rating: _rating, text: _text.text.trim());
      showSnack(S.reviewSent);
      _text.clear();
      _rating = 0;
      _writing = false;
      await _load(1);
      if (mounted && _first != null) _publishSummary(_first!);
    } catch (e) {
      if (mounted) setState(() => _formError = errorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Review r) async {
    final ok = await confirmDialog(
      context,
      title: S.deleteReview,
      text: S.deleteReviewText,
    );
    if (!ok) return;
    try {
      await ref.read(reviewsRepositoryProvider).delete(r.id);
      await _load(1);
      if (mounted && _first != null) _publishSummary(_first!);
    } catch (e) {
      showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final first = _first;
    final rating = first?.rating ?? widget.pin.rating;
    final count = first?.reviewsCount ?? widget.pin.reviewsCount;
    final canReview = first?.canReview ?? false;
    final loggedIn = ref.watch(authProvider.select((s) => s.isLoggedIn));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              count > 0 ? '${S.reviews} ($count)' : S.reviews,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (canReview && !_writing)
              TextButton.icon(
                onPressed: () => setState(() => _writing = true),
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text(S.writeReview),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SectionCard(
          child: Row(
            children: [
              Text(
                count > 0 ? formatRating(rating) : '–',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarRating(rating: rating, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    count > 0 ? S.reviewsCount(count) : S.noReviews,
                    style: TextStyle(color: p.muted, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_writing) ...[
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  S.yourRating,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                StarPicker(
                  value: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _text,
                  enabled: !_sending,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(hintText: S.reviewHint),
                ),
                if (_formError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _formError!,
                      style: const TextStyle(
                        color: AppPalette.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: p.text),
                      onPressed: _sending
                          ? null
                          : () => setState(() => _writing = false),
                      child: const Text(S.cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _sending ? null : _send,
                      child: _sending
                          ? const Spinner(size: 18, color: Colors.white)
                          : const Text(S.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (!canReview && loggedIn && first != null && _items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              S.reviewOnlyBuyers,
              style: TextStyle(color: p.muted, fontSize: 13),
            ),
          ),
        if (_error != null && _items.isEmpty)
          Row(
            children: [
              Flexible(
                child: Text(
                  errorMessage(_error),
                  style: const TextStyle(color: AppPalette.danger),
                ),
              ),
              TextButton(onPressed: () => _load(1), child: const Text(S.retry)),
            ],
          ),
        const SizedBox(height: 4),
        for (final r in _items) _ReviewTile(review: r, onDelete: _delete),
        if (_hasMore)
          TextButton(
            onPressed: _loading ? null : () => _load(_page + 1),
            child: Text(_loading ? S.loading : S.loadMore),
          ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.onDelete});

  final Review review;
  final ValueChanged<Review> onDelete;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final r = review;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            user: r.author,
            size: 36,
            onTap: () =>
                context.push('/user/${Uri.encodeComponent(r.author.username)}'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: UserName(
                        user: r.author,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo(r.createdAt),
                      style: TextStyle(color: p.muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                StarRating(rating: r.rating.toDouble(), size: 15),
                if (r.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(r.text, style: const TextStyle(height: 1.4)),
                ],
              ],
            ),
          ),
          if (r.canDelete)
            IconButton(
              tooltip: S.deleteReview,
              visualDensity: VisualDensity.compact,
              onPressed: () => onDelete(r),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: p.muted,
              ),
            ),
        ],
      ),
    );
  }
}
