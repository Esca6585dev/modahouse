import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/paged_controller.dart';
import '../state/providers.dart';
import '../widgets/avatar.dart';
import '../widgets/states.dart';

/// Followers or following of a user.
class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key, required this.username, required this.followers});

  final String username;
  final bool followers;

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  late final PagedController<UserBrief> _users;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(usersRepositoryProvider);
    _users = PagedController(
      (page) => widget.followers ? repo.followers(widget.username, page) : repo.following(widget.username, page),
    );
  }

  @override
  void dispose() {
    _users.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.followers ? S.followers : S.followingTitle)),
      body: ListenableBuilder(
        listenable: _users,
        builder: (context, _) {
          if (!_users.loaded) return const LoadingView();
          if (_users.error != null && _users.items.isEmpty) {
            return ErrorView(error: _users.error!, onRetry: _users.refresh);
          }
          if (_users.items.isEmpty) {
            return EmptyView(
              icon: Icons.people_outline_rounded,
              title: widget.followers ? S.noFollowers : S.noFollowing,
            );
          }
          final items = _users.items;
          return RefreshIndicator(
            color: AppPalette.accent,
            onRefresh: _users.refresh,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: items.length + 1,
              itemBuilder: (context, i) {
                if (i == items.length) {
                  if (_users.hasMore && !_users.loading && _users.error == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _users.loadMore());
                  }
                  return SizedBox(
                    height: 56,
                    child: Center(
                      child: _users.loading
                          ? const Spinner()
                          : _users.error != null
                              ? TextButton(onPressed: _users.loadMore, child: Text('${errorMessage(_users.error)} · ${S.retry}'))
                              : null,
                    ),
                  );
                }
                final u = items[i];
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: UserAvatar(user: u, size: 44),
                  title: Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('@${u.username}', style: TextStyle(color: p.muted)),
                  onTap: () => context.push('/user/${Uri.encodeComponent(u.username)}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
