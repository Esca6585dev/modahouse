import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/models.dart';

String businessCategoryLabel(BusinessCategory? c) {
  switch (c) {
    case BusinessCategory.dress:
      return S.catDress;
    case BusinessCategory.tailor:
      return S.catTailor;
    case BusinessCategory.boutique:
      return S.catBoutique;
    case BusinessCategory.designer:
      return S.catDesigner;
    case BusinessCategory.accessories:
      return S.catAccessories;
    case null:
      return '';
  }
}

IconData businessCategoryIcon(BusinessCategory? c) {
  switch (c) {
    case BusinessCategory.dress:
      return Icons.checkroom_rounded;
    case BusinessCategory.tailor:
      return Icons.content_cut_rounded;
    case BusinessCategory.boutique:
      return Icons.storefront_rounded;
    case BusinessCategory.designer:
      return Icons.design_services_rounded;
    case BusinessCategory.accessories:
      return Icons.diamond_outlined;
    case null:
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
