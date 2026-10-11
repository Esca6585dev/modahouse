import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/labels.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/paged_controller.dart';
import '../state/providers.dart';
import '../widgets/app_image.dart';
import '../widgets/shop_ui.dart';
import '../widgets/states.dart';

/// `/shops`: every shop, filtered by business category.
class ShopsScreen extends ConsumerStatefulWidget {
  const ShopsScreen({super.key});

  @override
  ConsumerState<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends ConsumerState<ShopsScreen> {
  BusinessCategory? _category;
  late PagedController<BusinessCard> _shops = _make();

  PagedController<BusinessCard> _make() {
    final repo = ref.read(businessRepositoryProvider);
    final c = _category;
    return PagedController((page) => repo.list(category: c, page: page));
  }

  void _setCategory(BusinessCategory? c) {
    if (c == _category) return;
    final old = _shops;
    setState(() {
      _category = c;
      _shops = _make();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    _shops.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(S.shops)),
    body: RefreshIndicator(
      color: AppPalette.accent,
      onRefresh: () => _shops.refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: BusinessCategoryChips(
              selected: _category,
              onSelected: _setCategory,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ShopListSliver(controller: _shops),
        ],
      ),
    ),
  );
}

/// "Hemmesi" + the five business categories.
class BusinessCategoryChips extends StatelessWidget {
  const BusinessCategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final BusinessCategory? selected;
  final ValueChanged<BusinessCategory?> onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChips<BusinessCategory?>(
    values: const [null, ...BusinessCategory.values],
    selected: selected,
    label: (c) => c == null ? S.all : businessCategoryLabel(c),
    onSelected: onSelected,
  );
}

/// Paged list of [ShopCard]s with loading, empty and error states.
class ShopListSliver extends StatelessWidget {
  const ShopListSliver({super.key, required this.controller});

  final PagedController<BusinessCard> controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final items = controller.items;
      if (!controller.loaded && controller.error == null) {
        return SliverList.separated(
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppPalette.gutter),
            child: Skeleton(height: 150, radius: AppPalette.cardRadius),
          ),
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
        return const SliverToBoxAdapter(
          child: EmptyView(
            icon: Icons.storefront_outlined,
            title: S.shopsEmpty,
          ),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppPalette.gutter,
          0,
          AppPalette.gutter,
          24,
        ),
        sliver: SliverList.separated(
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == items.length) {
              if (controller.hasMore && !controller.loading) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => controller.loadMore(),
                );
              }
              return controller.loading
                  ? const Center(child: Spinner())
                  : const SizedBox.shrink();
            }
            return ShopCard(shop: items[i]);
          },
        ),
      );
    },
  );
}

class ShopCard extends StatelessWidget {
  const ShopCard({super.key, required this.shop});

  final BusinessCard shop;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final b = shop;
    final enc = Uri.encodeComponent(b.username);
    final details = [
      businessCategoryLabel(b.category),
      if (b.city.isNotEmpty) b.city,
    ].where((e) => e.isNotEmpty).join(' · ');
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppPalette.cardRadius),
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/user/$enc'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StoryAvatar(user: b, size: 58, hasStory: b.hasStory),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserName(
                          user: b,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                        ),
                        if (details.isNotEmpty)
                          Text(
                            details,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.muted, fontSize: 12.5),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppPalette.gold,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              b.reviewsCount > 0
                                  ? '${formatRating(b.rating)} (${b.reviewsCount})'
                                  : '–',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                '${S.followersCount(compactCount(b.followersCount))} · ${S.productsCount(compactCount(b.productsCount))}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: p.muted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.muted),
                ],
              ),
              if (b.covers.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 86,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: i < b.covers.length
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AppImage(b.covers[i]),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
