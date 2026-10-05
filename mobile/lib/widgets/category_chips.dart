import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../state/providers.dart';
import 'states.dart';

/// Horizontal category chips ("Hemmesi" + every category from the API).
class CategoryChips extends ConsumerWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    return SizedBox(
      height: 40,
      child: cats.when(
        data: (list) => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppPalette.gutter),
          children: [
            PillChip(
              label: S.all,
              active: selected == null,
              onTap: () => onSelected(null),
            ),
            for (final c in list)
              PillChip(
                label: c.name,
                active: selected == c.slug,
                onTap: () => onSelected(c.slug),
              ),
          ],
        ),
        loading: () => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppPalette.gutter),
          children: [
            for (var i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Skeleton(width: 92, height: 40, radius: 20),
              ),
          ],
        ),
        error: (e, _) => Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => ref.invalidate(categoriesProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(S.retry),
          ),
        ),
      ),
    );
  }
}

class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: active,
        button: true,
        child: Material(
          color: active ? p.text : p.surface,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: active ? p.bg : p.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
