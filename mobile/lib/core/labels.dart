import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/models.dart';

/// Turkmen name of a business category slug.
String businessCategoryLabel(String? slug, [List<Category>? categories]) {
  if (slug == null || slug.isEmpty) return '';
  for (final c in categories ?? const <Category>[]) {
    if (c.slug == slug) return c.name;
  }
  return businessCategoryNames[slug] ?? slug;
}

IconData businessCategoryIcon(String? slug) {
  switch (slug) {
    case 'dress':
      return Icons.checkroom_rounded;
    case 'tailor':
    case 'kurte':
      return Icons.content_cut_rounded;
    case 'embroidery':
      return Icons.gesture_rounded;
    case 'fata':
      return Icons.auto_awesome_outlined;
    case 'hair':
    case 'makeup':
    case 'lashes':
    case 'nails':
      return Icons.face_retouching_natural_outlined;
    case 'atelier':
      return Icons.design_services_outlined;
    case 'bridal':
      return Icons.favorite_border_rounded;
    case 'rental':
      return Icons.event_available_rounded;
    case 'boutique':
      return Icons.storefront_rounded;
    case 'designer':
      return Icons.brush_outlined;
    case 'jewelry':
      return Icons.diamond_outlined;
    case 'beauty':
      return Icons.face_retouching_natural_outlined;
    case 'accessories':
      return Icons.shopping_bag_outlined;
    default:
      return Icons.store_mall_directory_outlined;
  }
}

String orderStatusLabel(OrderStatus s) {
  switch (s) {
    case OrderStatus.isNew:
      return S.statusNew;
    case OrderStatus.confirmed:
      return S.statusConfirmed;
    case OrderStatus.shipped:
      return S.statusShipped;
    case OrderStatus.delivered:
      return S.statusDelivered;
    case OrderStatus.cancelled:
      return S.statusCancelled;
    case OrderStatus.unknown:
      return '';
  }
}

/// Button label for a business moving an order to [s].
String orderActionLabel(OrderStatus s) {
  switch (s) {
    case OrderStatus.confirmed:
      return S.actionConfirm;
    case OrderStatus.shipped:
      return S.actionShip;
    case OrderStatus.delivered:
      return S.actionDeliver;
    case OrderStatus.cancelled:
      return S.actionCancel;
    case OrderStatus.isNew:
    case OrderStatus.unknown:
      return orderStatusLabel(s);
  }
}

IconData orderStatusIcon(OrderStatus s) {
  switch (s) {
    case OrderStatus.isNew:
      return Icons.receipt_long_rounded;
    case OrderStatus.confirmed:
      return Icons.task_alt_rounded;
    case OrderStatus.shipped:
      return Icons.local_shipping_rounded;
    case OrderStatus.delivered:
      return Icons.inventory_2_rounded;
    case OrderStatus.cancelled:
      return Icons.cancel_rounded;
    case OrderStatus.unknown:
      return Icons.help_outline_rounded;
  }
}

String badgeLabel(ProductBadge b) {
  switch (b) {
    case ProductBadge.isNew:
      return S.badgeNew;
    case ProductBadge.hit:
      return S.badgeHit;
    case ProductBadge.sale:
      return S.badgeSale;
    case ProductBadge.none:
      return '';
  }
}

String periodLabel(StatsPeriod p) {
  switch (p) {
    case StatsPeriod.week:
      return S.periodWeek;
    case StatsPeriod.month:
      return S.periodMonth;
    case StatsPeriod.all:
      return S.periodAll;
  }
}
