import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_exception.dart';
import '../core/format.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../data/common.dart';
import '../data/pins_repository.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/providers.dart';
import '../state/shop_state.dart';
import '../widgets/app_image.dart';
import '../widgets/avatar.dart';
import '../widgets/board_form.dart';
import '../widgets/shop_ui.dart';
import '../widgets/states.dart';
import 'create_screen.dart' show pickImage;

/// Passed as `extra` when opening `/stories/:username` from the stories row,
/// so the viewer can swipe on to the next users.
class StoryViewerArgs {
  const StoryViewerArgs({required this.groups, this.initialIndex = 0});

  final List<StoryGroup> groups;
  final int initialIndex;
}

/// Full-screen story viewer: progress bars, tap left/right, auto-advance,
/// hold to pause, swipe between users, swipe down to close.
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({super.key, required this.username, this.args});

  final String username;
  final StoryViewerArgs? args;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  List<StoryGroup>? _groups;
  Object? _error;
  late PageController _pages;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    if (args != null && args.groups.isNotEmpty) {
      _groups = args.groups;
      _current = args.initialIndex.clamp(0, args.groups.length - 1);
    } else {
      _load();
    }
    _pages = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final g = await ref
          .read(storiesRepositoryProvider)
          .ofUser(widget.username);
      if (mounted) setState(() => _groups = [g]);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _nextGroup() {
    final groups = _groups!;
    if (_current >= groups.length - 1) {
      _close();
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  void _prevGroup() {
    if (_current > 0) {
      _pages.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  void _removeGroupStory(int groupIndex, int storyId) {
    final groups = [..._groups!];
    final g = groups[groupIndex];
    final rest = g.stories.where((s) => s.id != storyId).toList();
    if (rest.isEmpty) {
      _close();
      return;
    }
    groups[groupIndex] = StoryGroup(
      user: g.user,
      stories: rest,
      allSeen: rest.every((s) => s.seen),
    );
    setState(() => _groups = groups);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    Widget body;
    if (groups == null) {
      body = _error == null
          ? const Center(child: Spinner(color: Colors.white))
          : Center(
              child: Theme(
                data: ThemeData.dark(),
                child:
                    (_error is ApiException &&
                        (_error as ApiException).isNotFound)
                    ? EmptyView(
                        icon: Icons.auto_stories_outlined,
                        title: S.storyNotFound,
                        action: FilledButton(
                          onPressed: _close,
                          child: const Text(S.close),
                        ),
                      )
                    : ErrorView(error: _error!, onRetry: _load),
              ),
            );
    } else {
      body = PageView.builder(
        controller: _pages,
        itemCount: groups.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, i) => _GroupPlayer(
          key: ValueKey('group-${groups[i].user.id}'),
          group: groups[i],
          active: i == _current,
          onNextGroup: _nextGroup,
          onPrevGroup: _prevGroup,
          onClose: _close,
          onDeleted: (id) => _removeGroupStory(i, id),
        ),
      );
    }
    return Scaffold(backgroundColor: Colors.black, body: body);
  }
}

class _GroupPlayer extends ConsumerStatefulWidget {
  const _GroupPlayer({
    super.key,
    required this.group,
    required this.active,
    required this.onNextGroup,
    required this.onPrevGroup,
    required this.onClose,
    required this.onDeleted,
  });

  final StoryGroup group;
  final bool active;
  final VoidCallback onNextGroup;
  final VoidCallback onPrevGroup;
  final VoidCallback onClose;
  final ValueChanged<int> onDeleted;

  @override
  ConsumerState<_GroupPlayer> createState() => _GroupPlayerState();
}

class _GroupPlayerState extends ConsumerState<_GroupPlayer>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(seconds: 5);
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: _duration,
  )..addStatusListener(_onStatus);
  late int _index = widget.group.firstUnseen;
  final Set<int> _marked = {};
  bool _paused = false;

  List<Story> get stories => widget.group.stories;
  Story get story => stories[_index.clamp(0, stories.length - 1)];

  bool get _isOwner => ref.read(authProvider).user?.id == widget.group.user.id;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(covariant _GroupPlayer old) {
    super.didUpdateWidget(old);
    if (_index >= stories.length) _index = stories.length - 1;
    if (widget.active && !old.active) {
      _start();
    } else if (!widget.active && old.active) {
      _progress.stop();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) _next();
  }

  void _start() {
    _progress.forward(from: 0);
    _markViewed();
  }

  void _markViewed() {
    final s = story;
    if (_marked.contains(s.id)) return;
    _marked.add(s.id);
    ref.read(storiesProvider.notifier).markSeen(widget.group.user.id, s.id);
    if (!ref.read(authProvider).isLoggedIn || _isOwner || s.seen) return;
    unawaited(
      ref.read(storiesRepositoryProvider).markViewed(s.id).catchError((_) {}),
    );
  }

  void _next() {
    if (_index < stories.length - 1) {
      setState(() => _index++);
      _start();
    } else {
      _progress.stop();
      widget.onNextGroup();
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      _start();
    } else {
      widget.onPrevGroup();
      _progress.forward(from: 0);
    }
  }

  void _pause() {
    _paused = true;
    _progress.stop();
    setState(() {});
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    if (widget.active) _progress.forward();
    setState(() {});
  }

  Future<void> _openProduct(int pinId) async {
    _pause();
    await context.push('/pin/$pinId');
    if (mounted) _resume();
  }

  Future<void> _delete() async {
    _pause();
    final ok = await confirmDialog(
      context,
      title: S.deleteStory,
      text: S.deleteStoryText,
    );
    if (!mounted) return;
    if (!ok) {
      _resume();
      return;
    }
    try {
      final id = story.id;
      await ref.read(storiesRepositoryProvider).delete(id);
      showSnack(S.storyDeleted);
      unawaited(ref.read(storiesProvider.notifier).reload());
      widget.onDeleted(id);
      if (mounted) _start();
    } catch (e) {
      showError(e);
      _resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = story;
    final user = widget.group.user;
    final pad = MediaQuery.paddingOf(context);
    final landscape = s.width > 0 && s.height > 0 && s.width / s.height > 0.8;
    final bg = parseHexColor(s.color, const Color(0xFF222222));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final w = MediaQuery.sizeOf(context).width;
        if (d.localPosition.dx < w / 3) {
          _prev();
        } else {
          _next();
        }
      },
      onLongPressStart: (_) => _pause(),
      onLongPressEnd: (_) => _resume(),
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 300) widget.onClose();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: bg,
                child: AppImage(
                  s.imageUrl,
                  key: ValueKey('story-${s.id}'),
                  placeholder: bg,
                  fit: landscape ? BoxFit.contain : BoxFit.cover,
                  semanticLabel: s.caption.isEmpty
                      ? user.displayName
                      : s.caption,
                ),
              ),
            ),
          ),
          // Top scrim so the bars and the name stay readable.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: pad.top + 120,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: pad.bottom + 180,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xAA000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            top: pad.top + 8,
            child: Column(
              children: [
                _ProgressBars(
                  count: stories.length,
                  index: _index,
                  progress: _progress,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    UserAvatar(user: user, size: 34),
                    const SizedBox(width: 10),
                    Flexible(
                      child: UserName(
                        user: user,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo(s.createdAt),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (_isOwner)
                      IconButton(
                        tooltip: S.deleteStory,
                        onPressed: _delete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                    IconButton(
                      tooltip: S.close,
                      onPressed: widget.onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: pad.bottom + 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      s.caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        shadows: [Shadow(blurRadius: 8)],
                      ),
                    ),
                  ),
                if (s.pinId != null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF111111),
                    ),
                    onPressed: () => _openProduct(s.pinId!),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    label: const Text(S.viewProduct),
                  ),
                if (_isOwner)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          S.storyViews(s.viewsCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_paused)
            const Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Icon(
                    Icons.pause_circle_filled_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressBars extends StatelessWidget {
  const _ProgressBars({
    required this.count,
    required this.index,
    required this.progress,
  });

  final int count;
  final int index;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    builder: (context, _) => Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 2.5,
                value: i < index ? 1 : (i == index ? progress.value : 0),
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// `/story/new`: pick a photo, add a caption and optionally link a product.
class AddStoryScreen extends ConsumerStatefulWidget {
  const AddStoryScreen({super.key});

  @override
  ConsumerState<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends ConsumerState<AddStoryScreen> {
  PickedImage? _image;
  final _caption = TextEditingController();
  int? _pinId;
  List<Pin> _products = const [];
  bool _busy = false;
  double? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final me = ref.read(authProvider).user;
    if (me == null || !me.isBusiness) return;
    try {
      final page = await ref
          .read(pinsRepositoryProvider)
          .list(author: me.username, type: PinType.products, limit: 50);
      if (mounted) setState(() => _products = page.items);
    } catch (_) {
      // Linking a product is optional.
    }
  }

  Future<void> _pick(ImageSource source) async {
    final img = await pickImage(source, maxSize: 1600);
    if (img != null && mounted) setState(() => _image = img);
  }

  Future<void> _publish() async {
    final img = _image;
    if (img == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      await ref
          .read(storiesRepositoryProvider)
          .create(
            image: img,
            caption: _caption.text.trim(),
            pinId: _pinId,
            onProgress: (sent, total) {
              if (mounted && total > 0) {
                setState(() => _progress = sent / total);
              }
            },
          );
      unawaited(ref.read(storiesProvider.notifier).reload());
      showSnack(S.storyPublished);
      if (mounted) {
        context.canPop() ? context.pop() : context.go('/');
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final img = _image;
    return Scaffold(
      appBar: AppBar(title: const Text(S.newStory)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppPalette.gutter,
          4,
          AppPalette.gutter,
          32,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: img == null
                      ? Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                              colors: [
                                for (final c in AppPalette.storyGradient)
                                  c.withValues(alpha: 0.18),
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: p.muted,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                S.pickImage,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                S.storyHint,
                                style: TextStyle(color: p.muted, fontSize: 13),
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _pick(ImageSource.gallery),
                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                  size: 20,
                                ),
                                label: const Text(S.gallery),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _pick(ImageSource.camera),
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 20,
                                ),
                                label: const Text(S.camera),
                              ),
                            ],
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(img.bytes, fit: BoxFit.cover),
                            if (_caption.text.trim().isNotEmpty)
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 24,
                                child: Text(
                                  _caption.text.trim(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    shadows: [Shadow(blurRadius: 8)],
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: RoundIconButton(
                                icon: Icons.close_rounded,
                                tooltip: S.removeImage,
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _image = null),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _caption,
            enabled: !_busy,
            maxLength: 200,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: S.storyCaption,
              hintText: S.storyCaptionHint,
            ),
          ),
          if (_products.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: _pinId,
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              decoration: const InputDecoration(
                labelText: S.linkProduct,
                prefixIcon: Icon(Icons.shopping_bag_outlined),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text(S.noLinkedProduct),
                ),
                for (final pin in _products)
                  DropdownMenuItem<int?>(
                    value: pin.id,
                    child: Text(
                      '${pin.title} · ${formatPrice(pin.product?.price ?? 0)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy ? null : (v) => setState(() => _pinId = v),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            FormErrorBox(message: _error!),
          ],
          const SizedBox(height: 20),
          if (_progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: _progress, minHeight: 6),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: img == null || _busy ? null : _publish,
            icon: const Icon(Icons.auto_stories_outlined, size: 20),
            label: Text(_busy ? S.publishing : S.addStory),
          ),
        ],
      ),
    );
  }
}
