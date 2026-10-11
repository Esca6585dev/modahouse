import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config.dart';
import '../core/theme.dart';
import '../state/providers.dart';

/// Shows an API image (relative or absolute URL). SVG files (the seed images)
/// go through flutter_svg, everything else through cached_network_image.
/// [placeholder] fills the box while loading so layouts never jump.
class AppImage extends ConsumerWidget {
  const AppImage(
    this.url, {
    super.key,
    this.placeholder,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.cacheWidth,
  });

  final String url;
  final Color? placeholder;
  final BoxFit fit;
  final String? semanticLabel;

  /// Decode raster images at this logical width (thumbnails). Saves memory
  /// and gives the thumbnail its own decoded image.
  final double? cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = placeholder ?? AppPalette.of(context).surface;
    final box = ColoredBox(color: bg, child: const SizedBox.expand());
    final full = resolveImageUrl(url);
    if (full.isEmpty || !ref.watch(networkImagesProvider)) return box;

    Widget error(BuildContext context, Object? _, Object? _) => ColoredBox(
      color: bg,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppPalette.of(context).muted,
        ),
      ),
    );

    final cache = cacheWidth == null
        ? null
        : (cacheWidth! * MediaQuery.devicePixelRatioOf(context)).round();
    final Widget image = isSvgUrl(full)
        ? SvgPicture.network(
            full,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            placeholderBuilder: (_) => box,
            errorBuilder: error,
            semanticsLabel: semanticLabel,
            excludeFromSemantics: semanticLabel == null,
          )
        // On the web the browser's HTTP cache already caches images, and
        // cached_network_image's decoded images can be released while another
        // screen still draws them (blank / broken tiles in CanvasKit).
        : kIsWeb
        ? Image.network(
            full,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: cache,
            semanticLabel: semanticLabel,
            excludeFromSemantics: semanticLabel == null,
            frameBuilder: (context, child, frame, sync) => sync
                ? child
                : AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: child,
                  ),
            errorBuilder: (context, e, _) => error(context, e, null),
          )
        : CachedNetworkImage(
            imageUrl: full,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            fadeInDuration: const Duration(milliseconds: 150),
            memCacheWidth: cache,
            placeholder: (_, _) => box,
            errorWidget: error,
          );
    return ColoredBox(color: bg, child: image);
  }
}
