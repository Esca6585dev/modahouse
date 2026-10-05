import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_exception.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/providers.dart';
import '../widgets/avatar.dart';
import '../widgets/board_form.dart';
import '../widgets/states.dart';
import 'create_screen.dart' show pickImage;

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
              padding: const EdgeInsets.fromLTRB(AppPalette.gutter, 8, AppPalette.gutter, 32),
              children: [
                _AvatarCard(me: me),
                _ProfileCard(me: me),
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
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
    await _run(() => ref.read(authRepositoryProvider).uploadAvatar(img), S.avatarUpdated);
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
                FilledButton(onPressed: _busy ? null : _change, child: const Text(S.changeAvatar)),
                if (me.avatarUrl.isNotEmpty)
                  ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => ref.read(authRepositoryProvider).deleteAvatar(), S.avatarRemoved),
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
      final me = await ref.read(authRepositoryProvider).updateMe(
            name: _name.text.trim(),
            username: _username.text.trim().toLowerCase(),
            bio: _bio.text.trim(),
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
                decoration: const InputDecoration(labelText: S.username, helperText: S.usernameHelp, prefixText: '@'),
                validator: (v) => _usernameRe.hasMatch((v ?? '').trim().toLowerCase()) ? null : S.usernameInvalid,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bio,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                decoration: const InputDecoration(labelText: S.bio, hintText: S.bioHint),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                FormErrorBox(message: _error!),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? S.saving : S.save)),
              ),
            ],
          ),
        ),
      );
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
      await ref.read(authProvider.notifier).changePassword(_current.text, _new.text);
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
                validator: (v) => (v ?? '').isEmpty ? S.currentPasswordRequired : null,
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
              final ok = await confirmDialog(context, title: S.logoutConfirm, text: S.logoutText, confirm: S.logout);
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
