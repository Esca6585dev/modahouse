import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'auth.dart';
import 'providers.dart';

/// Number of items in the cart (badge on the cart icon). Loaded on login and
/// replaced with `Cart.count` after every cart change.
class CartCountNotifier extends Notifier<int> {
  @override
  int build() {
    final loggedIn = ref.watch(authProvider.select((s) => s.isLoggedIn));
    if (!loggedIn) return 0;
    unawaited(Future.microtask(refresh));
    return 0;
  }

  Future<void> refresh() async {
    if (!ref.read(authProvider).isLoggedIn) return;
    try {
      final n = await ref.read(cartRepositoryProvider).count();
      if (ref.mounted) state = n;
    } catch (_) {
      // Best effort.
    }
  }

  void set(int count) => state = count;
}

final cartCountProvider = NotifierProvider<CartCountNotifier, int>(
  CartCountNotifier.new,
);

/// Bumped after an order is placed or changes status, so lists reload.
class OrdersVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final ordersVersionProvider = NotifierProvider<OrdersVersionNotifier, int>(
  OrdersVersionNotifier.new,
);

/// Stories row on the home screen. Reloads when the account changes.
class StoriesNotifier extends AsyncNotifier<List<StoryGroup>> {
  @override
  Future<List<StoryGroup>> build() {
    ref.watch(currentUserIdProvider);
    return ref.read(storiesRepositoryProvider).feed();
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(storiesRepositoryProvider).feed(),
    );
  }

  /// Local "seen" update so rings turn grey without a refetch.
  void markSeen(int userId, int storyId) {
    final groups = state.value;
    if (groups == null) return;
    state = AsyncData([
      for (final g in groups) g.user.id == userId ? g.markSeen(storyId) : g,
    ]);
  }
}

final storiesProvider =
    AsyncNotifierProvider<StoriesNotifier, List<StoryGroup>>(
      StoriesNotifier.new,
    );
