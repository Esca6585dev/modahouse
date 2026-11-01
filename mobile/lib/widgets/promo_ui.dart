import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/providers.dart';
import 'app_image.dart';

/// Compact red "Top 10" pill that opens the Top 10 screen (app bars).
class Top10Button extends StatelessWidget {
  const Top10Button({super.key, this.onPressed});

  /// Defaults to `context.push('/top')`.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Center(
      widthFactor: 1,
      child: Semantics(
        button: true,
        label: S.top10Title,
        excludeSemantics: true,
        child: Tooltip(
          message: S.top10Title,
          excludeFromSemantics: true,
          child: Material(
            key: const Key('top10-button'),
            color: AppPalette.accent,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onPressed ?? () => context.push('/top'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                child: Text(
                  S.top10Button,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Small "Öňe çykarylan" line on boosted posts in feeds.
class PromotedLabel extends StatelessWidget {
  const PromotedLabel({super.key, this.fontSize = 11.5});

  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('promoted-label'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.trending_up_rounded,
        size: fontSize + 2,
        color: AppPalette.accent,
      ),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          S.promoted,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppPalette.accent,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
          ),
        ),
      ),
    ],
  );
}

/// `GET /pins/promoted` (random order on the server).
final promotedPinsProvider = FutureProvider.autoDispose<List<Pin>>(
  (ref) => ref.watch(pinsRepositoryProvider).promoted(),
);

/// Horizontal "Öňe çykarylanlar" strip; hidden while loading, on errors and
/// when nothing is boosted.
class PromotedStrip extends ConsumerWidget {
  const PromotedStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pins = ref.watch(promotedPinsProvider).value ?? const <Pin>[];
    if (pins.isEmpty) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    return Column(
      key: const Key('promoted-strip'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(AppPalette.gutter, 4, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 20,
                color: AppPalette.accent,
              ),
              SizedBox(width: 6),
              Text(
                S.promotedTitle,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppPalette.gutter),
            itemCount: pins.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final pin = pins[i];
              return SizedBox(
                width: 120,
                child: Semantics(
                  button: true,
                  label: '${S.promoted}: ${pin.title}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => context.push('/pin/${pin.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AppImage(
                              pin.imageUrl,
                              cacheWidth: 120,
                              placeholder: parseHexColor(pin.color, p.surface),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          pin.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                        Text(
                          '@${pin.author.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.muted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
