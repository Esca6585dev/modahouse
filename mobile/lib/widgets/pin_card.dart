import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../state/pin_updates.dart';
import 'app_image.dart';
import 'avatar.dart';

/// Masonry tile: image (with the pin color as placeholder and the real aspect
/// ratio), title and author.
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
    final current = ref.watch(pinUpdatesProvider.select((u) => u.updated[pin.id])) ?? pin;
    final placeholder = parseHexColor(current.color, p.surface);

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
                    if (action != null) Positioned(top: 8, right: 8, child: action!),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text, height: 1.3),
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
