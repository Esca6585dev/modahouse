import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/paged_controller.dart';
import '../state/pin_updates.dart';
import '../core/format.dart';
import 'app_image.dart';
import 'pin_card.dart';
import 'post_card.dart';
import 'save_sheet.dart';
import 'states.dart';

// Tight Pinterest gutters.
const _gridSpacing = 6.0;
const _gridRunSpacing = 10.0;
const _gridPadding = 6.0;
const _maxTileWidth = 260.0;

/// Masonry pin grid as a sliver: skeletons → pins with infinite scroll driven
/// by `hasMore`, or the given empty / error state.
class PinGridSliver extends ConsumerWidget {
  const PinGridSliver({
    super.key,
    required this.controller,
    required this.empty,
    this.onLongPress,
    this.actionBuilder,
  });

  final PagedController<Pin> controller;
  final Widget empty;
  final void Function(Pin pin)? onLongPress;
  final Widget? Function(Pin pin)? actionBuilder;

  void _maybeLoadMore() {
    if (controller.hasMore && !controller.loading && controller.error == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => controller.loadMore(),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates = ref.watch(pinUpdatesProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items
            .where((p) => !updates.isGone(p.id))
            .toList();

        if (!controller.loaded && controller.error == null) {
          return const PinGridSkeleton();
        }
        if (controller.error != null && items.isEmpty) {
          return SliverToBoxAdapter(
            child: ErrorView(
              error: controller.error!,
              onRetry: controller.refresh,
            ),
          );
        }
        if (items.isEmpty) {
          if (controller.hasMore) _maybeLoadMore();
          return SliverToBoxAdapter(
            child: controller.hasMore ? const LoadingView() : empty,
          );
        }

        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: _gridPadding),
              sliver: SliverMasonryGrid.extent(
                maxCrossAxisExtent: _maxTileWidth,
                mainAxisSpacing: _gridRunSpacing,
                crossAxisSpacing: _gridSpacing,
                childCount: items.length,
                itemBuilder: (context, i) {
                  if (i >= items.length - 6) _maybeLoadMore();
                  final pin = items[i];
                  return PinCard(
                    key: ValueKey(pin.id),
                    pin: pin,
                    onTap: () => context.push('/pin/${pin.id}'),
                    onAuthorTap: () => context.push(
                      '/user/${Uri.encodeComponent(pin.author.username)}',
                    ),
                    onLongPress: () => onLongPress != null
                        ? onLongPress!(pin)
                        : showSaveSheet(context, ref, pin),
                    action: actionBuilder?.call(pin),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(child: _Footer(controller: controller)),
          ],
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final PagedController<Pin> controller;

  @override
  Widget build(BuildContext context) {
    Widget child = const SizedBox.shrink();
    if (controller.loading) {
      child = const Spinner();
    } else if (controller.error != null) {
      child = Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            errorMessage(controller.error),
            style: TextStyle(color: AppPalette.of(context).muted),
          ),
          TextButton(
            onPressed: controller.loadMore,
            child: const Text(S.retry),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: SizedBox(height: 48, child: Center(child: child)),
    );
  }
}

class PinGridSkeleton extends StatelessWidget {
  const PinGridSkeleton({super.key});

  static const _heights = [
    230.0,
    170.0,
    260.0,
    200.0,
    240.0,
    180.0,
    210.0,
    250.0,
  ];

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: _gridPadding),
    sliver: SliverMasonryGrid.extent(
      maxCrossAxisExtent: _maxTileWidth,
      mainAxisSpacing: _gridRunSpacing,
      crossAxisSpacing: _gridSpacing,
      childCount: _heights.length,
      itemBuilder: (context, i) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: _heights[i]),
          const SizedBox(height: 10),
          const FractionallySizedBox(
            widthFactor: 0.7,
            child: Skeleton(height: 14, radius: 7),
          ),
        ],
      ),
    ),
  );
}

/// Instagram view: a single column of [PostCard]s with infinite scroll.
class PostListSliver extends ConsumerWidget {
  const PostListSliver({
    super.key,
    required this.controller,
    required this.empty,
  });

  final PagedController<Pin> controller;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates = ref.watch(pinUpdatesProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items
            .where((p) => !updates.isGone(p.id))
            .toList();
        if (!controller.loaded && controller.error == null) {
          return SliverList.list(
            children: const [
              Padding(
                padding: EdgeInsets.all(12),
                child: Skeleton(height: 44, width: 180, radius: 22),
              ),
              Skeleton(height: 420, radius: 0),
            ],
          );
        }
        if (controller.error != null && items.isEmpty) {
          return SliverToBoxAdapter(
            child: ErrorView(
              error: controller.error!,
              onRetry: controller.refresh,
            ),
          );
        }
        if (items.isEmpty) {
          if (controller.hasMore && !controller.loading) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => controller.loadMore(),
            );
          }
          return SliverToBoxAdapter(
            child: controller.hasMore ? const LoadingView() : empty,
          );
        }
        return SliverList.builder(
          itemCount: items.length + 1,
          itemBuilder: (context, i) {
            if (i == items.length) return _Footer(controller: controller);
            if (i >= items.length - 3 &&
                controller.hasMore &&
                !controller.loading &&
                controller.error == null) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => controller.loadMore(),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: PostCard(key: ValueKey(items[i].id), pin: items[i]),
              ),
            );
          },
        );
      },
    );
  }
}

/// Instagram profile grid: 3 square tiles per row.
class SquareGridSliver extends ConsumerWidget {
  const SquareGridSliver({
    super.key,
    required this.controller,
    required this.empty,
  });

  final PagedController<Pin> controller;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates = ref.watch(pinUpdatesProvider);
    final p = AppPalette.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items
            .where((x) => !updates.isGone(x.id))
            .toList();
        if (!controller.loaded && controller.error == null) {
          return const SliverToBoxAdapter(child: LoadingView());
        }
        if (controller.error != null && items.isEmpty) {
          return SliverToBoxAdapter(
            child: ErrorView(
              error: controller.error!,
              onRetry: controller.refresh,
            ),
          );
        }
        if (items.isEmpty) return SliverToBoxAdapter(child: empty);
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          delegate: SliverChildBuilderDelegate((context, i) {
            if (i >= items.length - 6 &&
                controller.hasMore &&
                !controller.loading) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => controller.loadMore(),
              );
            }
            final pin = items[i];
            return Semantics(
              button: true,
              label: pin.title,
              excludeSemantics: true,
              onTap: () => context.push('/pin/${pin.id}'),
              child: GestureDetector(
                onTap: () => context.push('/pin/${pin.id}'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(
                      pin.imageUrl,
                      cacheWidth: 200,
                      placeholder: parseHexColor(pin.color, p.surface),
                    ),
                    if (pin.isVideo)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 6)],
                        ),
                      )
                    else if (pin.images.length > 1)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.collections_rounded,
                          size: 18,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 6)],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }, childCount: items.length),
        );
      },
    );
  }
}
