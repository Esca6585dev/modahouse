import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/paged_controller.dart';
import '../state/providers.dart';
import '../widgets/category_chips.dart';
import '../widgets/pin_grid.dart';
import '../widgets/states.dart';

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
  late PagedController<Pin> _results = _make();
  final _focus = FocusNode();
  Timer? _debounce;

  PagedController<Pin> _make() {
    final repo = ref.read(pinsRepositoryProvider);
    final q = _query;
    final c = _category;
    return PagedController((page) => repo.list(q: q, category: c, page: page));
  }

  void _reset() {
    final old = _results;
    setState(() => _results = _make());
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
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
          onRefresh: () => _results.refresh(),
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
                      hintText: S.searchHint,
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
                child: CategoryChips(
                  selected: _category,
                  onSelected: (c) {
                    if (c == _category) return;
                    _category = c;
                    _reset();
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
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
