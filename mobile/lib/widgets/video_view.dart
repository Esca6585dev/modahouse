import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../config.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../state/providers.dart';
import 'app_image.dart';

/// App-wide sound setting for autoplaying videos (Instagram style: muted
/// until the user taps one, then videos keep playing with sound).
class VideoMutedNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool muted) => state = muted;
}

final videoMutedProvider = NotifierProvider<VideoMutedNotifier, bool>(
  VideoMutedNotifier.new,
);

/// Builds [builder] with `visible = true` while at least [threshold] of the
/// child is inside the screen, re-checked on every scroll of the enclosing
/// scrollables.
class VisibleBuilder extends StatefulWidget {
  const VisibleBuilder({
    super.key,
    required this.builder,
    this.threshold = 0.6,
  });

  final Widget Function(BuildContext context, bool visible) builder;
  final double threshold;

  @override
  State<VisibleBuilder> createState() => _VisibleBuilderState();
}

class _VisibleBuilderState extends State<VisibleBuilder> {
  bool _visible = false;
  final List<ScrollPosition> _positions = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final p in _positions) {
      p.removeListener(_check);
    }
    _positions.clear();
    var ctx = context;
    // Listen to every enclosing scrollable (e.g. a feed inside a PageView).
    while (true) {
      final s = Scrollable.maybeOf(ctx);
      if (s == null) break;
      _positions.add(s.position);
      s.position.addListener(_check);
      ctx = s.context;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    for (final p in _positions) {
      p.removeListener(_check);
    }
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final screen = MediaQuery.sizeOf(context);
    final top = box.localToGlobal(Offset.zero);
    final h = box.size.height;
    final w = box.size.width;
    if (h <= 0 || w <= 0) return;
    final visH =
        (top.dy + h).clamp(0.0, screen.height) -
        top.dy.clamp(0.0, screen.height);
    final visW =
        (top.dx + w).clamp(0.0, screen.width) - top.dx.clamp(0.0, screen.width);
    final fraction = (visH / h) * (visW / w);
    final visible = fraction >= widget.threshold;
    if (visible != _visible) setState(() => _visible = visible);
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _check());
          return false;
        },
        child: widget.builder(context, _visible),
      );
}

/// A network video that plays (looped, muted by default) while [active].
/// Shows the poster until the first frame; tapping toggles the sound.
class AutoVideo extends ConsumerStatefulWidget {
  const AutoVideo({
    super.key,
    required this.url,
    this.posterUrl = '',
    this.color = '',
    this.active = true,
    this.loop = true,
    this.fit = BoxFit.cover,
    this.onEnded,
    this.onProgress,
    this.onTap,
    this.showMuteButton = true,
    this.semanticLabel,
  });

  final String url;
  final String posterUrl;
  final String color;
  final bool active;
  final bool loop;
  final BoxFit fit;

  /// Called once when a non-looping video reaches its end.
  final VoidCallback? onEnded;

  /// Playback position as a 0..1 fraction (story progress bars).
  final ValueChanged<double>? onProgress;

  /// Overrides the default tap (toggle sound).
  final VoidCallback? onTap;
  final bool showMuteButton;
  final String? semanticLabel;

  @override
  ConsumerState<AutoVideo> createState() => _AutoVideoState();
}

class _AutoVideoState extends ConsumerState<AutoVideo> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _failed = false;
  bool _endedSent = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _ensure();
  }

  @override
  void didUpdateWidget(covariant AutoVideo old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _disposeController();
      _ready = false;
      _failed = false;
      if (widget.active) _ensure();
      return;
    }
    if (widget.active && !old.active) {
      _ensure();
      _sync();
    } else if (!widget.active && old.active) {
      _c?.pause();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final c = _c;
    _c = null;
    if (c != null) {
      c.removeListener(_onTick);
      unawaited(c.dispose());
    }
  }

  Future<void> _ensure() async {
    if (_c != null || _failed) return;
    if (!ref.read(networkImagesProvider)) return; // widget tests
    final full = resolveImageUrl(widget.url);
    if (full.isEmpty) return;
    final c = VideoPlayerController.networkUrl(
      Uri.parse(full),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _c = c;
    c.addListener(_onTick);
    try {
      await c.initialize();
      await c.setLooping(widget.loop);
      if (!mounted || _c != c) return;
      setState(() => _ready = true);
      await _sync();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _sync() async {
    final c = _c;
    if (c == null || !_ready) return;
    final muted = ref.read(videoMutedProvider);
    await c.setVolume(muted ? 0 : 1);
    if (widget.active) {
      _endedSent = false;
      await c.play();
    } else {
      await c.pause();
    }
  }

  void _onTick() {
    final c = _c;
    if (c == null) return;
    final v = c.value;
    if (widget.onProgress != null &&
        v.isInitialized &&
        v.duration > Duration.zero) {
      widget.onProgress!(
        (v.position.inMilliseconds / v.duration.inMilliseconds).clamp(0, 1),
      );
    }
    if (widget.loop || _endedSent) return;
    if (v.isInitialized &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 120) &&
        !v.isPlaying) {
      _endedSent = true;
      widget.onEnded?.call();
    }
  }

  void _toggleMute() {
    final muted = !ref.read(videoMutedProvider);
    ref.read(videoMutedProvider.notifier).set(muted);
    _c?.setVolume(muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(videoMutedProvider, (_, muted) => _c?.setVolume(muted ? 0 : 1));
    final muted = ref.watch(videoMutedProvider);
    final p = AppPalette.of(context);
    final bg = parseHexColor(widget.color, const Color(0xFF1A1A1A));
    final c = _c;
    final showVideo = _ready && c != null && c.value.isInitialized;
    return Semantics(
      label: widget.semanticLabel ?? S.video,
      button: true,
      onTap: widget.onTap ?? _toggleMute,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap ?? _toggleMute,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.posterUrl.isNotEmpty)
              AppImage(widget.posterUrl, placeholder: bg, fit: widget.fit)
            else
              ColoredBox(color: bg),
            if (showVideo)
              ClipRect(
                child: FittedBox(
                  fit: widget.fit,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
                  ),
                ),
              ),
            if (_failed)
              Center(
                child: Icon(
                  Icons.videocam_off_outlined,
                  color: p.muted,
                  size: 32,
                ),
              ),
            if (widget.showMuteButton)
              Positioned(
                right: 10,
                bottom: 10,
                child: Semantics(
                  button: true,
                  label: muted ? S.unmute : S.mute,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small "▶" badge for video cards.
class VideoBadge extends StatelessWidget {
  const VideoBadge({super.key, this.duration = 0});

  final double duration;

  @override
  Widget build(BuildContext context) {
    final secs = duration.round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
          if (secs > 0) ...[
            const SizedBox(width: 2),
            Text(
              '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
