import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/paged_controller.dart';
import '../state/prefs.dart';
import '../state/providers.dart';
import '../widgets/pin_grid.dart';
import '../widgets/states.dart';

/// `/tag/:tag`: posts with a hashtag (`GET /pins?tag=`).
class TagScreen extends ConsumerStatefulWidget {
  const TagScreen({super.key, required this.tag});

  final String tag;

  @override
  ConsumerState<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends ConsumerState<TagScreen> {
  late PagedController<Pin> _pins = _make();

  String get tag => widget.tag.replaceFirst('#', '');

  PagedController<Pin> _make() {
    final posts = ref.read(feedViewProvider) == FeedView.instagram;
    return PagedController(
      (page) => ref
          .read(pinsRepositoryProvider)
          .list(tag: tag, withComments: posts, page: page),
    );
  }

  @override
  void dispose() {
    _pins.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(feedViewProvider, (prev, next) {
      if (prev == next) return;
      final old = _pins;
      setState(() => _pins = _make());
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    });
    final view = ref.watch(feedViewProvider);
    final p = AppPalette.of(context);
    const empty = EmptyView(icon: Icons.tag_rounded, title: S.tagEmpty);
    return Scaffold(
      appBar: AppBar(
        title: Text('#$tag'),
        actions: [
          IconButton(
            tooltip: view == FeedView.pinterest
                ? S.viewInstagram
                : S.viewPinterest,
            onPressed: () => ref
                .read(feedViewProvider.notifier)
                .set(
                  view == FeedView.pinterest
                      ? FeedView.instagram
                      : FeedView.pinterest,
                ),
            icon: Icon(
              view == FeedView.pinterest
                  ? Icons.view_agenda_outlined
                  : Icons.dashboard_outlined,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: () => _pins.refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: p.border, width: 1.5),
                      ),
                      child: const Icon(Icons.tag_rounded, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#$tag',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          ListenableBuilder(
                            listenable: _pins,
                            builder: (context, _) => Text(
                              _pins.loaded
                                  ? S.postsCount(_pins.items.length) +
                                        (_pins.hasMore ? '+' : '')
                                  : S.loading,
                              style: TextStyle(color: p.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (view == FeedView.instagram)
              PostListSliver(controller: _pins, empty: empty)
            else
              PinGridSliver(controller: _pins, empty: empty),
          ],
        ),
      ),
    );
  }
}
