import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/pins_repository.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/paged_controller.dart';
import '../state/providers.dart';
import '../widgets/category_chips.dart';
import '../widgets/pin_grid.dart';
import '../widgets/shop_ui.dart';
import '../widgets/states.dart';
import 'shops_screen.dart';

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
  BusinessCategory? _shopCategory;
  late PagedController<Pin> _results = _make();
  late PagedController<BusinessCard> _shops = _makeShops();
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
                      prefixIcon: Icon(Icons.search_rounded, color: p.muted),
                      suffixIcon: _text.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: S.searchClear,
                              icon: Icon(Icons.close_rounded, color: p.muted),
                              onPressed: () {
                                _text.clear();
                                _submit('');
                                setState(() {});
                              },
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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
