import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/page.dart';

/// Page-by-page loader for `Page<T>` endpoints, driven by `hasMore`.
class PagedController<T> extends ChangeNotifier {
  PagedController(this._fetch, {bool autoload = true}) {
    if (autoload) unawaited(loadMore());
  }

  final Future<Page<T>> Function(int page) _fetch;

  List<T> _items = [];
  bool _loading = false;
  bool _loaded = false;
  bool _hasMore = true;
  Object? _error;
  int _nextPage = 1;
  int _generation = 0;
  bool _disposed = false;

  List<T> get items => _items;
  bool get loading => _loading;

  /// True once the first page arrived (or failed).
  bool get loaded => _loaded;
  bool get hasMore => _hasMore;
  Object? get error => _error;
  bool get isEmpty => _loaded && _items.isEmpty && _error == null;

  /// Loads the next page unless a load is running or the end was reached.
  Future<void> loadMore() async {
    if (_loading || !_hasMore || _disposed) return;
    await _load(_generation, _nextPage);
  }

  /// Reloads from page 1. Existing items stay visible until the new page arrives.
  Future<void> refresh() async {
    _generation++;
    _loading = false;
    _hasMore = true;
    _error = null;
    await _load(_generation, 1);
  }

  Future<void> _load(int gen, int page) async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final res = await _fetch(page);
      if (gen != _generation || _disposed) return;
      _items = page == 1 ? List.of(res.items) : [..._items, ...res.items];
      _hasMore = res.hasMore;
      _nextPage = page + 1;
    } catch (e) {
      if (gen != _generation || _disposed) return;
      _error = e;
    }
    _loading = false;
    _loaded = true;
    _notify();
  }

  /// Local edits (optimistic removals, inserts, replacements).
  void setItems(List<T> items) {
    _items = items;
    _notify();
  }

  void removeWhere(bool Function(T item) test) {
    _items = _items.where((e) => !test(e)).toList();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
