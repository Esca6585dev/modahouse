import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/format.dart';
import '../core/labels.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/paged_controller.dart';
import '../state/providers.dart';
import '../state/shop_state.dart';
import '../widgets/app_image.dart';
import '../widgets/avatar.dart';
import '../widgets/shop_ui.dart';
import '../widgets/states.dart';
import 'profile_screen.dart' show launchExternal, telUri;

/// Business: move an order to [next] (asks first when cancelling).
Future<Order?> changeOrderStatus(
  BuildContext context,
  WidgetRef ref,
  Order order,
  OrderStatus next,
) async {
  if (next == OrderStatus.cancelled) {
    final ok = await confirmDialog(
      context,
      title: S.cancelOrder,
      text: S.cancelOrderText,
      confirm: S.actionCancel,
    );
    if (!ok) return null;
  }
  try {
    final o = await ref
        .read(ordersRepositoryProvider)
        .setStatus(order.id, next);
    showSnack(S.statusUpdated);
    ref.read(ordersVersionProvider.notifier).bump();
    return o;
  } catch (e) {
    showError(e);
    return null;
  }
}

/// Buyer: cancel a "new" order.
Future<Order?> cancelOrder(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final ok = await confirmDialog(
    context,
    title: S.cancelOrder,
    text: S.cancelOrderText,
    confirm: S.actionCancel,
  );
  if (!ok) return null;
  try {
    final o = await ref.read(ordersRepositoryProvider).cancel(order.id);
    showSnack(S.orderCancelled);
    ref.read(ordersVersionProvider.notifier).bump();
    return o;
  } catch (e) {
    showError(e);
    return null;
  }
}

/// Täze → Tassyklandy → Ýolda → Gowşuryldy.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.status, this.compact = false});

  final OrderStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (status == OrderStatus.cancelled) {
      return Row(
        children: [
          Icon(Icons.cancel_rounded, color: p.muted, size: 18),
          const SizedBox(width: 6),
          Text(
            S.statusCancelled,
            style: TextStyle(color: p.muted, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }
    final step = status.step;
    final done = p.success;
    const flow = OrderStatus.flow;
    final dot = compact ? 18.0 : 30.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < flow.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox.shrink()
                          : Container(
                              height: 3,
                              color: i <= step ? done : p.surface2,
                            ),
                    ),
                    Container(
                      width: dot,
                      height: dot,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= step ? done : p.surface,
                        border: i == step + 1
                            ? Border.all(color: p.surface2, width: 2)
                            : null,
                      ),
                      child: Icon(
                        i <= step
                            ? Icons.check_rounded
                            : orderStatusIcon(flow[i]),
                        size: dot * 0.58,
                        color: i <= step ? Colors.white : p.muted,
                      ),
                    ),
                    Expanded(
                      child: i == flow.length - 1
                          ? const SizedBox.shrink()
                          : Container(
                              height: 3,
                              color: i < step ? done : p.surface2,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  orderStatusLabel(flow[i]),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12.5,
                    fontWeight: i == step ? FontWeight.w800 : FontWeight.w600,
                    color: i <= step ? p.text : p.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact order summary for "Sargytlarym" and the dashboard.
class OrderCard extends ConsumerStatefulWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.seller,
    this.onChanged,
  });

  final Order order;

  /// Shown to the shop (buyer details + status actions).
  final bool seller;
  final ValueChanged<Order>? onChanged;

  @override
  ConsumerState<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<OrderCard> {
  bool _busy = false;

  Future<void> _run(Future<Order?> Function() action) async {
    setState(() => _busy = true);
    final o = await action();
    if (mounted) setState(() => _busy = false);
    if (o != null) widget.onChanged?.call(o);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final o = widget.order;
    final party = widget.seller ? o.buyer : o.business;
    final items = o.items;
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppPalette.cardRadius),
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/orders/${o.id}', extra: o),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  UserAvatar(user: party, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserName(
                          user: party,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${S.orderNumber(o.id)} · ${formatDateTime(o.createdAt)}',
                          style: TextStyle(color: p.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  OrderStatusPill(status: o.status),
                ],
              ),
              const SizedBox(height: 12),
              if (items.length == 1)
                _ItemRow(item: items.first)
              else
                SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      for (final it in items.take(4))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 52,
                              child: AppImage(it.imageUrl),
                            ),
                          ),
                        ),
                      if (items.length > 4)
                        Text(
                          '+${items.length - 4}',
                          style: TextStyle(
                            color: p.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              OrderTimeline(status: o.status, compact: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    S.itemsCount(o.itemsCount),
                    style: TextStyle(color: p.muted, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '${S.total}: ',
                    style: TextStyle(color: p.muted, fontSize: 13),
                  ),
                  Text(
                    formatPrice(o.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              if (widget.seller && o.nextStatuses.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SellerActions(
                  order: o,
                  busy: _busy,
                  onAction: (s) =>
                      _run(() => changeOrderStatus(context, ref, o, s)),
                ),
              ],
              if (!widget.seller && o.canCancel) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: p.muted),
                    onPressed: _busy
                        ? null
                        : () => _run(() => cancelOrder(context, ref, o)),
                    child: const Text(S.cancelOrder),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerActions extends StatelessWidget {
  const _SellerActions({
    required this.order,
    required this.busy,
    required this.onAction,
  });

  final Order order;
  final bool busy;
  final ValueChanged<OrderStatus> onAction;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final main = order.nextStatuses
        .where((s) => s != OrderStatus.cancelled)
        .toList();
    final canCancel = order.nextStatuses.contains(OrderStatus.cancelled);
    return Row(
      children: [
        if (canCancel)
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                foregroundColor: p.muted,
                side: BorderSide(color: p.border, width: 1.5),
              ),
              onPressed: busy ? null : () => onAction(OrderStatus.cancelled),
              child: const Text(S.actionCancel),
            ),
          ),
        for (final s in main) ...[
          if (canCancel || s != main.first) const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: busy ? null : () => onAction(s),
              icon: busy
                  ? const Spinner(size: 16, color: Colors.white)
                  : Icon(orderStatusIcon(s), size: 18),
              label: Text(orderActionLabel(s)),
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, this.trailing});

  final OrderItem item;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final options = [
      if (item.color.isNotEmpty) '${S.color}: ${item.color}',
      if (item.size.isNotEmpty) '${S.size}: ${item.size}',
    ].join(' · ');
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            height: 70,
            child: AppImage(item.imageUrl),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (options.isNotEmpty)
                Text(options, style: TextStyle(color: p.muted, fontSize: 12.5)),
              const SizedBox(height: 2),
              Text(
                '${item.quantity} × ${formatPrice(item.price)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Paged list of [OrderCard]s.
class OrderListSliver extends StatelessWidget {
  const OrderListSliver({
    super.key,
    required this.controller,
    required this.seller,
    required this.empty,
    this.onChanged,
  });

  final PagedController<Order> controller;
  final bool seller;
  final Widget empty;
  final ValueChanged<Order>? onChanged;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final items = controller.items;
      if (!controller.loaded && controller.error == null) {
        return SliverList.separated(
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppPalette.gutter),
            child: Skeleton(height: 200, radius: AppPalette.cardRadius),
          ),
        );
      }
      if (controller.error != null && items.isEmpty) {
        return SliverToBoxAdapter(
          child: ErrorView(
            error: controller.error!,
            onRetry: controller.refresh,
          ),
        );
      }
      if (items.isEmpty) return SliverToBoxAdapter(child: empty);
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppPalette.gutter),
        sliver: SliverList.separated(
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == items.length) {
              if (controller.hasMore && !controller.loading) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => controller.loadMore(),
                );
              }
              return controller.loading
                  ? const Center(child: Spinner())
                  : const SizedBox.shrink();
            }
            return OrderCard(
              key: ValueKey('order-${items[i].id}'),
              order: items[i],
              seller: seller,
              onChanged: (o) {
                controller.setItems([
                  for (final x in controller.items) x.id == o.id ? o : x,
                ]);
                onChanged?.call(o);
              },
            );
          },
        ),
      );
    },
  );
}

/// `/orders`: my purchases with a status filter.
class MyOrdersScreen extends ConsumerStatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  ConsumerState<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends ConsumerState<MyOrdersScreen> {
  OrderStatus? _status;
  late PagedController<Order> _orders = _make();

  PagedController<Order> _make() {
    final s = _status;
    return PagedController(
      (page) => ref.read(ordersRepositoryProvider).mine(status: s, page: page),
    );
  }

  void _setStatus(OrderStatus? s) {
    if (s == _status) return;
    final old = _orders;
    setState(() {
      _status = s;
      _orders = _make();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    _orders.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ordersVersionProvider, (_, _) => _orders.refresh());
    return Scaffold(
      appBar: AppBar(title: const Text(S.myOrders)),
      body: RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: () => _orders.refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: ChoiceChips<OrderStatus?>(
                  values: const [
                    null,
                    OrderStatus.isNew,
                    OrderStatus.confirmed,
                    OrderStatus.shipped,
                    OrderStatus.delivered,
                    OrderStatus.cancelled,
                  ],
                  selected: _status,
                  label: (s) => s == null ? S.all : orderStatusLabel(s),
                  onSelected: _setStatus,
                ),
              ),
            ),
            OrderListSliver(
              controller: _orders,
              seller: false,
              empty: EmptyView(
                icon: Icons.receipt_long_outlined,
                title: S.ordersEmptyTitle,
                text: S.ordersEmptyText,
                action: FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text(S.goShopping),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

/// `/orders/:id`: full order (buyer or seller view).
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.id, this.initial});

  final int id;
  final Order? initial;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late Order? _order = widget.initial;
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
      final o = await ref.read(ordersRepositoryProvider).get(widget.id);
      if (mounted) setState(() => _order = o);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(Future<Order?> Function() action) async {
    setState(() => _busy = true);
    final o = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (o != null) _order = o;
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final me = ref.watch(authProvider).user;
    final p = AppPalette.of(context);

    Widget body;
    if (o == null) {
      body = _error == null
          ? const LoadingView()
          : (_error is ApiException && (_error as ApiException).isNotFound)
          ? const EmptyView(
              icon: Icons.receipt_long_outlined,
              title: S.orderNotFound,
            )
          : ErrorView(error: _error!, onRetry: _load);
    } else {
      final seller = me != null && me.id == o.business.id;
      final party = seller ? o.buyer : o.business;
      Widget label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          t,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      );
      Widget line(IconData icon, String text, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: p.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    height: 1.35,
                    color: onTap != null ? AppPalette.accent : p.text,
                    fontWeight: onTap != null
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.orderNumber(o.id),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              formatDateTime(o.createdAt),
                              style: TextStyle(color: p.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      OrderStatusPill(status: o.status),
                    ],
                  ),
                  const SizedBox(height: 18),
                  OrderTimeline(status: o.status),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label(seller ? S.buyer : S.seller),
                  Row(
                    children: [
                      UserAvatar(
                        user: party,
                        size: 40,
                        onTap: () => context.push(
                          '/user/${Uri.encodeComponent(party.username)}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UserName(
                              user: party,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '@${party.username}',
                              style: TextStyle(color: p.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label(S.products),
                  for (final it in o.items) ...[
                    InkWell(
                      onTap: it.pinId == null
                          ? null
                          : () => context.push('/pin/${it.pinId}'),
                      child: _ItemRow(
                        item: it,
                        trailing: Text(
                          formatPrice(it.lineTotal),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    if (!seller &&
                        o.status == OrderStatus.delivered &&
                        it.pinId != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => context.push('/pin/${it.pinId}'),
                          icon: const Icon(
                            Icons.rate_review_outlined,
                            size: 18,
                          ),
                          label: const Text(S.writeReview),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                  Divider(color: p.border),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        S.total,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        formatPrice(o.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppPalette.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    S.payOnDelivery,
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label(S.deliveryInfo),
                  line(Icons.person_outline_rounded, o.fullName),
                  line(
                    Icons.call_outlined,
                    o.phone,
                    onTap: seller
                        ? () => launchExternal(
                            telUri(o.phone),
                            error: S.cannotCall,
                          )
                        : null,
                  ),
                  line(Icons.location_on_outlined, o.address),
                  if (o.note.isNotEmpty) line(Icons.notes_rounded, o.note),
                ],
              ),
            ),
            if (seller && o.nextStatuses.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SellerActions(
                order: o,
                busy: _busy,
                onAction: (s) =>
                    _run(() => changeOrderStatus(context, ref, o, s)),
              ),
            ],
            if (!seller && o.canCancel) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.danger,
                  side: const BorderSide(color: AppPalette.danger, width: 1.5),
                ),
                onPressed: _busy
                    ? null
                    : () => _run(() => cancelOrder(context, ref, o)),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text(S.cancelOrder),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text(S.orderDetails)),
      body: body,
    );
  }
}
