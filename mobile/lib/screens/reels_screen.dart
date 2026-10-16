import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
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
import '../widgets/avatar.dart';
import '../widgets/caption.dart';
import '../widgets/pin_actions.dart';
import '../widgets/pin_menu.dart';
import '../widgets/save_sheet.dart';
import '../widgets/share_sheet.dart';
import '../widgets/shop_ui.dart';
import '../widgets/states.dart';
import '../widgets/video_view.dart';

/// Full-screen vertical video feed (`GET /pins?type=videos`).
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  late final PagedController<Pin> _reels = PagedController(
    (page) => ref
        .read(pinsRepositoryProvider)
        .list(type: PinType.videos, page: page, limit: 10),
  );
  final _pages = PageController();
  int _current = 0;
  bool _wheelLock = false;

  @override
  void dispose() {
    _reels.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Play only while this tab is shown and nothing is pushed on top of it.
    final visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    final updates = ref.watch(pinUpdatesProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: _reels,
        builder: (context, _) {
          final items = _reels.items
              .where((p) => !updates.isGone(p.id))
              .map(updates.resolve)
              .toList();
          if (!_reels.loaded) {
            return const Center(child: Spinner(color: Colors.white));
          }
          if (_reels.error != null && items.isEmpty) {
            return Theme(
              data: ThemeData.dark(),
              child: ErrorView(error: _reels.error!, onRetry: _reels.refresh),
            );
          }
          if (items.isEmpty) {
            return Theme(
              data: ThemeData.dark(),
              child: const EmptyView(
                icon: Icons.movie_outlined,
                title: S.reelsEmpty,
                text: S.reelsEmptyText,
              ),
            );
          }
          return Stack(
            children: [
              RefreshIndicator(
                color: AppPalette.accent,
                onRefresh: _reels.refresh,
                child: Listener(
                  // Mouse wheel / trackpad: one reel per scroll.
                  onPointerSignal: (event) {
                    if (event is! PointerScrollEvent || _wheelLock) return;
                    final dy = event.scrollDelta.dy;
                    if (dy.abs() < 20) return;
                    _wheelLock = true;
                    final go = dy > 0
                        ? _pages.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          )
                        : _pages.previousPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          );
                    go.whenComplete(() => _wheelLock = false);
                  },
                  child: ScrollConfiguration(
                    // Let mouse and trackpad drag the pages too (web, desktop).
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                    child: PageView.builder(
                      controller: _pages,
                      scrollDirection: Axis.vertical,
                      itemCount: items.length,
                      onPageChanged: (i) {
                        setState(() => _current = i);
                        if (i >= items.length - 3) _reels.loadMore();
                      },
                      itemBuilder: (context, i) => _Reel(
                        key: ValueKey('reel-${items[i].id}'),
                        pin: items[i],
                        active: visible && i == _current,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                top: MediaQuery.paddingOf(context).top + 10,
                child: const Text(
                  S.tabReels,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    shadows: [Shadow(blurRadius: 8)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Reel extends ConsumerStatefulWidget {
  const _Reel({super.key, required this.pin, required this.active});

  final Pin pin;
  final bool active;

  @override
  ConsumerState<_Reel> createState() => _ReelState();
}

class _ReelState extends ConsumerState<_Reel>
    with SingleTickerProviderStateMixin {
  Profile? _author;
  bool _followBusy = false;
  late final AnimationController _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _loadAuthor();
  }

  @override
  void didUpdateWidget(covariant _Reel old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _loadAuthor();
  }

  late final TapSorter _taps = TapSorter(
    onSingle: () {
      if (widget.pin.gallery.first.isVideo) {
        final muted = ref.read(videoMutedProvider);
        ref.read(videoMutedProvider.notifier).set(!muted);
      } else {
        context.push('/pin/${widget.pin.id}');
      }
    },
    onDouble: () {
      _heart.forward(from: 0);
      toggleLike(context, ref, widget.pin, like: true);
    },
  );

  @override
  void dispose() {
    _heart.dispose();
    _taps.dispose();
    super.dispose();
  }

  Future<void> _loadAuthor() async {
    if (_author != null) return;
    try {
      final p = await ref
          .read(usersRepositoryProvider)
          .profile(widget.pin.author.username);
      if (mounted) setState(() => _author = p);
    } catch (_) {}
  }

  Future<void> _follow() async {
    final a = _author;
    if (a == null || _followBusy) return;
    if (!ref.read(authProvider).isLoggedIn) {
      await context.push('/login?from=/reels');
      return;
    }
    setState(() => _followBusy = true);
    try {
      final repo = ref.read(usersRepositoryProvider);
      final p = a.isFollowing
          ? await repo.unfollow(a.username)
          : await repo.follow(a.username);
      if (mounted) setState(() => _author = p);
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final media = pin.gallery.first;
    final pad = MediaQuery.paddingOf(context);
    final me = ref.watch(authProvider.select((s) => s.user));
    final isMe = me?.id == pin.author.id;
    final author = _author;
    final text = pin.description.isEmpty
        ? pin.title
        : '${pin.title}\n${pin.description}';

    Widget rail(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color color = Colors.white,
      String? semantics,
    }) => Semantics(
      button: true,
      label: semantics ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 31,
                shadows: const [Shadow(blurRadius: 8)],
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    shadows: [Shadow(blurRadius: 6)],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          excludeFromSemantics: true,
          onTap: _taps.tap,
          child: media.isVideo
              ? AutoVideo(
                  url: media.url,
                  posterUrl: media.posterUrl,
                  color: media.color,
                  active: widget.active,
                  showMuteButton: true,
                  semanticLabel: pin.title,
                  onTap: _taps.tap,
                )
              : ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: media.aspectRatio,
                      child: AppImage(media.url, fit: BoxFit.contain),
                    ),
                  ),
                ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [Color(0xAA000000), Color(0x00000000)],
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
                if (t == 0 || t == 1) return const SizedBox.shrink();
                return Opacity(
                  opacity: t < 0.7 ? 1 : (1 - t) / 0.3,
                  child: Transform.scale(
                    scale: t < 0.3 ? 0.6 + t / 0.3 * 0.6 : 1.2,
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 100,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: pad.bottom + 70,
          child: Column(
            children: [
              rail(
                pin.liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                compactCount(pin.likesCount),
                () => toggleLike(context, ref, pin),
                color: pin.liked ? AppPalette.accentDark : Colors.white,
                semantics: pin.liked ? S.unlike : S.like,
              ),
              rail(
                Icons.chat_bubble_outline_rounded,
                compactCount(pin.commentsCount),
                () => context.push('/pin/${pin.id}'),
                semantics: S.comments,
              ),
              rail(
                Icons.send_outlined,
                '',
                () => showShareSheet(context, pin),
                semantics: S.share,
              ),
              rail(
                pin.isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                '',
                () => showSaveSheet(context, ref, pin),
                semantics: pin.isSaved ? S.saved : S.saveAction,
              ),
              rail(
                Icons.more_horiz_rounded,
                '',
                () => showPinMenu(context, ref, pin),
                semantics: S.postOptions,
              ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          right: 76,
          bottom: pad.bottom + 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push(
                      '/user/${Uri.encodeComponent(pin.author.username)}',
                    ),
                    child: UserAvatar(user: pin.author, size: 34),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: GestureDetector(
                      onTap: () => context.push(
                        '/user/${Uri.encodeComponent(pin.author.username)}',
                      ),
                      child: UserName(
                        user: pin.author,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          shadows: [Shadow(blurRadius: 6)],
                        ),
                      ),
                    ),
                  ),
                  if (!isMe && author != null) ...[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        side: const BorderSide(color: Colors.white, width: 1.2),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: _followBusy ? null : _follow,
                      child: Text(author.isFollowing ? S.following : S.follow),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              RichCaption(
                text: text,
                maxLines: 2,
                linkColor: Colors.white,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                  shadows: [Shadow(blurRadius: 6)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
