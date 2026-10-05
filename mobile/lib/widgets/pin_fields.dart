import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/providers.dart';

/// Controllers for the pin text fields shared by "create" and "edit".
class PinFieldControllers {
  PinFieldControllers({
    String title = '',
    String description = '',
    String link = '',
    String tags = '',
    this.category,
  }) : title = TextEditingController(text: title),
       description = TextEditingController(text: description),
       link = TextEditingController(text: link),
       tags = TextEditingController(text: tags);

  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController link;
  final TextEditingController tags;
  String? category;

  void clear() {
    title.clear();
    description.clear();
    link.clear();
    tags.clear();
    category = null;
  }

  void dispose() {
    title.dispose();
    description.dispose();
    link.dispose();
    tags.dispose();
  }
}

String? validateLink(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return null;
  final uri = Uri.tryParse(s);
  final ok =
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
  return ok ? null : S.linkInvalid;
}

/// Title, description, link, category and tags.
class PinFields extends ConsumerWidget {
  const PinFields({
    super.key,
    required this.controllers,
    required this.enabled,
    required this.onCategoryChanged,
  });

  final PinFieldControllers controllers;
  final bool enabled;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider).value ?? const [];
    final c = controllers;
    final selected = cats.any((x) => x.slug == c.category) ? c.category : null;
    const gap = SizedBox(height: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: c.title,
          enabled: enabled,
          maxLength: 100,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '${S.title} *',
            hintText: S.titleHint,
          ),
          validator: (v) => (v ?? '').trim().isEmpty ? S.titleRequired : null,
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: c.description,
          enabled: enabled,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: S.description,
            hintText: S.descriptionHint,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: c.link,
          enabled: enabled,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: S.link,
            hintText: S.linkHint,
          ),
          validator: validateLink,
        ),
        gap,
        DropdownButtonFormField<String>(
          key: ValueKey('cat-${cats.length}-$selected'),
          initialValue: selected,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          decoration: const InputDecoration(labelText: '${S.category} *'),
          hint: const Text(S.categoryRequired),
          items: [
            for (final cat in cats)
              DropdownMenuItem(value: cat.slug, child: Text(cat.name)),
          ],
          onChanged: enabled ? onCategoryChanged : null,
          validator: (v) => v == null || v.isEmpty ? S.categoryRequired : null,
        ),
        gap,
        TextFormField(
          controller: c.tags,
          enabled: enabled,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: S.tags,
            hintText: S.tagsHint,
            helperText: S.tagsHelp,
          ),
        ),
      ],
    );
  }
}
