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
import '../state/providers.dart';
import '../state/shop_state.dart';
import '../widgets/app_image.dart';
import '../widgets/avatar.dart';
import '../widgets/board_form.dart';
import '../widgets/cart_flow.dart';
import '../widgets/shop_ui.dart';
import '../widgets/states.dart';
import 'business_screens.dart' show validatePhone;

/// `/cart`: lines grouped by shop, quantities, total and "Sargyt et".
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  Cart? _cart;
  Object? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _set(Cart cart) {
    ref.read(cartCountProvider.notifier).set(cart.count);
    if (mounted) setState(() => _cart = cart);
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      _set(await ref.read(cartRepositoryProvider).get());
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(int id, Future<Cart> Function() action) async {
    setState(() => _busy.add(id));
    try {
      _set(await action());
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _clear() async {
    final ok = await confirmDialog(
      context,
      title: S.clearCart,
      text: S.clearCartText,
      confirm: S.clearCart,
    );
    if (!ok) return;
    await _run(-1, () => ref.read(cartRepositoryProvider).clear());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ordersVersionProvider, (_, _) => _load());
    final cart = _cart;
    final p = AppPalette.of(context);
    Widget body;
    if (cart == null) {
      body = _error == null
          ? const LoadingView()
          : ErrorView(error: _error!, onRetry: _load);
    } else if (cart.isEmpty) {
      body = EmptyView(
        icon: Icons.shopping_bag_outlined,
        title: S.cartEmptyTitle,
        text: S.cartEmptyText,
        action: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text(S.goShopping),
        ),
      );
    } else {
      body = RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppPalette.gutter,
            4,
            AppPalette.gutter,
            24,
          ),
          children: [
            for (final g in cart.byShop) ...[
              SectionCard(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push(
                        '/user/${Uri.encodeComponent(g.shop.username)}',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_outlined, size: 20),
                            const SizedBox(width: 8),
                            UserAvatar(user: g.shop, size: 26),
                            const SizedBox(width: 8),
                            Expanded(
                              child: UserName(
                                user: g.shop,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: p.muted),
                          ],
                        ),
                      ),
                    ),
                    Divider(color: p.border, height: 18),
                    for (final item in g.items)
                      _CartLine(
                        item: item,
                        busy: _busy.contains(item.id),
                        onQuantity: (q) => _run(
                          item.id,
                          () => ref
                              .read(cartRepositoryProvider)
                              .setQuantity(item.id, q),
                        ),
                        onRemove: () => _run(
                          item.id,
                          () =>
                              ref.read(cartRepositoryProvider).remove(item.id),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(S.subtotal, style: TextStyle(color: p.muted)),
                        const Spacer(),
                        Text(
                          formatPrice(g.subtotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Icon(Icons.payments_outlined, size: 18, color: p.muted),
                const SizedBox(width: 8),
                Text(
                  S.payOnDelivery,
                  style: TextStyle(color: p.muted, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final hasAvailable = cart?.items.any((i) => i.available) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          cart == null || cart.count == 0
              ? S.cartTitle
              : '${S.cartTitle} (${cart.count})',
        ),
        actions: [
          if (cart != null && !cart.isEmpty)
            IconButton(
              tooltip: S.clearCart,
              onPressed: _busy.isEmpty ? _clear : null,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: body,
      bottomNavigationBar: cart == null || cart.isEmpty
          ? null
          : Container(
              decoration: BoxDecoration(
                color: p.bg,
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.total,
                            style: TextStyle(color: p.muted, fontSize: 12.5),
                          ),
                          Text(
                            formatPrice(cart.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: AppPalette.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('cart-checkout'),
                          onPressed: hasAvailable && _busy.isEmpty
                              ? () => context.push(
                                  '/checkout',
                                  extra: const CheckoutArgs(),
                                )
                              : null,
                          icon: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 20,
                          ),
                          label: const Text(S.checkout),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.item,
    required this.busy,
    required this.onQuantity,
    required this.onRemove,
  });

  final CartItem item;
  final bool busy;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pin = item.pin;
    final options = [
      if (item.color.isNotEmpty) '${S.color}: ${item.color}',
      if (item.size.isNotEmpty) '${S.size}: ${item.size}',
    ].join(' · ');
    final max = pin.stock == null ? 99 : pin.stock!.clamp(1, 99);
    return Opacity(
      opacity: item.available ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => context.push('/pin/${pin.id}'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 96,
                  child: AppImage(
                    pin.imageUrl,
                    placeholder: parseHexColor(pin.color, p.surface),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          pin.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: S.remove,
                          onPressed: busy ? null : onRemove,
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: p.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (options.isNotEmpty)
                    Text(
                      options,
                      style: TextStyle(color: p.muted, fontSize: 12.5),
                    ),
                  if (!item.available)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        S.unavailable,
                        style: TextStyle(
                          color: AppPalette.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: PriceText(
                          price: pin.price,
                          oldPrice: pin.oldPrice,
                        ),
                      ),
                      if (busy)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Spinner(size: 16),
                        ),
                      QuantityStepper(
                        value: item.quantity,
                        max: max,
                        compact: true,
                        enabled: !busy && item.available,
                        onChanged: onQuantity,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `/checkout`: delivery details and the order summary; the cart or one
/// product ("Zakaz et").
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.args});

  final CheckoutArgs args;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: ref.read(authProvider).user?.name ?? '',
  );
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  Cart? _cart;
  Object? _error;
  bool _busy = false;
  String? _formError;
  List<Order>? _placed;

  BuyNow? get buyNow => widget.args.buyNow;

  @override
  void initState() {
    super.initState();
    if (buyNow == null) _loadCart();
    _prefill();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadCart() async {
    setState(() => _error = null);
    try {
      final c = await ref.read(cartRepositoryProvider).get();
      if (mounted) setState(() => _cart = c);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Reuse the phone and address of the last order.
  Future<void> _prefill() async {
    try {
      final page = await ref.read(ordersRepositoryProvider).mine(limit: 1);
      if (!mounted || page.items.isEmpty) return;
      final last = page.items.first;
      if (_phone.text.isEmpty) _phone.text = last.phone;
      if (_address.text.isEmpty) _address.text = last.address;
      if (last.fullName.isNotEmpty) _name.text = last.fullName;
    } catch (_) {
      // Optional.
    }
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final orders = await ref
          .read(ordersRepositoryProvider)
          .create(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            address: _address.text.trim(),
            note: _note.text.trim(),
            buyNow: buyNow,
          );
      ref.read(ordersVersionProvider.notifier).bump();
      await ref.read(cartCountProvider.notifier).refresh();
      if (mounted) setState(() => _placed = orders);
    } catch (e) {
      if (mounted) setState(() => _formError = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placed = _placed;
    if (placed != null) return OrderSuccessView(orders: placed);
    final p = AppPalette.of(context);
    const gap = SizedBox(height: 14);

    // Summary lines: (image, title, options, qty, price, shop).
    final lines = <_SummaryLine>[];
    var total = 0;
    final pin = widget.args.pin;
    final bn = buyNow;
    if (bn != null && pin != null) {
      final price = pin.product?.price ?? 0;
      lines.add(
        _SummaryLine(
          imageUrl: pin.imageUrl,
          title: pin.title,
          color: bn.color,
          size: bn.size,
          quantity: bn.quantity,
          price: price,
          shop: pin.author,
        ),
      );
      total = price * bn.quantity;
    } else if (_cart != null) {
      for (final i in _cart!.items.where((i) => i.available)) {
        lines.add(
          _SummaryLine(
            imageUrl: i.pin.imageUrl,
            title: i.pin.title,
            color: i.color,
            size: i.size,
            quantity: i.quantity,
            price: i.pin.price,
            shop: i.pin.author,
          ),
        );
      }
      total = _cart!.items
          .where((i) => i.available)
          .fold(0, (s, i) => s + i.lineTotal);
    }
    final loadingSummary = bn == null && _cart == null;

    return Scaffold(
      appBar: AppBar(title: const Text(S.checkoutTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppPalette.gutter,
            4,
            AppPalette.gutter,
            24,
          ),
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    S.orderSummary,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (loadingSummary)
                    _error == null
                        ? const LoadingView()
                        : ErrorView(
                            error: _error!,
                            onRetry: _loadCart,
                            compact: true,
                          )
                  else if (lines.isEmpty)
                    Text(S.nothingToOrder, style: TextStyle(color: p.muted))
                  else
                    for (final l in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 48,
                                height: 60,
                                child: AppImage(l.imageUrl),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    [
                                      l.shop.displayName,
                                      if (l.color.isNotEmpty) l.color,
                                      if (l.size.isNotEmpty) l.size,
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: p.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  Text(
                                    '${l.quantity} × ${formatPrice(l.price)}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatPrice(l.price * l.quantity),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  Divider(color: p.border),
                  Row(
                    children: [
                      const Text(
                        S.total,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        formatPrice(total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: AppPalette.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 16, color: p.muted),
                      const SizedBox(width: 6),
                      Text(
                        S.payOnDelivery,
                        style: TextStyle(color: p.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              S.deliveryInfo,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('checkout-name'),
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: S.fullName,
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? S.fullNameRequired : null,
            ),
            gap,
            TextFormField(
              key: const Key('checkout-phone'),
              controller: _phone,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: S.phone,
                hintText: S.phoneHint,
                prefixIcon: Icon(Icons.call_outlined),
              ),
              validator: validatePhone,
            ),
            gap,
            TextFormField(
              key: const Key('checkout-address'),
              controller: _address,
              enabled: !_busy,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: S.address,
                hintText: S.addressHint,
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? S.addressRequired : null,
            ),
            gap,
            TextFormField(
              controller: _note,
              enabled: !_busy,
              minLines: 1,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: S.note,
                hintText: S.noteHint,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            if (_formError != null) ...[
              gap,
              FormErrorBox(message: _formError!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('place-order'),
              onPressed: _busy || lines.isEmpty ? null : _submit,
              icon: _busy
                  ? const Spinner(size: 18, color: Colors.white)
                  : const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(_busy ? S.placingOrder : S.placeOrder),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine {
  const _SummaryLine({
    required this.imageUrl,
    required this.title,
    required this.color,
    required this.size,
    required this.quantity,
    required this.price,
    required this.shop,
  });

  final String imageUrl;
  final String title;
  final String color;
  final String size;
  final int quantity;
  final int price;
  final UserBrief shop;
}

/// "Sargydyňyz kabul edildi!" with one line per created order.
class OrderSuccessView extends StatelessWidget {
  const OrderSuccessView({super.key, required this.orders});

  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: p.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 64,
                      color: p.success,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  S.orderPlacedTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  S.orderPlacedText,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, height: 1.45),
                ),
                const SizedBox(height: 24),
                for (final o in orders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectionCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          UserAvatar(user: o.business, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  S.orderNumber(o.id),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  o.business.displayName,
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatPrice(o.total),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.pushReplacement('/orders'),
                  child: const Text(S.myOrders),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text(S.continueShopping),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
