import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../screens/story_screens.dart';
import '../state/auth.dart';
import '../state/shop_state.dart';
import 'shop_ui.dart';
import 'states.dart';

/// Instagram-style story circles at the top of the home feed.
class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key});

  static const _avatar = 68.0;
  static const _tileWidth = 78.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider.select((s) => s.user));
    final stories = ref.watch(storiesProvider);
    final groups = stories.value ?? const <StoryGroup>[];
    final own = me == null
        ? null
        : groups.where((g) => g.user.id == me.id).firstOrNull;
    final others = groups.where((g) => g.user.id != me?.id).toList();
    final viewerGroups = [?own, ...others];

    if (stories.isLoading && groups.isEmpty) {
      return SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, _) => const Column(
            children: [
              Skeleton(width: _avatar, height: _avatar, radius: _avatar / 2),
              SizedBox(height: 8),
              Skeleton(width: 52, height: 10, radius: 5),
            ],
          ),
        ),
      );
    }
    if (me == null && others.isEmpty) return const SizedBox.shrink();

    void open(StoryGroup g) {
      context.push(
        '/stories/${Uri.encodeComponent(g.user.username)}',
        extra: StoryViewerArgs(
          groups: viewerGroups,
          initialIndex: viewerGroups.indexOf(g),
        ),
      );
    }

    return SizedBox(
      height: 106,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
        children: [
          if (me != null)
            _StoryTile(
              label: S.yourStory,
              width: _tileWidth,
              onTap: () => own != null ? open(own) : context.push('/story/new'),
              semanticsLabel: own != null ? S.yourStory : S.addStory,
              child: StoryAvatar(
                user: me,
                size: _avatar,
                hasStory: own != null,
                seen: own?.allSeen ?? false,
                showAdd: own == null,
              ),
            ),
          for (final g in others)
            _StoryTile(
              label: g.user.username,
              width: _tileWidth,
              semanticsLabel: g.user.displayName,
              onTap: () => open(g),
              child: StoryAvatar(
                user: g.user,
                size: _avatar,
                hasStory: true,
                seen: g.allSeen,
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.label,
    required this.width,
    required this.child,
    required this.semanticsLabel,
    required this.onTap,
  });

  final VoidCallback onTap;
  final String label;
  final double width;
  final Widget child;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              child,
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: p.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
