import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:modahouse/core/format.dart';
import 'package:modahouse/core/labels.dart';
import 'package:modahouse/data/business_repository.dart';
import 'package:modahouse/data/pins_repository.dart';
import 'package:modahouse/l10n/strings.dart';
import 'package:modahouse/models/models.dart';

const _shop = {
  'id': 9,
  'username': 'gyzyl.guyze',
  'name': 'Gyzyl Güýze',
  'avatarUrl': '/uploads/seed/avatar-9.svg',
  'isBusiness': true,
  'verified': true,
};

const _product = {
  'price': 450,
  'oldPrice': 520,
  'colors': [
    {'name': 'Gyzyl', 'hex': '#C62828'},
    {'name': 'Gara', 'hex': '#212121'},
  ],
  'sizes': ['42', '44', '46'],
  'stock': 12,
  'deliveryDays': 12,
  'returnDays': 14,
  'material': 'Atlas',
  'badge': 'sale',
};

const _productPin = {
  'id': 31,
  'title': 'Zarif köýnek',
  'category': 'koynekler',
  'imageUrl': '/uploads/seed/p31-1.svg',
  'width': 600,
  'height': 800,
  'color': '#8E1B3A',
  'author': _shop,
  'images': [
    {
      'url': '/uploads/seed/p31-1.svg',
      'width': 600,
      'height': 800,
      'color': '#8E1B3A',
    },
    {
      'url': '/uploads/seed/p31-2.svg',
      'width': 600,
      'height': 600,
      'color': '#222222',
    },
  ],
  'product': _product,
  'viewsCount': 1240,
  'ordersCount': 18,
  'rating': 4.6,
  'reviewsCount': 7,
  'likesCount': 3,
  'savedBoardIds': [],
};

void main() {
  group('UserBrief / Profile v2', () {
    test('business flags and story ring', () {
      final p = Profile.fromJson({
        ..._shop,
        'bio': 'Toý köýnekleri',
        'followersCount': 120,
        'hasStory': true,
        'storySeen': false,
        'business': {
          'category': 'dress',
          'phone': '+993 61 234567',
          'address': 'Bitarap Türkmenistan şaýoly 12',
          'city': 'Aşgabat',
          'instagram': 'gyzyl.guyze',
          'workingHours': '09:00 - 19:00',
          'deliveryDays': 3,
          'returnDays': 14,
          'rating': 4.75,
          'reviewsCount': 12,
          'ordersCount': 40,
          'productsCount': 9,
        },
      });
      expect(p.isBusiness, isTrue);
      expect(p.verified, isTrue);
      expect(p.hasStory, isTrue);
      expect(p.storySeen, isFalse);
      final b = p.business!;
      expect(b.category, BusinessCategory.dress);
      expect(b.phone, '+993 61 234567');
      expect(b.city, 'Aşgabat');
      expect(b.workingHours, '09:00 - 19:00');
      expect(b.rating, 4.75);
      expect(b.productsCount, 9);
      expect(businessCategoryLabel(b.category), S.catDress);
      expect(p.copyWith(storySeen: true).storySeen, isTrue);
      expect(p.copyWith(storySeen: true).business, same(b));
    });

    test('personal accounts have no business', () {
      final me = Me.fromJson({
        'id': 2,
        'username': 'ic.bezeg',
        'name': 'Içki bezeg',
        'business': null,
        'email': 'a@b.tm',
      });
      expect(me.isBusiness, isFalse);
      expect(me.verified, isFalse);
      expect(me.business, isNull);
      expect(me.email, 'a@b.tm');
    });

    test('unknown business category is null', () {
      expect(BusinessCategory.tryParse('x'), isNull);
      expect(
        BusinessCategory.tryParse('accessories'),
        BusinessCategory.accessories,
      );
    });
  });

  group('Product pin', () {
    test('fromJson reads images, product and counters', () {
      final pin = Pin.fromJson(_productPin);
      expect(pin.isProduct, isTrue);
      expect(pin.images, hasLength(2));
      expect(pin.gallery.last.url, '/uploads/seed/p31-2.svg');
      expect(pin.images.last.aspectRatio, 1);
      expect(pin.viewsCount, 1240);
      expect(pin.ordersCount, 18);
      expect(pin.rating, 4.6);
      expect(pin.reviewsCount, 7);
      expect(pin.author.isBusiness, isTrue);
      final p = pin.product!;
      expect(p.price, 450);
      expect(p.oldPrice, 520);
      expect(p.hasDiscount, isTrue);
      expect(p.discountPercent, 13);
      expect(p.colors.first, const ColorOption(name: 'Gyzyl', hex: '#C62828'));
      expect(p.sizes, ['42', '44', '46']);
      expect(p.stock, 12);
      expect(p.inStock, isTrue);
      expect(p.hasOptions, isTrue);
      expect(p.material, 'Atlas');
      expect(p.badge, ProductBadge.sale);
      expect(badgeLabel(p.badge), S.badgeSale);
    });

    test('stock null = untracked, 0 = sold out; no discount', () {
      final untracked = Product.fromJson({
        ...{'price': 100},
        'stock': null,
      });
      expect(untracked.stock, isNull);
      expect(untracked.inStock, isTrue);
      expect(untracked.hasDiscount, isFalse);
      expect(untracked.badge, ProductBadge.none);
      final sold = Product.fromJson({'price': 100, 'stock': 0, 'badge': 'hit'});
      expect(sold.inStock, isFalse);
      expect(sold.badge, ProductBadge.hit);
      expect(ProductBadge.parse('new'), ProductBadge.isNew);
    });

    test('idea pins: no product, gallery falls back to the cover', () {
      final pin = Pin.fromJson({
        'id': 1,
        'title': 'Ideýa',
        'imageUrl': '/uploads/a.svg',
        'width': 300,
        'height': 400,
        'author': {'id': 1, 'username': 'a', 'name': 'A'},
        'product': null,
      });
      expect(pin.isProduct, isFalse);
      expect(pin.gallery.single.url, '/uploads/a.svg');
      expect(pin.copyWith(viewsCount: 5).viewsCount, 5);
    });

    test('ProductInput: multipart fields and JSON body', () {
      const input = ProductInput(
        price: 450,
        oldPrice: 520,
        deliveryDays: 3,
        material: 'Atlas',
        colors: [ColorOption(name: 'Gyzyl', hex: '#C62828')],
        sizes: ['42', '44'],
      );
      final form = input.toFormFields();
      expect(form['price'], '450');
      expect(form['stock'], '');
      expect(form['sizes'], '42,44');
      expect(jsonDecode(form['colors']!), [
        {'name': 'Gyzyl', 'hex': '#C62828'},
      ]);
      expect(form.containsKey('returnDays'), isFalse);
      final json = input.toJson();
      expect(json.containsKey('stock'), isTrue);
      expect(json['stock'], isNull);
      expect(json['sizes'], ['42', '44']);
    });
  });

  group('Shops and Top 10', () {
    test('BusinessCard and TopEntry', () {
      final e = TopEntry.fromJson({
        'rank': 1,
        'score': 96,
        'views': 12450,
        'likes': 3280,
        'orders': 620,
        'moreCount': 5,
        'business': {
          ..._shop,
          'category': 'tailor',
          'city': 'Mary',
          'rating': 4.8,
          'reviewsCount': 128,
          'followersCount': 900,
          'productsCount': 9,
          'hasStory': true,
          'covers': ['/a.svg', '/b.svg', '/c.svg', '/d.svg'],
        },
      });
      expect(e.rank, 1);
      expect(e.score, 96);
      expect(e.views, 12450);
      expect(e.moreCount, 5);
      expect(e.business.category, BusinessCategory.tailor);
      expect(e.business.covers, hasLength(4));
      expect(e.business.hasStory, isTrue);
      expect(e.business.verified, isTrue);
      expect(S.score(e.score), '96/100');
    });

    test('BusinessStats', () {
      final s = BusinessStats.fromJson({
        'views': 10,
        'likes': 4,
        'orders': 2,
        'revenue': 900,
        'pendingOrders': 1,
        'rating': 4,
        'reviewsCount': 3,
        'productsCount': 5,
        'followersCount': 7,
      });
      expect(s.revenue, 900);
      expect(s.rating, 4.0);
      expect(s.pendingOrders, 1);
    });

    test('BusinessInput only sends given fields', () {
      const input = BusinessInput(
        category: BusinessCategory.boutique,
        phone: '+993 65 000000',
      );
      expect(input.toJson(), {
        'category': 'boutique',
        'phone': '+993 65 000000',
      });
    });
  });

  group('Reviews', () {
    test('ReviewsPage keeps the summary fields', () {
      final r = ReviewsPage.fromJson({
        'items': [
          {
            'id': 1,
            'rating': 5,
            'text': 'Örän gowy',
            'author': {'id': 3, 'username': 'gezelenc', 'name': 'Gezelenç'},
            'canDelete': true,
            'createdAt': '2026-10-05T02:37:30Z',
          },
        ],
        'page': 1,
        'limit': 10,
        'hasMore': false,
        'rating': 4.5,
        'reviewsCount': 2,
        'canReview': true,
      });
      expect(r.items.single.rating, 5);
      expect(r.items.single.canDelete, isTrue);
      expect(r.rating, 4.5);
      expect(r.reviewsCount, 2);
      expect(r.canReview, isTrue);
      expect(r.hasMore, isFalse);
    });
  });

  group('Cart', () {
    Map<String, Object?> line(int id, Map<String, Object?> author, int total) =>
        {
          'id': id,
          'quantity': 2,
          'color': 'Gyzyl',
          'size': '44',
          'lineTotal': total,
          'available': id != 3,
          'pin': {
            'id': 30 + id,
            'title': 'Köýnek $id',
            'imageUrl': '/x.svg',
            'color': '#eee',
            'price': total ~/ 2,
            'oldPrice': 0,
            'stock': null,
            'author': author,
          },
        };

    test('fromJson and grouping by shop', () {
      const other = {'id': 10, 'username': 'ak.gelin', 'name': 'Ak Gelin'};
      final cart = Cart.fromJson({
        'items': [
          line(1, _shop, 900),
          line(2, other, 400),
          line(3, _shop, 300),
        ],
        'total': 1300,
        'count': 6,
      });
      expect(cart.count, 6);
      expect(cart.total, 1300);
      expect(cart.items.first.pin.stock, isNull);
      expect(cart.items.first.color, 'Gyzyl');
      final groups = cart.byShop;
      expect(groups, hasLength(2));
      expect(groups.first.shop.username, 'gyzyl.guyze');
      expect(groups.first.items, hasLength(2));
      // Unavailable lines do not count in the subtotal.
      expect(groups.first.subtotal, 900);
    });
  });

  group('Orders', () {
    final json = {
      'id': 5,
      'status': 'shipped',
      'total': 900,
      'buyer': {'id': 2, 'username': 'ic.bezeg', 'name': 'Aýna'},
      'business': _shop,
      'fullName': 'Aýna Annaýewa',
      'phone': '+993 61 234567',
      'address': 'Aşgabat',
      'note': '',
      'items': [
        {
          'pinId': 31,
          'title': 'Zarif köýnek',
          'imageUrl': '/x.svg',
          'price': 450,
          'color': 'Gyzyl',
          'size': '44',
          'quantity': 2,
        },
        {
          'pinId': null,
          'title': 'Pozulan',
          'imageUrl': '',
          'price': 0,
          'color': '',
          'size': '',
          'quantity': 1,
        },
      ],
      'canCancel': false,
      'nextStatuses': ['delivered'],
      'createdAt': '2026-10-05T10:00:00Z',
      'updatedAt': '2026-10-06T10:00:00Z',
    };

    test('fromJson', () {
      final o = Order.fromJson(json);
      expect(o.status, OrderStatus.shipped);
      expect(o.status.step, 2);
      expect(o.business.isBusiness, isTrue);
      expect(o.items.first.lineTotal, 900);
      expect(o.items.last.pinId, isNull);
      expect(o.itemsCount, 3);
      expect(o.nextStatuses, [OrderStatus.delivered]);
      expect(orderStatusLabel(o.status), S.statusShipped);
      expect(orderActionLabel(OrderStatus.confirmed), S.actionConfirm);
    });

    test('status parsing', () {
      expect(OrderStatus.parse('new'), OrderStatus.isNew);
      expect(OrderStatus.parse('cancelled').step, -1);
      expect(OrderStatus.parse('?'), OrderStatus.unknown);
    });

    test('BuyNow body', () {
      expect(const BuyNow(pinId: 3, size: '44', quantity: 2).toJson(), {
        'pinId': 3,
        'size': '44',
        'quantity': 2,
      });
    });
  });

  group('Stories', () {
    test('StoryGroup and markSeen', () {
      final g = StoryGroup.fromJson({
        'user': _shop,
        'allSeen': false,
        'stories': [
          {
            'id': 1,
            'imageUrl': '/s1.svg',
            'width': 720,
            'height': 1280,
            'color': '#111',
            'caption': 'Täze kolleksiýa',
            'pinId': 31,
            'seen': true,
            'viewsCount': 0,
            'createdAt': '2026-10-11T10:00:00Z',
            'expiresAt': '2026-10-12T10:00:00Z',
          },
          {'id': 2, 'imageUrl': '/s2.svg', 'pinId': null, 'seen': false},
        ],
      });
      expect(g.user.verified, isTrue);
      expect(g.stories.first.pinId, 31);
      expect(g.stories.first.caption, 'Täze kolleksiýa');
      expect(g.stories.last.pinId, isNull);
      expect(g.firstUnseen, 1);
      final seen = g.markSeen(2);
      expect(seen.allSeen, isTrue);
      expect(seen.firstUnseen, 0);
    });
  });

  group('Notifications v2', () {
    test('order and order_status carry the order', () {
      final n = Notification.fromJson({
        'id': 1,
        'type': 'order_status',
        'read': false,
        'actor': _shop,
        'order': {'id': 5, 'status': 'confirmed', 'total': 900},
      });
      expect(n.type, NotificationType.orderStatus);
      expect(n.order?.id, 5);
      expect(n.order?.status, OrderStatus.confirmed);
      expect(notificationTypeFrom('order'), NotificationType.order);
      expect(notificationTypeFrom('review'), NotificationType.review);
    });
  });

  group('format', () {
    test('prices and grouped numbers', () {
      expect(formatPrice(450), '450 TMT');
      expect(formatPrice(1250), '1 250 TMT');
      expect(groupDigits(12450), '12 450');
      expect(groupDigits(1234567), '1 234 567');
      expect(statCount(250000), compactCount(250000));
      expect(formatRating(4.66), '4,7');
      expect(formatDateTime(DateTime(2026, 10, 5, 9, 3)), '05.10.2026 09:03');
    });
  });
}
