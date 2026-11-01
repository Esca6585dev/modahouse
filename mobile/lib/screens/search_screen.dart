import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/pins_repository.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/paged_controller.dart';
import '../state/providers.dart';
import '../widgets/avatar.dart';
import '../widgets/category_chips.dart';
import '../widgets/pin_grid.dart';
import '../widgets/promo_ui.dart';
import '../widgets/shop_ui.dart';
import '../widgets/states.dart';
import 'shops_screen.dart';
import 'visual_search_screen.dart';

enum SearchTab { ideas, products, shops }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery, this.initialCategory});

  final String? initialQuery;
  final String? initialCategory;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _text = TextEditingController(text: widget.initialQuery ?? '');
  late String _query = widget.initialQuery?.trim() ?? '';
  late String? _category = widget.initialCategory;
  SearchTab _tab = SearchTab.ideas;
  String? _shopCategory;
  late PagedController<Pin> _results = _make();
  late PagedController<BusinessCard> _shops;

  @override
  void initState() {
    super.initState();
    // Created up front: dispose() must not create it (no ref there).
    _shops = _makeShops();
  }

  final _focus = FocusNode();
  Timer? _debounce;

  PagedController<Pin> _make() {
    final repo = ref.read(pinsRepositoryProvider);
    final q = _query;
    final c = _category;
    final type = _tab == SearchTab.products ? PinType.products : PinType.any;
    return PagedController(
      (page) => repo.list(q: q, category: c, type: type, page: page),
    );
  }

  PagedController<BusinessCard> _makeShops() {
    final repo = ref.read(businessRepositoryProvider);
    final q = _query;
    final c = _shopCategory;
    return PagedController(
      (page) => repo.list(q: q, category: c, page: page),
      autoload: _tab == SearchTab.shops,
    );
  }

  void _reset() {
    final old = _results;
    final oldShops = _shops;
    setState(() {
      _results = _make();
      _shops = _makeShops();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
      oldShops.dispose();
    });
  }

  @override
  void didUpdateWidget(covariant SearchScreen old) {
    super.didUpdateWidget(old);
    // Opened again with new ?q= / ?category= (e.g. tapping a tag on a pin).
    if (old.initialQuery != widget.initialQuery ||
        old.initialCategory != widget.initialCategory) {
      _text.text = widget.initialQuery ?? '';
      _query = _text.text.trim();
      _category = widget.initialCategory;
      _reset();
    }
  }

  void _onChanged(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _submit(v));
  }

  void _submit(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q == _query) return;
    _query = q;
    _reset();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    _focus.dispose();
    _results.dispose();
    _shops.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserIdProvider, (prev, next) {
      if (prev != next) _reset();
    });
    final p = AppPalette.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppPalette.accent,
          onRefresh: () =>
              _tab == SearchTab.shops ? _shops.refresh() : _results.refresh(),
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppPalette.gutter,
                    12,
                    AppPalette.gutter,
                    12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          focusNode: _focus,
                          textInputAction: TextInputAction.search,
                          onChanged: _onChanged,
                          onSubmitted: _submit,
                          decoration: InputDecoration(
                            hintText: _tab == SearchTab.shops
                                ? S.searchShopsHint
                                : S.searchHint,
                            filled: true,
                            fillColor: p.surface,
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: p.muted,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_text.text.isNotEmpty)
                                  IconButton(
                                    tooltip: S.searchClear,
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: p.muted,
                                    ),
                                    onPressed: () {
                                      _text.clear();
                                      _submit('');
                                      setState(() {});
                                    },
                                  ),
                                PhotoSearchButton(color: p.text),
                              ],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: AppPalette.accent.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Top10Button(),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ChoiceChips<SearchTab>(
                    values: SearchTab.values,
                    selected: _tab,
                    brand: true,
                    label: (t) => switch (t) {
                      SearchTab.ideas => S.searchTabIdeas,
                      SearchTab.products => S.feedProducts,
                      SearchTab.shops => S.shops,
                    },
                    onSelected: (t) {
                      if (t == _tab) return;
                      _tab = t;
                      _reset();
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _tab == SearchTab.shops
                    ? BusinessCategoryChips(
                        selected: _shopCategory,
                        onSelected: (c) {
                          if (c == _shopCategory) return;
                          _shopCategory = c;
                          _reset();
                        },
                      )
                    : CategoryChips(
                        selected: _category,
                        onSelected: (c) {
                          if (c == _category) return;
                          _category = c;
                          _reset();
                        },
                      ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (_tab != SearchTab.shops && _query.isNotEmpty)
                SliverToBoxAdapter(
                  child: _PeopleAndTags(
                    key: ValueKey('pt-$_query'),
                    query: _query,
                  ),
                ),
              if (_tab == SearchTab.shops)
                ShopListSliver(controller: _shops)
              else
                PinGridSliver(
                  controller: _results,
                  empty: const EmptyView(
                    icon: Icons.search_off_rounded,
                    title: S.noResultsTitle,
                    text: S.noResultsText,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Adamlar" and "Heşteg" results from `GET /search?q=`.
class _PeopleAndTags extends ConsumerStatefulWidget {
  const _PeopleAndTags({super.key, required this.query});

  final String query;

  @override
  ConsumerState<_PeopleAndTags> createState() => _PeopleAndTagsState();
}

class _PeopleAndTagsState extends ConsumerState<_PeopleAndTags> {
  SearchResult? _r;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(pinsRepositoryProvider).search(widget.query);
      if (mounted) setState(() => _r = r);
    } catch (_) {
      // Posts still show; people and tags are extra.
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    if (r == null || r.isEmpty) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    Widget title(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        t,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.users.isNotEmpty) ...[
            title(S.people),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: r.users.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final u = r.users[i];
                  void open() =>
                      context.push('/user/${Uri.encodeComponent(u.username)}');
                  return Semantics(
                    button: true,
                    label: u.displayName,
                    excludeSemantics: true,
                    onTap: open,
                    child: GestureDetector(
                      onTap: open,
                      child: SizedBox(
                        width: 74,
                        child: Column(
                          children: [
                            UserAvatar(user: u, size: 58),
                            const SizedBox(height: 6),
                            Text(
                              u.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (r.tags.isNotEmpty) ...[
            title(S.hashtags),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: r.tags.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final t = r.tags[i];
                  return ActionChip(
                    avatar: Icon(Icons.tag_rounded, size: 16, color: p.text),
                    label: Text('${t.tag} · ${t.count}'),
                    onPressed: () =>
                        context.push('/tag/${Uri.encodeComponent(t.tag)}'),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
