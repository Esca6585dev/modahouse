import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/api_exception.dart';
import '../core/labels.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/providers.dart';
import '../state/server.dart';
import '../widgets/avatar.dart';
import '../widgets/board_form.dart';
import '../widgets/states.dart';
import 'business_screens.dart';
import 'create_screen.dart' show pickImage;
import 'server_screen.dart' show serverSourceLabel;

final _usernameRe = RegExp(r'^[a-z0-9._]{3,30}$');

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).user;
    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: me == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppPalette.gutter,
                8,
                AppPalette.gutter,
                32,
              ),
              children: [
                _AvatarCard(me: me),
                _ProfileCard(me: me),
                BusinessSettingsCard(me: me),
                const _ShopLinksCard(),
                if (me.isAdmin) const _AdminCard(),
                const _ServerCard(),
                const _PasswordCard(),
                const _LogoutCard(),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(color: p.muted)),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AvatarCard extends ConsumerStatefulWidget {
  const _AvatarCard({required this.me});

  final Me me;

  @override
  ConsumerState<_AvatarCard> createState() => _AvatarCardState();
}

class _AvatarCardState extends ConsumerState<_AvatarCard> {
  bool _busy = false;

  Future<void> _run(Future<Me> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      final me = await action();
      ref.read(authProvider.notifier).setUser(me);
      showSnack(done);
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change() async {
    final img = await pickImage(ImageSource.gallery, maxSize: 1024);
    if (img == null || !mounted) return;
    await _run(
      () => ref.read(authRepositoryProvider).uploadAvatar(img),
      S.avatarUpdated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return _Card(
      title: S.avatar,
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              UserAvatar(user: me, size: 80),
              if (_busy) const Spinner(),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _change,
                  child: const Text(S.changeAvatar),
                ),
                if (me.avatarUrl.isNotEmpty)
                  ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () =>
                                ref.read(authRepositoryProvider).deleteAvatar(),
                            S.avatarRemoved,
                          ),
                    child: const Text(S.removeAvatar),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerStatefulWidget {
  const _ProfileCard({required this.me});

  final Me me;

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.me.name);
  late final _username = TextEditingController(text: widget.me.username);
  late final _bio = TextEditingController(text: widget.me.bio);
  late String _category = widget.me.category;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final me = await ref
          .read(authRepositoryProvider)
          .updateMe(
            name: _name.text.trim(),
            username: _username.text.trim().toLowerCase(),
            bio: _bio.text.trim(),
            category: _category == widget.me.category ? null : _category,
          );
      ref.read(authProvider.notifier).setUser(me);
      showSnack(S.profileUpdated);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Card(
    title: S.personalInfo,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            enabled: !_busy,
            maxLength: 60,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: S.name),
            validator: (v) => (v ?? '').trim().isEmpty ? S.nameRequired : null,
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _username,
            enabled: !_busy,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: S.username,
              helperText: S.usernameHelp,
              prefixText: '@',
            ),
            validator: (v) =>
                _usernameRe.hasMatch((v ?? '').trim().toLowerCase())
                ? null
                : S.usernameInvalid,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bio,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: S.bio,
              hintText: S.bioHint,
            ),
          ),
          const SizedBox(height: 8),
          CraftPicker(
            value: _category,
            allowNone: !widget.me.isBusiness,
            enabled: !_busy,
            onChanged: (v) => setState(() => _category = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            FormErrorBox(message: _error!),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? S.saving : S.save),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "Hünäriňiz": the profile craft as chips (`GET /profile-categories`).
/// [allowNone] adds "Ýok" (`""`); business accounts must keep a craft.
class CraftPicker extends ConsumerWidget {
  const CraftPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowNone = true,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool allowNone;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final cats =
        ref.watch(profileCategoriesProvider).value ??
        [
          for (final e in businessCategoryNames.entries)
            Category(slug: e.key, name: e.value),
        ];
    Widget chip(String slug, String label) => ChoiceChip(
      key: Key('craft-${slug.isEmpty ? 'none' : slug}'),
      label: Text(label),
      selected: value == slug,
      showCheckmark: false,
      onSelected: enabled ? (_) => onChanged(slug) : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(S.craft, style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          allowNone ? S.craftHelp : S.craftBusinessHelp,
          style: TextStyle(color: p.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (allowNone) chip('', S.craftNone),
            for (final c in cats) chip(c.slug, c.name),
            // A craft the list no longer has: keep it visible.
            if (value.isNotEmpty && !cats.any((c) => c.slug == value))
              chip(value, businessCategoryLabel(value)),
          ],
        ),
      ],
    );
  }
}

class _PasswordCard extends ConsumerStatefulWidget {
  const _PasswordCard();

  @override
  ConsumerState<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends ConsumerState<_PasswordCard> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .changePassword(_current.text, _new.text);
      _current.clear();
      _new.clear();
      _repeat.clear();
      showSnack(S.passwordChanged);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label);

  @override
  Widget build(BuildContext context) => _Card(
    title: S.changePassword,
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _current,
            enabled: !_busy,
            obscureText: true,
            decoration: _dec(S.currentPassword),
            validator: (v) =>
                (v ?? '').isEmpty ? S.currentPasswordRequired : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _new,
            enabled: !_busy,
            obscureText: true,
            decoration: _dec(S.newPassword),
            validator: (v) => (v ?? '').length < 6 ? S.passwordShort : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _repeat,
            enabled: !_busy,
            obscureText: true,
            decoration: _dec(S.repeatPassword),
            validator: (v) => v != _new.text ? S.passwordsMismatch : null,
            onFieldSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            FormErrorBox(message: _error!),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? S.saving : S.changePassword),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LogoutCard extends ConsumerWidget {
  const _LogoutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Card(
    title: S.logout,
    subtitle: S.logoutText,
    child: Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.danger,
          side: const BorderSide(color: AppPalette.danger, width: 2),
        ),
        onPressed: () async {
          final ok = await confirmDialog(
            context,
            title: S.logoutConfirm,
            text: S.logoutText,
            confirm: S.logout,
          );
          if (!ok) return;
          await ref.read(authProvider.notifier).logout();
          showSnack(S.loggedOut);
          if (context.mounted) context.go('/');
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text(S.logout),
      ),
    ),
  );
}

/// Quick links: my orders, cart.
class _ShopLinksCard extends StatelessWidget {
  const _ShopLinksCard();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget link(IconData icon, String label, String path) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: p.text),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: Icon(Icons.chevron_right_rounded, color: p.muted),
      onTap: () => context.push(path),
    );
    return _Card(
      title: S.myOrders,
      child: Column(
        children: [
          link(Icons.receipt_long_outlined, S.myOrders, '/orders'),
          link(Icons.shopping_bag_outlined, S.cart, '/cart'),
          link(Icons.block_rounded, S.blockedUsers, '/settings/blocked'),
          link(Icons.interests_outlined, S.myInterests, '/settings/interests'),
        ],
      ),
    );
  }
}

/// Sazlamalar → Serwer: the current API address, opens `/server`.
class _ServerCard extends ConsumerWidget {
  const _ServerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final s = ref.watch(serverProvider);
    return _Card(
      title: S.server,
      child: ListTile(
        key: const Key('settings-server'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.dns_outlined, color: p.text),
        title: Text(
          s.apiUrl,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(serverSourceLabel(s.source)),
        trailing: Icon(Icons.chevron_right_rounded, color: p.muted),
        onTap: () => context.push('/server'),
      ),
    );
  }
}

/// Shown to admins: opens `{webUrl}/admin` in the browser.
class _AdminCard extends StatelessWidget {
  const _AdminCard();

  Future<void> _open() async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(AppConfig.adminLink),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!ok) showSnack(S.adminPanelFailed, error: true);
  }

  @override
  Widget build(BuildContext context) => _Card(
    title: S.adminPanel,
    subtitle: S.adminPanelText,
    child: Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        key: const Key('settings-admin'),
        onPressed: _open,
        icon: const Icon(Icons.admin_panel_settings_outlined),
        label: const Text(S.adminPanelOpen),
      ),
    ),
  );
}

/// `/settings/blocked`: users I blocked, with "Petigi aýyr".
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  List<UserBrief>? _users;
  Object? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final u = await ref.read(usersRepositoryProvider).blocks();
      if (mounted) setState(() => _users = u);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _unblock(UserBrief u) async {
    setState(() => _busy.add(u.username));
    try {
      await ref.read(usersRepositoryProvider).unblock(u.username);
      showSnack(S.unblocked);
      if (mounted) {
        setState(() => _users = [..._users!]..removeWhere((x) => x.id == u.id));
      }
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _busy.remove(u.username));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return Scaffold(
      appBar: AppBar(title: const Text(S.blockedUsers)),
      body: users == null
          ? (_error == null
                ? const LoadingView()
                : ErrorView(error: _error!, onRetry: _load))
          : users.isEmpty
          ? const EmptyView(icon: Icons.block_rounded, title: S.noBlockedUsers)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: users.length,
              separatorBuilder: (_, _) => const SizedBox(height: 2),
              itemBuilder: (context, i) {
                final u = users[i];
                return ListTile(
                  leading: UserAvatar(user: u, size: 44),
                  title: Text(
                    u.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('@${u.username}'),
                  trailing: ElevatedButton(
                    onPressed: _busy.contains(u.username)
                        ? null
                        : () => _unblock(u),
                    child: const Text(S.unblock),
                  ),
                );
              },
            ),
    );
  }
}
