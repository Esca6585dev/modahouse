import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/snack.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';

final Set<int> _likeBusy = {};

/// Optimistic like / unlike shared by cards, posts, reels and the detail
/// page. [like] forces a direction (double tap only likes).
Future<void> toggleLike(
  BuildContext context,
  WidgetRef ref,
  Pin pin, {
  bool? like,
}) async {
  // The container outlives the widget (a card may scroll away mid-request).
  final c = ProviderScope.containerOf(context, listen: false);
  if (!c.read(authProvider).isLoggedIn) {
    await context.push('/login?from=${Uri.encodeComponent('/pin/${pin.id}')}');
    return;
  }
  final updates = c.read(pinUpdatesProvider.notifier);
  final current = c.read(pinUpdatesProvider).resolve(pin);
  final target = like ?? !current.liked;
  if (target == current.liked || _likeBusy.contains(pin.id)) return;
  _likeBusy.add(pin.id);
  updates.updated(
    current.copyWith(
      liked: target,
      likesCount: math.max(0, current.likesCount + (target ? 1 : -1)),
    ),
  );
  try {
    final repo = c.read(pinsRepositoryProvider);
    final res = target ? await repo.like(pin.id) : await repo.unlike(pin.id);
    final now = c.read(pinUpdatesProvider).resolve(pin);
    updates.updated(now.copyWith(liked: res.liked, likesCount: res.likesCount));
  } catch (e) {
    final now = c.read(pinUpdatesProvider).resolve(pin);
    updates.updated(
      now.copyWith(liked: current.liked, likesCount: current.likesCount),
    );
    showError(e);
  } finally {
    _likeBusy.remove(pin.id);
  }
}

/// Tells single taps from double taps without the gesture arena (so it also
/// works over a video that has its own tap handler).
class TapSorter {
  TapSorter({required this.onSingle, required this.onDouble});

  final VoidCallback onSingle;
  final VoidCallback onDouble;

  static const window = Duration(milliseconds: 300);
  DateTime? _last;
  Timer? _timer;

  void tap() {
    final now = DateTime.now();
    final last = _last;
    if (last != null && now.difference(last) < window) {
      _timer?.cancel();
      _last = null;
      onDouble();
      return;
    }
    _last = now;
    _timer?.cancel();
    _timer = Timer(window, () {
      _last = null;
      onSingle();
    });
  }

  void dispose() => _timer?.cancel();
}
