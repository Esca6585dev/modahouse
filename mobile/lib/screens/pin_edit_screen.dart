import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/format.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import '../widgets/app_image.dart';
import '../widgets/board_form.dart';
import '../widgets/pin_fields.dart';
import '../widgets/states.dart';

class PinEditScreen extends ConsumerStatefulWidget {
  const PinEditScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<PinEditScreen> createState() => _PinEditScreenState();
}

class _PinEditScreenState extends ConsumerState<PinEditScreen> {
  final _formKey = GlobalKey<FormState>();
  Pin? _pin;
  Object? _error;
  PinFieldControllers? _fields;
  bool _busy = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fields?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final pin = await ref.read(pinsRepositoryProvider).get(widget.id);
      if (!mounted) return;
      _fields?.dispose();
      setState(() {
        _pin = pin;
        _fields = PinFieldControllers(
          title: pin.title,
          description: pin.description,
          link: pin.link,
          tags: pin.tags.join(', '),
          category: pin.category,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save() async {
    final f = _fields;
    final pin = _pin;
    if (f == null || pin == null || _busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final updated = await ref.read(pinsRepositoryProvider).update(
            pin.id,
            title: f.title.text.trim(),
            description: f.description.text.trim(),
            link: f.link.text.trim(),
            category: f.category,
            tags: splitTags(f.tags.text).join(','),
          );
      ref.read(pinUpdatesProvider.notifier).updated(updated);
      showSnack(S.changesSaved);
      if (mounted) context.pop(updated);
    } catch (e) {
      if (mounted) setState(() => _formError = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;
    final pin = _pin;
    final f = _fields;
    final p = AppPalette.of(context);

    Widget body;
    if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (pin == null || f == null) {
      body = const LoadingView();
    } else if (me == null || me.id != pin.author.id) {
      body = const EmptyView(icon: Icons.lock_outline_rounded, title: S.forbidden, text: S.onlyOwnPins);
    } else {
      body = Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppPalette.gutter, 8, AppPalette.gutter, 32),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 220,
                  child: AspectRatio(
                    aspectRatio: pin.aspectRatio,
                    child: AppImage(pin.imageUrl, placeholder: parseHexColor(pin.color, p.surface)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PinFields(
              controllers: f,
              enabled: !_busy,
              onCategoryChanged: (v) => setState(() => f.category = v),
            ),
            if (_formError != null) ...[
              const SizedBox(height: 16),
              FormErrorBox(message: _formError!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? S.saving : S.save),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(S.editPin)),
      body: SafeArea(top: false, child: body),
    );
  }
}
