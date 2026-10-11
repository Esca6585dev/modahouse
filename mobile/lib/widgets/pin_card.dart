import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/pin_updates.dart';
import 'app_image.dart';
import 'avatar.dart';
import 'cart_flow.dart';
import 'shop_ui.dart';

/// Masonry tile: image (with the pin color as placeholder and the real aspect
/// ratio), title and author. Products also show the badge, the price (with the
/// struck old price) and a quick add-to-cart button.
class PinCard extends ConsumerWidget {
  const PinCard({
    super.key,
    required this.pin,
    this.onTap,
    this.onLongPress,
    this.onAuthorTap,
    this.action,
  });

  final Pin pin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAuthorTap;

  /// Optional small button shown over the top-right corner of the image.
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final current =
        ref.watch(pinUpdatesProvider.select((u) => u.updated[pin.id])) ?? pin;
    final placeholder = parseHexColor(current.color, p.surface);
    final product = current.product;
    if (product != null) {
      return _ProductTile(
        pin: current,
        product: product,
        placeholder: placeholder,
        onTap: onTap,
        onLongPress: onLongPress,
        onAuthorTap: onAuthorTap,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: current.title,
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppPalette.radius),
              child: AspectRatio(
                aspectRatio: current.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(current.imageUrl, placeholder: placeholder),
                    if (action != null)
                      Positioned(top: 8, right: 8, child: action!),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (current.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: ExcludeSemantics(
              child: Text(
                current.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                  height: 1.3,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: InkWell(
            onTap: onAuthorTap,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(user: current.author, size: 22),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    current.author.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: p.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({
    required this.pin,
    required this.product,
    required this.placeholder,
    this.onTap,
    this.onLongPress,
    this.onAuthorTap,
  });

  final Pin pin;
  final Product product;
  final Color placeholder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final soldOut = !product.inStock;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: '${pin.title}, ${formatPrice(product.price)}',
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppPalette.radius),
              child: AspectRatio(
                aspectRatio: pin.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(pin.imageUrl, placeholder: placeholder),
                    if (product.badge != ProductBadge.none)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: ProductBadgeChip(
                          badge: product.badge,
                          small: true,
                        ),
                      ),
                    if (pin.images.length > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.collections_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (soldOut)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.55),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: const Text(
                            S.outOfStock,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 2, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pin.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: p.text,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      PriceText(
                        price: product.price,
                        oldPrice: product.oldPrice,
                        listingType: product.listingType,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: product.isSale
                    ? '${S.addToCart}: ${pin.title}'
                    : '${S.contact}: ${pin.title}',
                child: ExcludeSemantics(
                  child: Material(
                    color: p.surface,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: soldOut
                          ? null
                          : () => quickAddToCart(context, ref, pin),
                      child: SizedBox.square(
                        dimension: 36,
                        child: Icon(
                          product.isSale
                              ? Icons.add_shopping_cart_rounded
                              : Icons.chat_bubble_outline_rounded,
                          size: 19,
                          color: soldOut ? p.muted : AppPalette.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: InkWell(
            onTap: onAuthorTap,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(user: pin.author, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: UserName(
                    user: pin.author,
                    iconSize: 13,
                    style: TextStyle(fontSize: 12.5, color: p.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
