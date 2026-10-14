import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/labels.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../widgets/app_image.dart';
import '../widgets/shop_ui.dart';
import '../widgets/states.dart';
import '../widgets/top_actions.dart';

final topProvider = FutureProvider.family<List<TopEntry>, StatsPeriod>(
  (ref, period) => ref.watch(businessRepositoryProvider).top(period: period),
);

/// "Top 10 köýnekçi": the best shops by views, likes and orders.
class TopScreen extends ConsumerStatefulWidget {
  const TopScreen({super.key});

  @override
  ConsumerState<TopScreen> createState() => _TopScreenState();
}

class _TopScreenState extends ConsumerState<TopScreen> {
  StatsPeriod _period = StatsPeriod.week;

  @override
  Widget build(BuildContext context) {
    final top = ref.watch(topProvider(_period));
    final p = AppPalette.of(context);

    final List<Widget> list;
    if (top.hasError && !top.hasValue) {
      list = [
        SliverToBoxAdapter(
          child: ErrorView(
            error: top.error!,
            onRetry: () => ref.invalidate(topProvider(_period)),
          ),
        ),
      ];
    } else if (!top.hasValue) {
      list = [
        SliverList.separated(
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppPalette.gutter),
            child: Skeleton(height: 220, radius: AppPalette.cardRadius),
          ),
        ),
      ];
    } else if (top.value!.isEmpty) {
      list = const [
        SliverToBoxAdapter(
          child: EmptyView(
            icon: Icons.emoji_events_outlined,
            title: S.top10Empty,
            text: S.top10EmptyText,
          ),
        ),
      ];
    } else {
      final entries = top.value!;
      list = [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppPalette.gutter),
          sliver: SliverList.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => TopEntryCard(entry: entries[i]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppPalette.gutter,
              16,
              AppPalette.gutter,
              24,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: p.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.top10Note,
                      style: TextStyle(color: p.muted, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return Scaffold(
      body: RefreshIndicator(
        color: AppPalette.accent,
        edgeOffset: 64,
        onRefresh: () => ref.refresh(topProvider(_period).future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              toolbarHeight: 60,
              titleSpacing: AppPalette.gutter,
              title: const LogoWordmark(height: 42),
              actions: topActions(),
            ),
            const SliverToBoxAdapter(child: _TopBanner()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChips<StatsPeriod>(
                        values: StatsPeriod.values,
                        selected: _period,
                        label: periodLabel,
                        brand: true,
                        onSelected: (v) => setState(() => _period = v),
                      ),
                    ),
                    IconButton(
                      tooltip: S.shops,
                      onPressed: () => context.push('/shops'),
                      icon: const Icon(Icons.storefront_outlined),
                    ),
                  ],
                ),
              ),
            ),
            ...list,
          ],
        ),
      ),
    );
  }
}

class _TopBanner extends StatelessWidget {
  const _TopBanner();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppPalette.gutter,
      4,
      AppPalette.gutter,
      0,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppPalette.cardRadius),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD7263D), Color(0xFF8A1424)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -26,
              child: Icon(
                Icons.emoji_events_rounded,
                size: 150,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Positioned(
              right: 70,
              top: -30,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: AppPalette.gold,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          S.top10Title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          S.top10Subtitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          S.top10Text,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Color medalColor(int rank) => switch (rank) {
  1 => AppPalette.gold,
  2 => AppPalette.silver,
  3 => AppPalette.bronze,
  _ => const Color(0x00000000),
};

/// One place in the Top 10 (like the owner's reference screenshot).
class TopEntryCard extends StatelessWidget {
  const TopEntryCard({super.key, required this.entry});

  final TopEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final b = entry.business;
    final first = entry.rank == 1;
    final medal = entry.rank <= 3;
    final enc = Uri.encodeComponent(b.username);
    void openProfile() => context.push('/user/$enc');
    void openDresses() => context.push('/user/$enc?tab=products');

    Widget stat(IconData icon, int n) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: p.muted),
        const SizedBox(width: 4),
        Text(
          statCount(n),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: p.text,
          ),
        ),
      ],
    );

    final covers = b.covers.take(4).toList();
    return Semantics(
      container: true,
      label: '${S.rankLabel(entry.rank)}: ${b.displayName}',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: first
              ? Color.alphaBlend(
                  AppPalette.gold.withValues(alpha: 0.09),
                  p.card,
                )
              : p.card,
          borderRadius: BorderRadius.circular(AppPalette.cardRadius),
          border: Border.all(
            color: first ? AppPalette.gold.withValues(alpha: 0.6) : p.border,
            width: first ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: openProfile,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      StoryAvatar(user: b, size: 74, hasStory: b.hasStory),
                      Positioned(
                        left: -6,
                        top: -6,
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: medal ? medalColor(entry.rank) : p.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.card, width: 2.5),
                          ),
                          child: Text(
                            '${entry.rank}',
                            style: TextStyle(
                              color: medal ? Colors.white : p.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserName(
                        user: b,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          StarRating(rating: b.rating, size: 15),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '(${b.reviewsCount})',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(color: p.muted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          businessCategoryLabel(b.category),
                          if (b.city.isNotEmpty) b.city,
                        ].where((e) => e.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.muted, fontSize: 12.5),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          stat(Icons.visibility_outlined, entry.views),
                          stat(Icons.favorite_border_rounded, entry.likes),
                          stat(Icons.shopping_bag_outlined, entry.orders),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: first
                        ? AppPalette.gold.withValues(alpha: 0.18)
                        : p.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        S.totalScore,
                        style: TextStyle(color: p.muted, fontSize: 10.5),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        S.score(entry.score),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (covers.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 78,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: i < covers.length
                            ? GestureDetector(
                                onTap: openDresses,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: AppImage(covers[i]),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 42,
                      child: Material(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: openDresses,
                          child: Center(
                            child: Text(
                              entry.moreCount > 0 ? '+${entry.moreCount}' : '›',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: p.muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    onPressed: openProfile,
                    icon: const Icon(Icons.person_outline_rounded, size: 18),
                    label: const Text(
                      S.viewProfile,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    onPressed: openDresses,
                    icon: const Icon(Icons.checkroom_rounded, size: 18),
                    label: const Text(
                      S.viewDresses,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
