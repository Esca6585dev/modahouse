import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/providers.dart';
import '../state/shop_state.dart';
import 'app_image.dart';
import 'shop_ui.dart';
import 'states.dart';

/// What the checkout screen needs for "Zakaz et" (buy one product now).
class CheckoutArgs {
  const CheckoutArgs({this.buyNow, this.pin});

  final BuyNow? buyNow;

  /// Shown in the summary for buy-now.
  final Pin? pin;
}

/// Sends logged-out users to the login screen. Returns true when logged in.
bool ensureLoggedIn(BuildContext context, WidgetRef ref, String from) {
  if (ref.read(authProvider).isLoggedIn) return true;
  context.push('/login?from=${Uri.encodeComponent(from)}');
  return false;
}

/// Adds a product to the cart and shows "Sebede goşuldy" with a link to it.
Future<bool> addToCart(
  BuildContext context,
  WidgetRef ref,
  Pin pin, {
  String color = '',
  String size = '',
  int quantity = 1,
}) async {
  final router = GoRouter.of(context);
  try {
    final cart = await ref
        .read(cartRepositoryProvider)
        .add(pin.id, color: color, size: size, quantity: quantity);
    ref.read(cartCountProvider.notifier).set(cart.count);
    showSnack(
      S.addedToCart,
      actionLabel: S.goToCart,
      onAction: () => router.push('/cart'),
    );
    return true;
  } catch (e) {
    showError(e);
    return false;
  }
}

/// The cart button on product cards: adds directly, or asks for the color and
/// size first when the product has options.
Future<void> quickAddToCart(
  BuildContext context,
  WidgetRef ref,
  Pin pin,
) async {
  final product = pin.product;
  if (product == null) return;
  if (!product.isSale) {
    await context.push('/pin/${pin.id}');
    return;
  }
  if (!ensureLoggedIn(context, ref, '/pin/${pin.id}')) return;
  if (ref.read(authProvider).user?.id == pin.author.id) {
    showSnack(S.ownProduct);
    return;
  }
  if (!product.inStock) {
    showSnack(S.outOfStock, error: true);
    return;
  }
  if (!product.hasOptions) {
    await addToCart(context, ref, pin);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ProductOptionsSheet(pin: pin),
  );
}

/// Bottom sheet: choose color, size and quantity, then add to the cart or buy.
class ProductOptionsSheet extends ConsumerStatefulWidget {
  const ProductOptionsSheet({super.key, required this.pin});

  final Pin pin;

  @override
  ConsumerState<ProductOptionsSheet> createState() =>
      _ProductOptionsSheetState();
}

class _ProductOptionsSheetState extends ConsumerState<ProductOptionsSheet> {
  String _color = '';
  String _size = '';
  int _qty = 1;
  bool _busy = false;
  bool _showErrors = false;

  Product get product => widget.pin.product!;

  @override
  void initState() {
    super.initState();
    if (product.colors.length == 1) _color = product.colors.first.name;
    if (product.sizes.length == 1) _size = product.sizes.first;
  }

  bool get _valid =>
      (product.colors.isEmpty || _color.isNotEmpty) &&
      (product.sizes.isEmpty || _size.isNotEmpty);

  Future<void> _add() async {
    if (!_valid) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _busy = true);
    final ok = await addToCart(
      context,
      ref,
      widget.pin,
      color: _color,
      size: _size,
      quantity: _qty,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  void _buy() {
    if (!_valid) {
      setState(() => _showErrors = true);
      return;
    }
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(
      '/checkout',
      extra: CheckoutArgs(
        pin: widget.pin,
        buyNow: BuyNow(
          pinId: widget.pin.id,
          color: _color,
          size: _size,
          quantity: _qty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pin = widget.pin;
    final maxQty = product.stock == null ? 99 : product.stock!.clamp(1, 99);
    Widget label(String text, bool missing) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: missing && _showErrors ? AppPalette.danger : p.text,
        ),
      ),
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 72,
                  height: 90,
                  child: AppImage(
                    pin.imageUrl,
                    placeholder: parseHexColor(pin.color, p.surface),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pin.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    PriceText(
                      price: product.price,
                      oldPrice: product.oldPrice,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (product.colors.isNotEmpty) ...[
            label(
              _color.isEmpty ? S.chooseColor : '${S.color}: $_color',
              _color.isEmpty,
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in product.colors)
                  ColorSwatchButton(
                    option: c,
                    selected: c.name == _color,
                    onTap: () => setState(() => _color = c.name),
                  ),
              ],
            ),
          ],
          if (product.sizes.isNotEmpty) ...[
            label(
              _size.isEmpty ? S.chooseSize : '${S.size}: $_size',
              _size.isEmpty,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in product.sizes)
                  SizeChip(
                    label: s,
                    selected: s == _size,
                    onTap: () => setState(() => _size = s),
                  ),
              ],
            ),
          ],
          label(S.quantity, false),
          QuantityStepper(
            value: _qty,
            max: maxQty,
            onChanged: (v) => setState(() => _qty = v),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _add,
                  icon: _busy
                      ? const Spinner(size: 16)
                      : const Icon(Icons.add_shopping_cart_rounded, size: 20),
                  label: const Text(S.addToCart),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _buy,
                  icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                  label: const Text(S.buyNow),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
