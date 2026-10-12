import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import '../state/shop_state.dart';
import 'app_image.dart';
import 'caption.dart';
import 'pin_actions.dart';
import 'pin_menu.dart';
import 'save_sheet.dart';
import 'shop_ui.dart';
import 'video_view.dart';

/// Instagram-style single-column post: header, media carousel / video,
/// actions with double-tap like, likes, caption, latest comments, time.
class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.pin});

  final Pin pin;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  int _page = 0;
  late final AnimationController _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  late final TapSorter _taps = TapSorter(
    onSingle: () {
      final pin = ref.read(pinUpdatesProvider).resolve(widget.pin);
      if (pin.gallery[_page.clamp(0, pin.gallery.length - 1)].isVideo) {
        final muted = ref.read(videoMutedProvider);
        ref.read(videoMutedProvider.notifier).set(!muted);
      } else {
        _open();
      }
    },
    onDouble: () =>
        _doubleTap(ref.read(pinUpdatesProvider).resolve(widget.pin)),
  );

  @override
  void dispose() {
    _heart.dispose();
    _taps.dispose();
    super.dispose();
  }

  void _open() => context.push('/pin/${widget.pin.id}');

  void _openAuthor(Pin pin) =>
      context.push('/user/${Uri.encodeComponent(pin.author.username)}');

  Future<void> _doubleTap(Pin pin) async {
    _heart.forward(from: 0);
    await toggleLike(context, ref, pin, like: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pin =
        ref.watch(pinUpdatesProvider.select((u) => u.updated[widget.pin.id])) ??
        widget.pin;
    final gallery = pin.gallery;
    final ratio = gallery.first.aspectRatio.clamp(0.8, 1.25);
    final groups = ref.watch(storiesProvider).value ?? const <StoryGroup>[];
    final story = groups.where((g) => g.user.id == pin.author.id).firstOrNull;
    final cats = ref.watch(categoriesProvider).value;
    final product = pin.product;
    final text = pin.description.isEmpty
        ? pin.title
        : '${pin.title}\n${pin.description}';

    return Semantics(
      container: true,
      label: pin.title,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: story != null
                        ? () => context.push(
                            '/stories/${Uri.encodeComponent(pin.author.username)}',
                          )
                        : () => _openAuthor(pin),
                    child: StoryAvatar(
                      user: pin.author,
                      size: 38,
                      hasStory: story != null,
                      seen: story?.allSeen ?? false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _openAuthor(pin),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserName(
                            user: pin.author,
                            iconSize: 14,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          if (pin.category.isNotEmpty)
                            Text(
                              categoryName(pin.category, cats),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.muted, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: S.postOptions,
                    onPressed: () => showPinMenu(context, ref, pin),
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ],
              ),
            ),
            // Media
            AspectRatio(
              aspectRatio: ratio,
              child: GestureDetector(
                // Screen readers open the post with the comments button; a
                // semantic tap here would swallow double taps on the web.
                excludeFromSemantics: true,
                onTap: _taps.tap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VisibleBuilder(
                      builder: (context, visible) => PageView.builder(
                        itemCount: gallery.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (context, i) {
                          final m = gallery[i];
                          if (m.isVideo) {
                            return AutoVideo(
                              url: m.url,
                              posterUrl: m.posterUrl,
                              color: m.color,
                              active: visible && i == _page,
                              semanticLabel: pin.title,
                              onTap: _taps.tap,
                            );
                          }
                          return AppImage(
                            m.url,
                            placeholder: parseHexColor(m.color, p.surface),
                            semanticLabel: i == 0 ? pin.title : null,
                          );
                        },
                      ),
                    ),
                    if (gallery.length > 1)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            S.imageIndex(_page + 1, gallery.length),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    if (product != null)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _open,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.sell_outlined,
                                    size: 15,
                                    color: Color(0xFF262B2F),
                                  ),
                                  const SizedBox(width: 6),
                                  PriceText(
                                    price: product.price,
                                    oldPrice: product.oldPrice,
                                    listingType: product.listingType,
                                    size: 13.5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    IgnorePointer(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _heart,
                          builder: (context, _) {
                            final t = _heart.value;
                            if (t == 0 || t == 1) {
                              return const SizedBox.shrink();
                            }
                            final scale = t < 0.3
                                ? Curves.easeOutBack.transform(t / 0.3)
                                : 1.0;
                            final opacity = t < 0.7 ? 1.0 : (1 - t) / 0.3;
                            return Opacity(
                              opacity: opacity.clamp(0, 1),
                              child: Transform.scale(
                                scale: scale * 1.1,
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: Colors.white,
                                  size: 96,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 24,
                                      color: Color(0x55000000),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: pin.liked ? S.unlike : S.like,
                    onPressed: () => toggleLike(context, ref, pin),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (c, a) =>
                          ScaleTransition(scale: a, child: c),
                      child: Icon(
                        pin.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(pin.liked),
                        color: pin.liked ? AppPalette.accent : p.text,
                        size: 27,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: S.comments,
                    onPressed: _open,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  IconButton(
                    tooltip: S.share,
                    onPressed: () => sharePin(pin),
                    icon: const Icon(Icons.send_outlined),
                  ),
                  if (gallery.length > 1)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < gallery.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _page
                                    ? AppPalette.accent
                                    : p.surface2,
                              ),
                            ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  IconButton(
                    tooltip: pin.isSaved ? S.saved : S.saveAction,
                    onPressed: () => showSaveSheet(context, ref, pin),
                    icon: Icon(
                      pin.isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 27,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pin.likesCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        S.likesCount(groupDigits(pin.likesCount)),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  RichCaption(
                    author: pin.author.username,
                    onAuthorTap: () => _openAuthor(pin),
                    text: text,
                  ),
                  if (pin.commentsCount > pin.latestComments.length ||
                      (pin.commentsCount > 0 && pin.latestComments.isEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: GestureDetector(
                        onTap: _open,
                        child: Text(
                          S.allComments(pin.commentsCount),
                          style: TextStyle(color: p.muted, fontSize: 14),
                        ),
                      ),
                    ),
                  for (final c in pin.latestComments)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: RichCaption(
                        author: c.author.username,
                        onAuthorTap: () => context.push(
                          '/user/${Uri.encodeComponent(c.author.username)}',
                        ),
                        text: c.text,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: p.text,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo(pin.createdAt),
                    style: TextStyle(color: p.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
