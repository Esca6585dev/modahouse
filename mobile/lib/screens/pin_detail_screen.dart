import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/api_exception.dart';
import '../core/format.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/paged_controller.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import '../widgets/app_image.dart';
import '../widgets/avatar.dart';
import '../widgets/follow_button.dart';
import '../widgets/pin_grid.dart';
import '../widgets/save_sheet.dart';
import '../widgets/states.dart';

class PinDetailScreen extends ConsumerStatefulWidget {
  const PinDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<PinDetailScreen> createState() => _PinDetailScreenState();
}

class _PinDetailScreenState extends ConsumerState<PinDetailScreen> {
  Object? _error;
  bool _loaded = false;
  Profile? _author;
  bool _likeBusy = false;
  bool _deleting = false;
  late final PagedController<Comment> _comments;
  late final PagedController<Pin> _similar;

  int get id => widget.id;

  @override
  void initState() {
    super.initState();
    _comments = PagedController(
      (page) => ref.read(commentsRepositoryProvider).list(id, page),
    );
    _similar = PagedController(
      (page) => ref.read(pinsRepositoryProvider).similar(id, page),
    );
    _load();
  }

  @override
  void dispose() {
    _comments.dispose();
    _similar.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final pin = await ref.read(pinsRepositoryProvider).get(id);
      if (!mounted) return;
      ref.read(pinUpdatesProvider.notifier).updated(pin);
      setState(() => _loaded = true);
      unawaited(_loadAuthor(pin.author.username));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadAuthor(String username) async {
    try {
      final profile = await ref.read(usersRepositoryProvider).profile(username);
      if (mounted) setState(() => _author = profile);
    } catch (_) {
      // The author row still works without the follower count.
    }
  }

  void _publish(Pin pin) => ref.read(pinUpdatesProvider.notifier).updated(pin);

  bool _requireLogin() {
    if (ref.read(authProvider).isLoggedIn) return true;
    context.push('/login?from=${Uri.encodeComponent('/pin/$id')}');
    return false;
  }

  Future<void> _toggleLike(Pin pin) async {
    if (_likeBusy || !_requireLogin()) return;
    final was = pin.liked;
    // Optimistic update, rolled back on error.
    _publish(
      pin.copyWith(
        liked: !was,
        likesCount: math.max(0, pin.likesCount + (was ? -1 : 1)),
      ),
    );
    setState(() => _likeBusy = true);
    try {
      final repo = ref.read(pinsRepositoryProvider);
      final res = was ? await repo.unlike(id) : await repo.like(id);
      final current = ref.read(pinUpdatesProvider).updated[id] ?? pin;
      _publish(current.copyWith(liked: res.liked, likesCount: res.likesCount));
    } catch (e) {
      final current = ref.read(pinUpdatesProvider).updated[id] ?? pin;
      _publish(current.copyWith(liked: was, likesCount: pin.likesCount));
      showError(e);
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  Future<void> _share(Pin pin) async {
    final image = resolveImageUrl(pin.imageUrl);
    final text = [
      pin.title,
      if (pin.link.isNotEmpty) pin.link,
      image,
    ].join('\n');
    try {
      final res = await SharePlus.instance.share(
        ShareParams(text: text, subject: pin.title),
      );
      if (res.status == ShareResultStatus.unavailable) {
        throw Exception('unavailable');
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      showSnack(S.linkCopied);
    }
  }

  Future<void> _openLink(String link) async {
    final uri = Uri.tryParse(link);
    var ok = false;
    if (uri != null) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok) showSnack(S.cannotOpenLink, error: true);
  }

  Future<void> _edit() async {
    final updated = await context.push<Pin>('/pin/$id/edit');
    if (updated != null) _publish(updated);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: S.deletePinTitle,
      text: S.deletePinText,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(pinsRepositoryProvider).delete(id);
      ref.read(pinUpdatesProvider.notifier).deleted(id);
      ref.read(boardsVersionProvider.notifier).bump();
      showSnack(S.pinDeleted);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } catch (e) {
      showError(e);
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = ref.watch(pinUpdatesProvider.select((u) => u.updated[id]));
    final me = ref.watch(authProvider).user;

    if (!_loaded || pin == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error == null
            ? const LoadingView()
            : (_error is ApiException && (_error as ApiException).isNotFound)
            ? EmptyView(
                icon: Icons.image_not_supported_outlined,
                title: S.pinNotFound,
                text: S.pinNotFoundText,
                action: FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text(S.tabHome),
                ),
              )
            : ErrorView(error: _error!, onRetry: _load),
      );
    }

    final isOwner = me != null && me.id == pin.author.id;
    return Scaffold(
      body: RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: () async {
          await Future.wait([_load(), _comments.refresh(), _similar.refresh()]);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _hero(pin, isOwner)),
            SliverToBoxAdapter(child: _body(pin, me, isOwner)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                child: Text(
                  S.similar,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            PinGridSliver(
              controller: _similar,
              empty: const EmptyView(title: S.noSimilar, compact: true),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(Pin pin, bool isOwner) {
    final p = AppPalette.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width, 720.0) - 16;
    final height = math.min(width / pin.aspectRatio, size.height * 0.72);
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top + 8, 8, 0),
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(
                  pin.imageUrl,
                  placeholder: parseHexColor(pin.color, p.surface),
                  semanticLabel: pin.title,
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: S.back,
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                  ),
                ),
                if (isOwner)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _deleting
                        ? const RoundIconButton(
                            icon: Icons.hourglass_top_rounded,
                            tooltip: S.deleting,
                            onPressed: null,
                          )
                        : PopupMenuButton<String>(
                            tooltip: S.pinOptions,
                            onSelected: (v) =>
                                v == 'edit' ? _edit() : _delete(),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text(S.edit),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppPalette.danger,
                                  ),
                                  title: Text(
                                    S.delete,
                                    style: TextStyle(color: AppPalette.danger),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                            child: const IgnorePointer(
                              child: RoundIconButton(
                                icon: Icons.more_horiz_rounded,
                                tooltip: S.pinOptions,
                                onPressed: null,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(Pin pin, Me? me, bool isOwner) {
    final p = AppPalette.of(context);
    final cats = ref.watch(categoriesProvider).value;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppPalette.gutter,
            8,
            AppPalette.gutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Actions: like, comments, share | save
              Row(
                children: [
                  _LikeButton(
                    pin: pin,
                    busy: _likeBusy,
                    onTap: () => _toggleLike(pin),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 22,
                          color: p.text,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${pin.commentsCount}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: S.share,
                    onPressed: () => _share(pin),
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: pin.isSaved
                        ? FilledButton.styleFrom(
                            backgroundColor: p.text,
                            foregroundColor: p.bg,
                          )
                        : null,
                    onPressed: () => showSaveSheet(context, ref, pin),
                    child: Text(pin.isSaved ? S.saved : S.saveAction),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (pin.category.isNotEmpty)
                InkWell(
                  onTap: () => context.go(
                    '/search?category=${Uri.encodeComponent(pin.category)}',
                  ),
                  child: Text(
                    categoryName(pin.category, cats).toUpperCase(),
                    style: const TextStyle(
                      color: AppPalette.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                pin.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              if (pin.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  pin.description,
                  style: const TextStyle(fontSize: 16, height: 1.45),
                ),
              ],
              if (pin.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in pin.tags)
                      Material(
                        color: p.surface,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () =>
                              context.go('/search?q=${Uri.encodeComponent(t)}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            child: Text(
                              '#$t',
                              style: TextStyle(
                                color: p.muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (pin.link.isNotEmpty) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _openLink(pin.link),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(S.openLink),
                ),
              ],
              const SizedBox(height: 20),
              _authorRow(pin, isOwner),
              const SizedBox(height: 20),
              _CommentsSection(
                pin: pin,
                controller: _comments,
                loggedIn: me != null,
                onCountChanged: (delta) {
                  final current =
                      ref.read(pinUpdatesProvider).updated[id] ?? pin;
                  _publish(
                    current.copyWith(
                      commentsCount: math.max(0, current.commentsCount + delta),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _authorRow(Pin pin, bool isOwner) {
    final p = AppPalette.of(context);
    final author = _author;
    void open() =>
        context.push('/user/${Uri.encodeComponent(pin.author.username)}');
    return Row(
      children: [
        UserAvatar(user: pin.author, size: 48, onTap: open),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: open,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pin.author.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  author == null
                      ? '@${pin.author.username}'
                      : S.followersCount(compactCount(author.followersCount)),
                  style: TextStyle(color: p.muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        if (!isOwner && author != null)
          FollowButton(
            username: pin.author.username,
            isFollowing: author.isFollowing,
            small: true,
            onChanged: (following, profile) {
              setState(() {
                _author =
                    profile ??
                    author.copyWith(
                      isFollowing: following,
                      followersCount:
                          author.followersCount +
                          (following == author.isFollowing
                              ? 0
                              : (following ? 1 : -1)),
                    );
              });
            },
          ),
      ],
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.pin,
    required this.busy,
    required this.onTap,
  });

  final Pin pin;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = pin.liked ? AppPalette.accent : p.text;
    return Semantics(
      button: true,
      toggled: pin.liked,
      label: pin.liked ? S.unlike : S.like,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Icon(
                  pin.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Text(
                  compactCount(pin.likesCount),
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({
    required this.pin,
    required this.controller,
    required this.loggedIn,
    required this.onCountChanged,
  });

  final Pin pin;
  final PagedController<Comment> controller;
  final bool loggedIn;
  final ValueChanged<int> onCountChanged;

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _text = TextEditingController();
  bool _sending = false;
  final Set<int> _deleting = {};

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final c = await ref
          .read(commentsRepositoryProvider)
          .add(widget.pin.id, text);
      widget.controller.setItems([...widget.controller.items, c]);
      widget.onCountChanged(1);
      _text.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Comment c) async {
    final ok = await confirmDialog(
      context,
      title: S.deleteComment,
      text: S.deleteCommentText,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting.add(c.id));
    try {
      await ref.read(commentsRepositoryProvider).delete(c.id);
      widget.controller.removeWhere((x) => x.id == c.id);
      widget.onCountChanged(-1);
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _deleting.remove(c.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final count = widget.pin.commentsCount;
    final ctrl = widget.controller;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count > 0 ? S.commentsCount(count) : S.comments,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (!ctrl.loaded && ctrl.loading)
            Text(
              S.commentsLoading,
              style: TextStyle(color: p.muted, fontSize: 14),
            )
          else if (ctrl.error != null && ctrl.items.isEmpty)
            Row(
              children: [
                Flexible(
                  child: Text(
                    errorMessage(ctrl.error),
                    style: const TextStyle(color: AppPalette.danger),
                  ),
                ),
                TextButton(onPressed: ctrl.refresh, child: const Text(S.retry)),
              ],
            )
          else if (ctrl.items.isEmpty)
            Text(S.noComments, style: TextStyle(color: p.muted, fontSize: 14))
          else
            for (final c in ctrl.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(
                      user: c.author,
                      size: 32,
                      onTap: () => context.push(
                        '/user/${Uri.encodeComponent(c.author.username)}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: c.author.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: '  ${timeAgo(c.createdAt)}',
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.text,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    if (c.canDelete)
                      IconButton(
                        tooltip: S.deleteComment,
                        visualDensity: VisualDensity.compact,
                        onPressed: _deleting.contains(c.id)
                            ? null
                            : () => _delete(c),
                        icon: _deleting.contains(c.id)
                            ? const Spinner(size: 16)
                            : Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: p.muted,
                              ),
                      ),
                  ],
                ),
              ),
          if (ctrl.items.isNotEmpty && ctrl.hasMore)
            TextButton(
              onPressed: ctrl.loading ? null : ctrl.loadMore,
              child: Text(ctrl.loading ? S.loading : S.moreComments),
            ),
          const SizedBox(height: 8),
          Divider(color: p.border, height: 1),
          const SizedBox(height: 12),
          if (widget.loggedIn)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    enabled: !_sending,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: S.addComment,
                      counterText: '',
                      filled: true,
                      fillColor: p.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: p.border, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: p.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: AppPalette.accent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _text.text.trim().isEmpty || _sending
                      ? null
                      : _send,
                  child: _sending
                      ? const Spinner(size: 18, color: Colors.white)
                      : const Text(S.send),
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: () => context.push(
                '/login?from=${Uri.encodeComponent('/pin/${widget.pin.id}')}',
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text(S.loginToComment),
            ),
        ],
      ),
    );
  }
}
