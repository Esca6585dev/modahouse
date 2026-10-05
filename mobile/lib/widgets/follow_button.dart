import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/providers.dart';

/// Follow / unfollow toggle with optimistic update and rollback.
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({
    super.key,
    required this.username,
    required this.isFollowing,
    this.onChanged,
    this.small = false,
  });

  final String username;
  final bool isFollowing;

  /// Receives the updated profile from the server (or the optimistic state).
  final void Function(bool following, Profile? profile)? onChanged;
  final bool small;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  late bool _on = widget.isFollowing;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant FollowButton old) {
    super.didUpdateWidget(old);
    if (!_busy && old.isFollowing != widget.isFollowing) {
      _on = widget.isFollowing;
    }
  }

  Future<void> _toggle() async {
    if (!ref.read(authProvider).isLoggedIn) {
      await context.push(
        '/login?from=${Uri.encodeComponent('/user/${widget.username}')}',
      );
      return;
    }
    final was = _on;
    setState(() {
      _on = !was;
      _busy = true;
    });
    widget.onChanged?.call(!was, null);
    final repo = ref.read(usersRepositoryProvider);
    try {
      final profile = was
          ? await repo.unfollow(widget.username)
          : await repo.follow(widget.username);
      if (!mounted) return;
      setState(() => _on = profile.isFollowing);
      widget.onChanged?.call(profile.isFollowing, profile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _on = was);
      widget.onChanged?.call(was, null);
      showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final size = widget.small ? const Size(64, 36) : const Size(64, 44);
    final style = FilledButton.styleFrom(
      minimumSize: size,
      backgroundColor: _on ? p.text : AppPalette.accent,
      foregroundColor: _on ? p.bg : Colors.white,
      padding: EdgeInsets.symmetric(horizontal: widget.small ? 14 : 18),
      textStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: widget.small ? 14 : 15,
      ),
    );
    return FilledButton(
      style: style,
      onPressed: _busy ? null : _toggle,
      child: Text(_on ? S.following : S.follow),
    );
  }
}
