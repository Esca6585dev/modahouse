import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../state/auth.dart';
import '../widgets/board_form.dart';
import '../widgets/states.dart';

final _usernameRe = RegExp(r'^[a-z0-9._]{3,30}$');
final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Only allow in-app paths as "return to" targets.
String? safeFrom(String? from) =>
    from != null && from.startsWith('/') && !from.startsWith('//') && !from.startsWith('/login') && !from.startsWith('/register')
        ? from
        : null;

/// After login/registration go back to the screen that asked for it.
void _finish(BuildContext context, String? from) {
  if (context.canPop()) {
    context.pop(true);
  } else {
    context.go(safeFrom(from) ?? '/');
  }
}

String _query(String? from) {
  final f = safeFrom(from);
  return f == null ? '' : '?from=${Uri.encodeComponent(f)}';
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LogoMark(size: 56)),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.validator,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onFieldSubmitted: widget.onSubmitted,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: IconButton(
            tooltip: _obscure ? S.showPassword : S.hidePassword,
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          ),
        ),
      );
}

/// Login form (username or email + password). [onSuccess] runs after login.
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key, required this.onSuccess, this.onRegister});

  final VoidCallback onSuccess;
  final VoidCallback? onRegister;

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(_login.text, _password.text);
      if (mounted) widget.onSuccess();
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('login-field'),
              controller: _login,
              enabled: !_busy,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(labelText: S.loginField),
              validator: (v) => (v ?? '').trim().isEmpty ? S.loginRequired : null,
            ),
            const SizedBox(height: 16),
            PasswordField(
              key: const Key('password-field'),
              controller: _password,
              label: S.password,
              enabled: !_busy,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              validator: (v) => (v ?? '').isEmpty ? S.passwordRequired : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              FormErrorBox(message: _error!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('login-submit'),
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? S.loggingIn : S.login),
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: '${S.demoTitle}: ${S.demoHint}',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _busy
                    ? null
                    : () {
                        final parts = S.demoHint.split(' / ');
                        _login.text = parts.first;
                        _password.text = parts.last;
                      },
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16)),
                  child: ExcludeSemantics(
                    child: Column(
                      children: [
                        Text(S.demoTitle, style: TextStyle(color: p.muted, fontSize: 14)),
                        const SizedBox(height: 2),
                        const Text(
                          S.demoHint,
                          style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.onRegister != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(S.noAccount, style: TextStyle(color: p.muted)),
                  TextButton(onPressed: widget.onRegister, child: const Text(S.register)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.from});

  final String? from;

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: S.welcome,
        subtitle: S.loginSubtitle,
        child: LoginForm(
          onSuccess: () => _finish(context, from),
          onRegister: () => context.pushReplacement('/register${_query(from)}'),
        ),
      );
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).register(
            username: _username.text.trim().toLowerCase(),
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
      if (mounted) _finish(context, widget.from);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const gap = SizedBox(height: 16);
    return _AuthScaffold(
      title: S.registerTitle,
      subtitle: S.registerSubtitle,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: S.name, hintText: S.nameHint),
                validator: (v) => (v ?? '').trim().isEmpty ? S.nameRequired : null,
              ),
              gap,
              TextFormField(
                controller: _username,
                enabled: !_busy,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                decoration: const InputDecoration(labelText: S.username, helperText: S.usernameHelp),
                validator: (v) => _usernameRe.hasMatch((v ?? '').trim().toLowerCase()) ? null : S.usernameInvalid,
              ),
              gap,
              TextFormField(
                controller: _email,
                enabled: !_busy,
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: S.email),
                validator: (v) => _emailRe.hasMatch((v ?? '').trim()) ? null : S.emailInvalid,
              ),
              gap,
              PasswordField(
                controller: _password,
                label: S.password,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                validator: (v) => (v ?? '').length < 6 ? S.passwordShort : null,
              ),
              if (_error != null) ...[
                gap,
                FormErrorBox(message: _error!),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? S.registering : S.register),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(S.haveAccount, style: TextStyle(color: p.muted)),
                  TextButton(
                    onPressed: _busy ? null : () => context.pushReplacement('/login${_query(widget.from)}'),
                    child: const Text(S.loginAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
