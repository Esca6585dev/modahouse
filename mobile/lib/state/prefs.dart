import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home / profile feed layout.
enum FeedView { pinterest, instagram }

/// The chosen feed view, remembered between launches.
class FeedViewNotifier extends Notifier<FeedView> {
  static const _key = 'mh_feed_view';

  @override
  FeedView build() {
    unawaited(_restore());
    return FeedView.pinterest;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_key);
      if (v == FeedView.instagram.name && ref.mounted) {
        state = FeedView.instagram;
      }
    } catch (_) {
      // No storage (tests): keep the default.
    }
  }

  Future<void> set(FeedView v) async {
    state = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, v.name);
    } catch (_) {}
  }
}

final feedViewProvider = NotifierProvider<FeedViewNotifier, FeedView>(
  FeedViewNotifier.new,
);
