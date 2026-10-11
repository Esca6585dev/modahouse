import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/labels.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import 'avatar.dart';

/// "450 TMT" in bold brand red, with the struck-through old price next to it.
class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.price,
    this.oldPrice = 0,
    this.size = 15,
    this.showDiscount = false,
    this.listingType = 'sale',
  });

  final String listingType;
  final int price;
  final int oldPrice;
  final double size;
  final bool showDiscount;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final discounted = oldPrice > price && price > 0;
    final percent = discounted
        ? ((oldPrice - price) * 100 / oldPrice).round()
        : 0;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: size * 0.4,
      runSpacing: 2,
      children: [
        Text(
          switch (listingType) {
            'rent' => '${formatPrice(price)} ${S.perDay}',
            'custom' => '${formatPrice(price)} ${S.priceFrom}',
            _ => formatPrice(price),
          },
          style: TextStyle(
            color: AppPalette.accent,
            fontWeight: FontWeight.w800,
            fontSize: size,
            height: 1.15,
            letterSpacing: -0.2,
          ),
        ),
        if (discounted)
          Text(
            formatPrice(oldPrice),
            style: TextStyle(
              color: p.muted,
              fontSize: size * 0.72,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.lineThrough,
              decorationColor: p.muted,
            ),
          ),
        if (discounted && showDiscount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppPalette.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              S.discount(percent),
              style: TextStyle(
                color: AppPalette.accent,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.62,
              ),
            ),
          ),
      ],
    );
  }
}

/// "Täze" (white), "Hit!" (red), "Aksiýa" (black) label.
class ProductBadgeChip extends StatelessWidget {
  const ProductBadgeChip({super.key, required this.badge, this.small = false});

  final ProductBadge badge;
  final bool small;

  @override
  Widget build(BuildContext context) {
    if (badge == ProductBadge.none) return const SizedBox.shrink();
    final (bg, fg) = switch (badge) {
      ProductBadge.isNew => (Colors.white, const Color(0xFF111111)),
      ProductBadge.hit => (AppPalette.accent, Colors.white),
      _ => (const Color(0xFF111111), Colors.white),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        badgeLabel(badge),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: small ? 11 : 12.5,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Five gold stars with half-star precision.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final empty = AppPalette.of(context).surface2;
    return Semantics(
      label: '${formatRating(rating)} / 5',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                rating >= i
                    ? Icons.star_rounded
                    : rating >= i - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_rounded,
                size: size,
                color: rating >= i - 0.5 ? AppPalette.gold : empty,
              ),
          ],
        ),
      ),
    );
  }
}

/// Tappable 1..5 star picker for writing reviews.
class StarPicker extends StatelessWidget {
  const StarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final empty = AppPalette.of(context).surface2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: true,
            selected: value == i,
            label: S.starsLabel(i),
            child: InkResponse(
              onTap: () => onChanged(i),
              radius: size * 0.7,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.star_rounded,
                  size: size,
                  color: value >= i ? AppPalette.gold : empty,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// − 1 + quantity control.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.compact = false,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final d = compact ? 30.0 : 38.0;
    Widget btn(IconData icon, String tip, int next, bool on) => Semantics(
      button: true,
      label: tip,
      enabled: on,
      child: ExcludeSemantics(
        child: Material(
          color: p.bg,
          shape: CircleBorder(side: BorderSide(color: p.border)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: on ? () => onChanged(next) : null,
            child: SizedBox.square(
              dimension: d,
              child: Icon(
                icon,
                size: d * 0.5,
                color: on ? p.text : p.muted.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(
          Icons.remove_rounded,
          S.decrease,
          value - 1,
          enabled && value > min,
        ),
        SizedBox(
          width: compact ? 30 : 38,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            semanticsLabel: '${S.quantity}: $value',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 14 : 16,
            ),
          ),
        ),
        btn(Icons.add_rounded, S.increase, value + 1, enabled && value < max),
      ],
    );
  }
}

/// Round color swatch with a ring when selected.
class ColorSwatchButton extends StatelessWidget {
  const ColorSwatchButton({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
    this.size = 38,
  });

  final ColorOption option;
  final bool selected;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final c = parseHexColor(option.hex, p.surface2);
    final light = c.computeLuminance() > 0.8;
    return Semantics(
      button: true,
      selected: selected,
      label: option.name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size + 8,
          height: size + 8,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? p.text : Colors.transparent,
              width: 2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: light ? p.border : Colors.transparent),
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: size * 0.5,
                    color: c.computeLuminance() > 0.5
                        ? const Color(0xFF111111)
                        : Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped size option ("44").
class SizeChip extends StatelessWidget {
  const SizeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.text : p.bg,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? p.text : p.border, width: 1.5),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 52, minHeight: 38),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: selected ? p.bg : p.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small blue check after verified names.
class VerifiedIcon extends StatelessWidget {
  const VerifiedIcon({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: S.verified,
    child: Icon(
      Icons.verified_rounded,
      size: size,
      color: const Color(0xFF0095F6),
    ),
  );
}

/// Name with an optional verified check.
class UserName extends StatelessWidget {
  const UserName({
    super.key,
    required this.user,
    this.style,
    this.iconSize = 15,
  });

  final UserBrief user;
  final TextStyle? style;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          user.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
      if (user.verified) ...[
        const SizedBox(width: 4),
        VerifiedIcon(size: iconSize),
      ],
    ],
  );
}

Color orderStatusColor(BuildContext context, OrderStatus s) {
  final p = AppPalette.of(context);
  switch (s) {
    case OrderStatus.isNew:
      return AppPalette.accent;
    case OrderStatus.confirmed:
      return const Color(0xFF1A73E8);
    case OrderStatus.shipped:
      return const Color(0xFFE37400);
    case OrderStatus.delivered:
      return p.success;
    case OrderStatus.cancelled:
    case OrderStatus.unknown:
      return p.muted;
  }
}

/// Colored status label ("Ýolda").
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final c = orderStatusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(orderStatusIcon(status), size: 14, color: c),
          const SizedBox(width: 4),
          Text(
            orderStatusLabel(status),
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar with an Instagram story ring: gradient when there is an unseen
/// story, grey when all were seen, nothing without a story.
class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    super.key,
    required this.user,
    this.size = 64,
    this.hasStory = false,
    this.seen = false,
    this.onTap,
    this.showAdd = false,
  });

  final UserBrief user;

  /// Outer diameter, ring included.
  final double size;
  final bool hasStory;
  final bool seen;
  final VoidCallback? onTap;

  /// Small "+" badge (own avatar: add a story).
  final bool showAdd;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final ring = (size * 0.045).clamp(2.0, 4.0);
    final gap = (size * 0.04).clamp(2.0, 4.0);
    final Gradient? gradient = hasStory && !seen
        ? const LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: AppPalette.storyGradient,
          )
        : null;
    final Widget avatar = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        color: hasStory && seen ? p.border : null,
      ),
      child: Container(
        padding: EdgeInsets.all(hasStory ? gap : 0),
        decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
        child: UserAvatar(
          user: user,
          size: size - 2 * ring - (hasStory ? 2 * gap : 0),
        ),
      ),
    );
    final Widget content = showAdd
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: size * 0.32,
                  height: size * 0.32,
                  decoration: BoxDecoration(
                    color: AppPalette.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.bg, width: 2.5),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: size * 0.22,
                  ),
                ),
              ),
            ],
          )
        : avatar;
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

/// Rounded white card with a hairline border used across shop screens.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.card,
        borderRadius: BorderRadius.circular(AppPalette.cardRadius),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }
}

/// Horizontal pill chips for a small fixed set of options.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: AppPalette.gutter),
    this.brand = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  /// Red active chip instead of black.
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                selected: v == selected,
                child: Material(
                  color: v == selected
                      ? (brand ? AppPalette.accent : p.text)
                      : p.surface,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onSelected(v),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          label(v),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: v == selected
                                ? (brand ? Colors.white : p.bg)
                                : p.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
