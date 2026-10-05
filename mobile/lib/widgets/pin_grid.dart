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
import 'pin_card.dart';
import 'save_sheet.dart';
import 'states.dart';

const _gridSpacing = 10.0;
const _gridRunSpacing = 16.0;
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
    final deleted = ref.watch(pinUpdatesProvider.select((u) => u.deleted));
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items
            .where((p) => !deleted.contains(p.id))
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppPalette.gutter,
              ),
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
    padding: const EdgeInsets.symmetric(horizontal: AppPalette.gutter),
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
