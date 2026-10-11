import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/pins_repository.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import 'shop_ui.dart';

/// Preset colors offered when adding a product color.
const presetColors = <ColorOption>[
  ColorOption(name: 'Gyzyl', hex: '#C62828'),
  ColorOption(name: 'Gyrmyzy', hex: '#8E1B3A'),
  ColorOption(name: 'Gülgüne', hex: '#EC407A'),
  ColorOption(name: 'Mämişi', hex: '#EF6C00'),
  ColorOption(name: 'Sary', hex: '#F9A825'),
  ColorOption(name: 'Altyn', hex: '#C9A227'),
  ColorOption(name: 'Ýaşyl', hex: '#2E7D32'),
  ColorOption(name: 'Gök', hex: '#1565C0'),
  ColorOption(name: 'Benewşe', hex: '#6A1B9A'),
  ColorOption(name: 'Goňur', hex: '#6D4C41'),
  ColorOption(name: 'Bej', hex: '#D7C4A3'),
  ColorOption(name: 'Çal', hex: '#9E9E9E'),
  ColorOption(name: 'Gara', hex: '#212121'),
  ColorOption(name: 'Ak', hex: '#FFFFFF'),
];

const _sizePresets = [
  ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
  ['40', '42', '44', '46', '48', '50', '52'],
];

/// Controllers for the product fields (create and edit).
class ProductFormControllers {
  ProductFormControllers({Product? initial, int? deliveryDays, int? returnDays})
    : price = TextEditingController(
        text: initial == null ? '' : '${initial.price}',
      ),
      oldPrice = TextEditingController(
        text: initial == null || initial.oldPrice == 0
            ? ''
            : '${initial.oldPrice}',
      ),
      stock = TextEditingController(
        text: initial?.stock == null ? '' : '${initial!.stock}',
      ),
      delivery = TextEditingController(
        text: '${initial?.deliveryDays ?? deliveryDays ?? ''}',
      ),
      returns = TextEditingController(
        text: '${initial?.returnDays ?? returnDays ?? ''}',
      ),
      material = TextEditingController(text: initial?.material ?? ''),
      colors = [...?initial?.colors],
      sizes = [...?initial?.sizes];

  final TextEditingController price;
  final TextEditingController oldPrice;
  final TextEditingController stock;
  final TextEditingController delivery;
  final TextEditingController returns;
  final TextEditingController material;
  final List<ColorOption> colors;
  final List<String> sizes;

  ProductInput toInput() => ProductInput(
    price: int.tryParse(price.text.trim()) ?? 0,
    oldPrice: int.tryParse(oldPrice.text.trim()) ?? 0,
    stock: int.tryParse(stock.text.trim()),
    deliveryDays: int.tryParse(delivery.text.trim()),
    returnDays: int.tryParse(returns.text.trim()),
    material: material.text.trim(),
    colors: colors,
    sizes: sizes,
  );

  void clear() {
    for (final c in [price, oldPrice, stock, material]) {
      c.clear();
    }
    colors.clear();
    sizes.clear();
  }

  void dispose() {
    for (final c in [price, oldPrice, stock, delivery, returns, material]) {
      c.dispose();
    }
  }
}

/// Price, old price, stock, delivery/return days, material, colors, sizes.
class ProductFields extends StatefulWidget {
  const ProductFields({
    super.key,
    required this.controllers,
    required this.enabled,
  });

  final ProductFormControllers controllers;
  final bool enabled;

  @override
  State<ProductFields> createState() => _ProductFieldsState();
}

class _ProductFieldsState extends State<ProductFields> {
  final _size = TextEditingController();

  ProductFormControllers get c => widget.controllers;

  @override
  void dispose() {
    _size.dispose();
    super.dispose();
  }

  void _addSize(String raw) {
    final v = raw.trim();
    if (v.isEmpty || c.sizes.contains(v)) return;
    setState(() => c.sizes.add(v));
    _size.clear();
  }

  Future<void> _addColor() async {
    final color = await showDialog<ColorOption>(
      context: context,
      builder: (_) => const _ColorDialog(),
    );
    if (color != null && !c.colors.any((x) => x.name == color.name)) {
      setState(() => c.colors.add(color));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    const gap = SizedBox(height: 16);
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        t,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('product-price'),
                controller: c.price,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                decoration: const InputDecoration(
                  labelText: '${S.priceLabel} *',
                  suffixText: S.currency,
                ),
                validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) <= 0
                    ? S.priceRequired
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: c.oldPrice,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                decoration: const InputDecoration(
                  labelText: S.oldPriceLabel,
                  suffixText: S.currency,
                ),
                validator: (v) {
                  final old = int.tryParse((v ?? '').trim()) ?? 0;
                  final price = int.tryParse(c.price.text.trim()) ?? 0;
                  return old != 0 && old <= price ? S.oldPriceInvalid : null;
                },
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            S.oldPriceHelp,
            style: TextStyle(color: p.muted, fontSize: 12),
          ),
        ),
        gap,
        TextFormField(
          controller: c.stock,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          inputFormatters: digits,
          decoration: const InputDecoration(
            labelText: S.stockLabel,
            helperText: S.stockHelp,
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
        ),
        gap,
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: c.delivery,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                decoration: const InputDecoration(
                  labelText: S.deliveryDaysLabel,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: c.returns,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                decoration: const InputDecoration(labelText: S.returnDaysLabel),
              ),
            ),
          ],
        ),
        gap,
        TextFormField(
          controller: c.material,
          enabled: widget.enabled,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: S.materialLabel,
            hintText: S.materialHint,
            prefixIcon: Icon(Icons.layers_outlined),
          ),
        ),
        const SizedBox(height: 8),
        label(S.colorsLabel),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final col in c.colors)
              InputChip(
                avatar: CircleAvatar(
                  backgroundColor: parseHexColor(col.hex, p.surface),
                  radius: 10,
                ),
                label: Text(col.name),
                onDeleted: widget.enabled
                    ? () => setState(() => c.colors.remove(col))
                    : null,
              ),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text(S.addColor),
              onPressed: widget.enabled ? _addColor : null,
            ),
          ],
        ),
        gap,
        label(S.sizesLabel),
        if (c.sizes.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in c.sizes)
                InputChip(
                  label: Text(s),
                  onDeleted: widget.enabled
                      ? () => setState(() => c.sizes.remove(s))
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('size-input'),
                controller: _size,
                enabled: widget.enabled,
                textInputAction: TextInputAction.done,
                onSubmitted: _addSize,
                decoration: const InputDecoration(
                  hintText: S.sizeHint,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: widget.enabled ? () => _addSize(_size.text) : null,
              child: const Text(S.addSize),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final row in _sizePresets)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in row)
                  SizeChip(
                    label: s,
                    selected: c.sizes.contains(s),
                    onTap: !widget.enabled
                        ? null
                        : () => setState(
                            () => c.sizes.contains(s)
                                ? c.sizes.remove(s)
                                : c.sizes.add(s),
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog();

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  final _name = TextEditingController();
  ColorOption _picked = presetColors.first;

  @override
  void initState() {
    super.initState();
    _name.text = _picked.name;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(S.addColor),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                for (final c in presetColors)
                  ColorSwatchButton(
                    option: c,
                    size: 32,
                    selected: c.hex == _picked.hex,
                    onTap: () => setState(() {
                      _picked = c;
                      _name.text = c.name;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 30,
              decoration: const InputDecoration(labelText: S.colorName),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, ColorOption(name: name, hex: _picked.hex));
          },
          child: const Text(S.addColor),
        ),
      ],
    );
  }
}
