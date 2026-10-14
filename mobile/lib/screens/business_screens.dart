import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/format.dart';
import '../core/labels.dart';
import '../core/snack.dart';
import '../core/theme.dart';
import '../data/business_repository.dart';
import '../data/pins_repository.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../state/paged_controller.dart';
import '../state/pin_updates.dart';
import '../state/providers.dart';
import '../state/shop_state.dart';
import '../widgets/app_image.dart';
import '../widgets/board_form.dart';
import '../widgets/shop_ui.dart';
import '../widgets/states.dart';
import 'orders_screens.dart';

final _phoneRe = RegExp(r'^[0-9+\- ]{8,20}$');

String? validatePhone(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return S.phoneRequired;
  return _phoneRe.hasMatch(s) ? null : S.phoneInvalid;
}

/// `/business/setup`: open a business account, or edit its details.
class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() =>
      _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Me _me = ref.read(authProvider).user!;
  late final Business? _b = _me.business;
  late String? _category = (_b?.category ?? '').isEmpty ? null : _b!.category;
  late final _phone = TextEditingController(text: _b?.phone ?? '');
  late final _city = TextEditingController(text: _b?.city ?? '');
  late final _address = TextEditingController(text: _b?.address ?? '');
  late final _instagram = TextEditingController(text: _b?.instagram ?? '');
  late final _tiktok = TextEditingController(text: _b?.tiktok ?? '');
  late final _telegram = TextEditingController(text: _b?.telegram ?? '');
  late final _whatsapp = TextEditingController(text: _b?.whatsapp ?? '');
  late final _imo = TextEditingController(text: _b?.imo ?? '');
  late final _youtube = TextEditingController(text: _b?.youtube ?? '');
  late final _website = TextEditingController(text: _b?.website ?? '');
  late final _hours = TextEditingController(text: _b?.workingHours ?? '');
  late final _delivery = TextEditingController(
    text: _b == null ? '3' : '${_b.deliveryDays}',
  );
  late final _return = TextEditingController(
    text: _b == null ? '14' : '${_b.returnDays}',
  );
  bool _busy = false;
  String? _error;
  bool _categoryMissing = false;

  bool get _editing => _me.isBusiness;

  @override
  void dispose() {
    for (final c in [
      _phone,
      _city,
      _address,
      _instagram,
      _tiktok,
      _telegram,
      _whatsapp,
      _imo,
      _youtube,
      _website,
      _hours,
      _delivery,
      _return,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final ok = _formKey.currentState!.validate();
    setState(() => _categoryMissing = _category == null);
    if (!ok || _category == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final input = BusinessInput(
      category: _category,
      phone: _phone.text.trim(),
      city: _city.text.trim(),
      address: _address.text.trim(),
      instagram: _instagram.text.trim().replaceFirst('@', ''),
      workingHours: _hours.text.trim(),
      deliveryDays: int.tryParse(_delivery.text.trim()),
      returnDays: int.tryParse(_return.text.trim()),
      tiktok: _tiktok.text.trim().replaceFirst('@', ''),
      telegram: _telegram.text.trim().replaceFirst('@', ''),
      whatsapp: _whatsapp.text.trim(),
      imo: _imo.text.trim(),
      youtube: _youtube.text.trim(),
      website: _website.text.trim(),
    );
    try {
      final repo = ref.read(businessRepositoryProvider);
      final me = _editing ? await repo.update(input) : await repo.open(input);
      ref.read(authProvider.notifier).setUser(me);
      showSnack(_editing ? S.businessUpdated : S.businessOpened);
      if (!mounted) return;
      if (_editing) {
        context.pop();
      } else {
        context.pushReplacement('/business');
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _handleField(TextEditingController c, String label, IconData icon) =>
      TextFormField(
        controller: c,
        enabled: !_busy,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: S.instagramHint,
          prefixText: '@',
          prefixIcon: Icon(icon),
        ),
      );

  static String? _optionalPhone(String? v) =>
      (v ?? '').trim().isEmpty ? null : validatePhone(v);

  static String? _optionalUrl(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final u = Uri.tryParse(s);
    return u != null &&
            (u.scheme == 'http' || u.scheme == 'https') &&
            u.host.isNotEmpty
        ? null
        : S.urlInvalid;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    const gap = SizedBox(height: 16);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? S.editBusiness : S.openBusiness)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppPalette.gutter,
            4,
            AppPalette.gutter,
            32,
          ),
          children: [
            if (!_editing) ...[
              SectionCard(
                color: p.tint,
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      color: AppPalette.accent,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        S.openBusinessText,
                        style: TextStyle(color: p.text, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              S.businessCategory,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: _categoryMissing ? AppPalette.danger : p.text,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.9,
              children: [
                for (final c
                    in ref.watch(businessCategoriesProvider).value ??
                        const <Category>[])
                  _CategoryTile(
                    category: c.slug,
                    label: c.name,
                    selected: c.slug == _category,
                    onTap: _busy
                        ? null
                        : () => setState(() {
                            _category = c.slug;
                            _categoryMissing = false;
                          }),
                  ),
              ],
            ),
            if (_categoryMissing)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  S.categoryChoose,
                  style: TextStyle(color: AppPalette.danger, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phone,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '${S.phone} *',
                hintText: S.phoneHint,
                prefixIcon: Icon(Icons.call_outlined),
              ),
              validator: validatePhone,
            ),
            gap,
            TextFormField(
              controller: _city,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: S.city,
                hintText: S.cityHint,
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
            ),
            gap,
            TextFormField(
              controller: _address,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: S.address,
                hintText: S.addressHint,
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            gap,
            TextFormField(
              controller: _hours,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: S.workingHours,
                hintText: S.workingHoursHint,
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
            ),
            gap,
            const SizedBox(height: 8),
            const Text(
              S.socialLinks,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _handleField(_instagram, S.instagram, Icons.camera_alt_outlined),
            gap,
            _handleField(_tiktok, S.tiktok, Icons.music_note_rounded),
            gap,
            _handleField(_telegram, S.telegram, Icons.send_rounded),
            gap,
            TextFormField(
              controller: _whatsapp,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: S.whatsapp,
                hintText: S.phoneHint,
                prefixIcon: Icon(Icons.chat_rounded),
              ),
              validator: _optionalPhone,
            ),
            gap,
            TextFormField(
              controller: _imo,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: S.imo,
                hintText: S.phoneHint,
                prefixIcon: Icon(Icons.videocam_outlined),
              ),
              validator: _optionalPhone,
            ),
            gap,
            TextFormField(
              controller: _youtube,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: S.youtube,
                hintText: S.websiteHint,
                prefixIcon: Icon(Icons.smart_display_outlined),
              ),
              validator: _optionalUrl,
            ),
            gap,
            TextFormField(
              controller: _website,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: S.website,
                hintText: S.websiteHint,
                prefixIcon: Icon(Icons.language_rounded),
              ),
              validator: _optionalUrl,
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _delivery,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: const InputDecoration(
                      labelText: S.defaultDelivery,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _return,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: const InputDecoration(
                      labelText: S.defaultReturn,
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[gap, FormErrorBox(message: _error!)],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('business-save'),
              onPressed: _busy ? null : _save,
              child: Text(
                _busy ? S.saving : (_editing ? S.save : S.openBusiness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String category;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppPalette.accent.withValues(alpha: 0.08) : p.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppPalette.accent : p.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  businessCategoryIcon(category),
                  size: 20,
                  color: selected ? AppPalette.accent : p.text,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: selected ? AppPalette.accent : p.text,
                    ),
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

/// Settings card: open / edit / close the business account.
class BusinessSettingsCard extends ConsumerStatefulWidget {
  const BusinessSettingsCard({super.key, required this.me});

  final Me me;

  @override
  ConsumerState<BusinessSettingsCard> createState() =>
      _BusinessSettingsCardState();
}

class _BusinessSettingsCardState extends ConsumerState<BusinessSettingsCard> {
  bool _busy = false;

  Future<void> _close() async {
    final ok = await confirmDialog(
      context,
      title: S.switchToPersonal,
      text: S.switchToPersonalText,
      confirm: S.switchToPersonal,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final me = await ref.read(businessRepositoryProvider).close();
      ref.read(authProvider.notifier).setUser(me);
      ref.read(pinUpdatesProvider.notifier).reloadFeeds();
      showSnack(S.switchedToPersonal);
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final me = widget.me;
    final b = me.business;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded, color: AppPalette.accent),
              const SizedBox(width: 8),
              const Text(
                S.settingsBusiness,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (me.isBusiness)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: p.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    businessCategoryLabel(b?.category),
                    style: TextStyle(
                      color: p.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            me.isBusiness ? S.businessActive : S.openBusinessText,
            style: TextStyle(color: p.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (!me.isBusiness)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const Key('open-business'),
                onPressed: () => context.push('/business/setup'),
                icon: const Icon(Icons.storefront_outlined, size: 20),
                label: const Text(S.openBusiness),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => context.push('/business'),
                  icon: const Icon(Icons.insights_rounded, size: 20),
                  label: const Text(S.openDashboard),
                ),
                ElevatedButton(
                  onPressed: () => context.push('/business/setup'),
                  child: const Text(S.edit),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: p.muted),
                  onPressed: _busy ? null : _close,
                  child: Text(_busy ? S.wait : S.switchToPersonal),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

final businessStatsProvider = FutureProvider.family<BusinessStats, StatsPeriod>(
  (ref, period) => ref.watch(businessRepositoryProvider).stats(period),
);

enum _DashTab { orders, products }

/// `/business`: stats, incoming orders and products.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  StatsPeriod _period = StatsPeriod.week;
  _DashTab _tab = _DashTab.orders;
  OrderStatus? _status;
  late PagedController<Order> _orders = _makeOrders();
  late final PagedController<Pin> _products;

  @override
  void initState() {
    super.initState();
    _products = PagedController(
      (page) => ref
          .read(pinsRepositoryProvider)
          .list(
            author: ref.read(authProvider).user?.username,
            type: PinType.products,
            page: page,
          ),
    );
  }

  PagedController<Order> _makeOrders() {
    final status = _status;
    return PagedController(
      (page) => ref
          .read(ordersRepositoryProvider)
          .incoming(status: status, page: page),
    );
  }

  void _setStatus(OrderStatus? s) {
    if (s == _status) return;
    final old = _orders;
    setState(() {
      _status = s;
      _orders = _makeOrders();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    _orders.dispose();
    _products.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(businessStatsProvider(_period));
    await Future.wait([_orders.refresh(), _products.refresh()]);
  }

  void _replaceOrder(Order o) {
    _orders.setItems([for (final x in _orders.items) x.id == o.id ? o : x]);
    ref.invalidate(businessStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ordersVersionProvider, (_, _) => _refresh());
    ref.listen(pinUpdatesProvider.select((u) => u.created), (_, _) {
      _products.refresh();
    });
    final me = ref.watch(authProvider).user;
    final p = AppPalette.of(context);
    if (me == null || !me.isBusiness) {
      return Scaffold(
        appBar: AppBar(title: const Text(S.dashboard)),
        body: EmptyView(
          icon: Icons.storefront_outlined,
          title: S.businessAccount,
          text: S.openBusinessText,
          action: FilledButton(
            onPressed: () => context.push('/business/setup'),
            child: const Text(S.openBusiness),
          ),
        ),
      );
    }
    final stats = ref.watch(businessStatsProvider(_period));

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.dashboard),
        actions: [
          IconButton(
            tooltip: S.editBusiness,
            onPressed: () => context.push('/business/setup'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      floatingActionButton: _tab == _DashTab.products
          ? FloatingActionButton.extended(
              backgroundColor: AppPalette.accent,
              foregroundColor: Colors.white,
              onPressed: () => context.go('/create'),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                S.addProduct,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: RefreshIndicator(
        color: AppPalette.accent,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppPalette.gutter,
                  4,
                  AppPalette.gutter,
                  12,
                ),
                child: Row(
                  children: [
                    StoryAvatar(user: me, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserName(
                            user: me,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            businessCategoryLabel(me.business?.category),
                            style: TextStyle(color: p.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(
                        '/user/${Uri.encodeComponent(me.username)}',
                      ),
                      child: const Text(S.viewProfile),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ChoiceChips<StatsPeriod>(
                values: StatsPeriod.values,
                selected: _period,
                label: periodLabel,
                brand: true,
                onSelected: (v) => setState(() => _period = v),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppPalette.gutter,
                  12,
                  AppPalette.gutter,
                  4,
                ),
                child: stats.when(
                  data: (s) => _StatsGrid(stats: s),
                  loading: () => const Skeleton(height: 250),
                  error: (e, _) => ErrorView(
                    error: e,
                    compact: true,
                    onRetry: () =>
                        ref.invalidate(businessStatsProvider(_period)),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppPalette.gutter,
                  14,
                  AppPalette.gutter,
                  10,
                ),
                child: SegmentedButton<_DashTab>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: p.text,
                    selectedForegroundColor: p.bg,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: _DashTab.orders,
                      icon: Icon(Icons.receipt_long_outlined, size: 18),
                      label: Text(S.incomingOrders),
                    ),
                    ButtonSegment(
                      value: _DashTab.products,
                      icon: Icon(Icons.checkroom_rounded, size: 18),
                      label: Text(S.myProducts),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (v) => setState(() => _tab = v.first),
                ),
              ),
            ),
            if (_tab == _DashTab.orders) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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
                seller: true,
                onChanged: _replaceOrder,
                empty: const EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: S.noIncomingOrders,
                  compact: true,
                ),
              ),
            ] else
              _ProductsList(controller: _products),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final BusinessStats stats;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget tile(
      IconData icon,
      String label,
      String value, {
      Color? color,
      bool highlight = false,
    }) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? AppPalette.accent : p.card,
        borderRadius: BorderRadius.circular(20),
        border: highlight ? null : Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: highlight ? Colors.white : (color ?? p.muted),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlight ? Colors.white70 : p.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: highlight ? Colors.white : p.text,
              ),
            ),
          ),
        ],
      ),
    );
    final s = stats;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.9,
      children: [
        tile(
          Icons.payments_outlined,
          S.statRevenue,
          formatPrice(s.revenue),
          highlight: true,
        ),
        tile(
          Icons.shopping_bag_outlined,
          S.statOrders,
          statCount(s.orders),
          color: AppPalette.accent,
        ),
        tile(Icons.visibility_outlined, S.statViews, statCount(s.views)),
        tile(Icons.favorite_border_rounded, S.statLikes, statCount(s.likes)),
        tile(
          Icons.pending_actions_rounded,
          S.statPending,
          statCount(s.pendingOrders),
          color: const Color(0xFFE37400),
        ),
        tile(
          Icons.star_rounded,
          S.statRating,
          s.reviewsCount > 0
              ? '${formatRating(s.rating)} (${s.reviewsCount})'
              : '–',
          color: AppPalette.gold,
        ),
        tile(
          Icons.checkroom_rounded,
          S.statProducts,
          statCount(s.productsCount),
        ),
        tile(
          Icons.people_outline_rounded,
          S.statFollowers,
          statCount(s.followersCount),
        ),
      ],
    );
  }
}

class _ProductsList extends ConsumerWidget {
  const _ProductsList({required this.controller});

  final PagedController<Pin> controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates = ref.watch(pinUpdatesProvider);
    final p = AppPalette.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items
            .where((x) => !updates.isGone(x.id))
            .map(updates.resolve)
            .toList();
        if (!controller.loaded) {
          return const SliverToBoxAdapter(child: LoadingView());
        }
        if (controller.error != null && items.isEmpty) {
          return SliverToBoxAdapter(
            child: ErrorView(
              error: controller.error!,
              onRetry: controller.refresh,
            ),
          );
        }
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: EmptyView(
              icon: Icons.checkroom_rounded,
              title: S.noProductsTitle,
              text: S.noProductsText,
              compact: true,
              action: FilledButton(
                onPressed: () => context.go('/create'),
                child: const Text(S.addProduct),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppPalette.gutter),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i >= items.length - 3 &&
                  controller.hasMore &&
                  !controller.loading) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => controller.loadMore(),
                );
              }
              final pin = items[i];
              final product = pin.product;
              final stock = product?.stock;
              return Material(
                color: p.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: p.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push('/pin/${pin.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 64,
                            height: 80,
                            child: AppImage(
                              pin.imageUrl,
                              placeholder: parseHexColor(pin.color, p.surface),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pin.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              if (product != null)
                                PriceText(
                                  price: product.price,
                                  oldPrice: product.oldPrice,
                                  size: 14,
                                ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 10,
                                children: [
                                  _mini(
                                    context,
                                    Icons.inventory_2_outlined,
                                    stock == null
                                        ? S.available
                                        : (stock > 0 ? '$stock' : S.outOfStock),
                                    color: stock == 0
                                        ? AppPalette.danger
                                        : null,
                                  ),
                                  _mini(
                                    context,
                                    Icons.visibility_outlined,
                                    compactCount(pin.viewsCount),
                                  ),
                                  _mini(
                                    context,
                                    Icons.favorite_border_rounded,
                                    compactCount(pin.likesCount),
                                  ),
                                  _mini(
                                    context,
                                    Icons.shopping_bag_outlined,
                                    compactCount(pin.ordersCount),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: S.edit,
                          onPressed: () async {
                            final updated = await context.push<Pin>(
                              '/pin/${pin.id}/edit',
                            );
                            if (updated != null) {
                              ref
                                  .read(pinUpdatesProvider.notifier)
                                  .updated(updated);
                            }
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _mini(
    BuildContext context,
    IconData icon,
    String text, {
    Color? color,
  }) {
    final p = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? p.muted),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color ?? p.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
