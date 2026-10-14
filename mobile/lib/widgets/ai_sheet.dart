import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../data/common.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/providers.dart';
import 'states.dart';

/// Whether the server writes with Claude (false = template suggestions).
final aiEnabledProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.watch(aiRepositoryProvider).enabled();
  } catch (_) {
    return false;
  }
});

/// "✨ AI bilen ýaz": asks `POST /ai/suggest` and shows the suggestion with
/// Goş / Täzeden / Ýap. Returns the suggestion to insert, or null.
Future<Suggestion?> showAiSuggestSheet(
  BuildContext context, {
  required ListingType listingType,
  String category = '',
  String title = '',
  PickedImage? image,
}) => showModalBottomSheet<Suggestion>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  builder: (_) => _AiSheet(
    listingType: listingType,
    category: category,
    title: title,
    image: image,
  ),
);

class _AiSheet extends ConsumerStatefulWidget {
  const _AiSheet({
    required this.listingType,
    required this.category,
    required this.title,
    this.image,
  });

  final ListingType listingType;
  final String category;
  final String title;
  final PickedImage? image;

  @override
  ConsumerState<_AiSheet> createState() => _AiSheetState();
}

class _AiSheetState extends ConsumerState<_AiSheet> {
  final _notes = TextEditingController();
  Suggestion? _s;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await ref
          .read(aiRepositoryProvider)
          .suggest(
            listingType: widget.listingType,
            category: widget.category,
            title: widget.title,
            notes: _notes.text.trim(),
            image: widget.image,
          );
      if (mounted) setState(() => _s = s);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = _s;
    final enabled = ref.watch(aiEnabledProvider).value ?? true;
    final template = !enabled || (s?.isTemplate ?? false);
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        t,
        style: TextStyle(
          color: p.muted,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppPalette.accent),
              const SizedBox(width: 8),
              const Text(
                S.aiTitle,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(width: 8),
              if (template)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    S.aiTemplate,
                    style: TextStyle(
                      color: p.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (template)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                S.aiTemplateNote,
                style: TextStyle(color: p.muted, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            enabled: !_busy,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: S.aiNotes,
              isDense: true,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: _busy && s == null
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Spinner()),
                    )
                  : _error != null && s == null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        errorMessage(_error),
                        style: const TextStyle(color: AppPalette.danger),
                      ),
                    )
                  : s == null
                  ? const SizedBox.shrink()
                  : Opacity(
                      opacity: _busy ? 0.4 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          label(S.title),
                          Text(
                            s.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16.5,
                            ),
                          ),
                          if (s.description.isNotEmpty) ...[
                            label(S.description),
                            Text(
                              s.description,
                              style: const TextStyle(height: 1.45),
                            ),
                          ],
                          if (s.priceLine.isNotEmpty) ...[
                            label(S.priceLabel.replaceAll(' (TMT)', '')),
                            Text(
                              s.priceLine,
                              style: const TextStyle(
                                color: AppPalette.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          if (s.details.isNotEmpty) ...[
                            label(S.details),
                            for (final d in s.details)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text('• $d'),
                              ),
                          ],
                          if (s.hashtags.isNotEmpty) ...[
                            label(S.hashtags),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final t in s.hashtags)
                                  Chip(
                                    label: Text('#$t'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: p.text),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(S.close),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _busy ? null : _run,
                icon: _busy
                    ? const Spinner(size: 16)
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_busy ? S.aiWorking : S.aiRegenerate),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('ai-insert'),
                onPressed: s == null || _busy
                    ? null
                    : () => Navigator.of(context).pop(s),
                child: const Text(S.aiInsert),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
