import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/interests.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import '../widgets/board_form.dart';
import '../widgets/category_chips.dart';
import '../widgets/states.dart';

/// `/interests`: the one-time "Näme bilen gyzyklanýarsyňyz?" screen shown
/// after signing in while nothing is picked. At least one post category
/// must be chosen; "Geçmek" skips it for good.
class InterestsPickScreen extends ConsumerStatefulWidget {
  const InterestsPickScreen({super.key});

  @override
  ConsumerState<InterestsPickScreen> createState() =>
      _InterestsPickScreenState();
}

class _InterestsPickScreenState extends ConsumerState<InterestsPickScreen> {
  final Set<String> _selected = {};
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Shown once: leaving with the back button counts as skipping.
    final id = ref.read(currentUserIdProvider);
    if (id != null) const InterestsPromptStore().markShown(id);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _save() async {
    if (_busy || _selected.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(usersRepositoryProvider).pickInterests(_selected.toList());
      ref.read(pinUpdatesProvider.notifier).reloadFeeds();
      showSnack(S.interestsSaved);
      if (mounted) _close();
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final cats = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            key: const Key('interests-skip'),
            onPressed: _busy ? null : _close,
            child: const Text(S.interestsSkip),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppPalette.gutter,
          4,
          AppPalette.gutter,
          24,
        ),
        children: [
          const Text(
            S.interestsTitle,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(S.interestsText, style: TextStyle(color: p.muted)),
          const SizedBox(height: 20),
          cats.when(
            data: (list) => Wrap(
              runSpacing: 10,
              children: [
                for (final c in list)
                  SizedBox(
                    height: 40,
                    child: PillChip(
                      key: Key('interest-${c.slug}'),
                      label: c.name,
                      active: _selected.contains(c.slug),
                      onTap: () => setState(() {
                        if (!_selected.remove(c.slug)) _selected.add(c.slug);
                      }),
                    ),
                  ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Spinner()),
            ),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(categoriesProvider),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            FormErrorBox(message: _error!),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppPalette.gutter,
          8,
          AppPalette.gutter,
          12,
        ),
        child: FilledButton(
          key: const Key('interests-continue'),
          onPressed: _busy || _selected.isEmpty ? null : _save,
          child: Text(_busy ? S.saving : S.interestsContinue(_selected.length)),
        ),
      ),
    );
  }
}

/// `/settings/interests`: "Gyzyklanmalarym", what the server learned, with
/// a reset button.
class MyInterestsScreen extends ConsumerStatefulWidget {
  const MyInterestsScreen({super.key});

  @override
  ConsumerState<MyInterestsScreen> createState() => _MyInterestsScreenState();
}

class _MyInterestsScreenState extends ConsumerState<MyInterestsScreen> {
  Interests? _data;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await ref.read(usersRepositoryProvider).interests();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _reset() async {
    final ok = await confirmDialog(
      context,
      title: S.interestsResetConfirm,
      text: S.interestsResetText,
      confirm: S.interestsReset,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(usersRepositoryProvider).resetInterests();
      ref.read(pinUpdatesProvider.notifier).reloadFeeds();
      showSnack(S.interestsResetDone);
      if (mounted) setState(() => _data = const Interests());
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    await context.push('/interests');
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final data = _data;
    Widget body;
    if (data == null) {
      body = _error == null
          ? const LoadingView()
          : ErrorView(error: _error!, onRetry: _load);
    } else if (data.items.isEmpty) {
      body = EmptyView(
        icon: Icons.interests_outlined,
        title: S.interestsEmpty,
        text: S.interestsEmptyText,
        action: FilledButton(
          key: const Key('interests-pick'),
          onPressed: _pick,
          child: const Text(S.interestsPick),
        ),
      );
    } else {
      final top = data.items
          .map((e) => e.score)
          .fold<double>(0, (a, b) => b > a ? b : a);
      body = RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppPalette.gutter,
            4,
            AppPalette.gutter,
            32,
          ),
          children: [
            Text(S.myInterestsText, style: TextStyle(color: p.muted)),
            const SizedBox(height: 12),
            for (final it in data.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      it.isTag ? Icons.tag_rounded : Icons.category_outlined,
                      size: 20,
                      color: p.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.isTag ? '#${it.name}' : it.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: top > 0 ? (it.score / top) : 0,
                              minHeight: 5,
                              color: AppPalette.accent,
                              backgroundColor: p.surface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      it.isTag ? S.interestTag : S.interestCategory,
                      style: TextStyle(color: p.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _pick,
                  child: const Text(S.interestsPick),
                ),
                OutlinedButton.icon(
                  key: const Key('interests-reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.danger,
                    side: const BorderSide(color: AppPalette.danger, width: 2),
                  ),
                  onPressed: _busy ? null : _reset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text(S.interestsReset),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text(S.myInterests)),
      body: body,
    );
  }
}
