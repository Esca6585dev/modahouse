import 'package:cached_network_image/cached_network_image.dart';
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
  });

  final String url;
  final Color? placeholder;
  final BoxFit fit;
  final String? semanticLabel;

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
        : CachedNetworkImage(
            imageUrl: full,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => box,
            errorWidget: error,
          );
    return ColoredBox(color: bg, child: image);
  }
}
