import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:modahouse/data/business_repository.dart';
import 'package:modahouse/data/common.dart';
import 'package:modahouse/data/pins_repository.dart';
import 'package:modahouse/l10n/strings.dart';
import 'package:modahouse/models/models.dart';
import 'package:modahouse/widgets/caption.dart';
import 'package:modahouse/widgets/contact_sheet.dart';
import 'package:modahouse/widgets/crop_box.dart';

const _author = {
  'id': 13,
  'username': 'aysoltan.style',
  'name': 'Aýsoltan',
  'avatarUrl': '/uploads/seed/creator-00.svg',
  'isBusiness': false,
  'verified': false,
};

void main() {
  group('Listing types', () {
    test('parse and product fields per type', () {
      expect(ListingType.parse('rent'), ListingType.rent);
      expect(ListingType.parse('x'), ListingType.sale);
      expect(
        ListingType.parse(null, fallback: ListingType.post),
        ListingType.post,
      );
      final rent = Product.fromJson({
        'listingType': 'rent',
        'price': 250,
        'deposit': 500,
        'minDays': 2,
        'readyDays': 0,
      });
      expect(rent.type, ListingType.rent);
      expect(rent.isSale, isFalse);
      expect(rent.deposit, 500);
      expect(rent.minDays, 2);
      final custom = Product.fromJson({
        'listingType': 'custom',
        'price': 700,
        'readyDays': 10,
      });
      expect(custom.type, ListingType.custom);
      expect(custom.readyDays, 10);
      // Pre-v3 products without a type are sales.
      expect(Product.fromJson({'price': 1}).isSale, isTrue);
    });

    test('ProductInput sends the type fields', () {
      const rent = ProductInput(
        listingType: ListingType.rent,
        price: 250,
        deposit: 500,
        minDays: 2,
      );
      final form = rent.toFormFields();
      expect(form['listingType'], 'rent');
      expect(form['deposit'], '500');
      expect(form['minDays'], '2');
      expect(rent.toJson()['readyDays'], 0);
      const custom = ProductInput(
        listingType: ListingType.custom,
        price: 700,
        readyDays: 10,
      );
      expect(custom.toJson()['listingType'], 'custom');
      expect(custom.toJson()['readyDays'], 10);
    });
  });

  group('Media items', () {
    test('video pin with poster, duration and latest comments', () {
      final pin = Pin.fromJson({
        'id': 209,
        'title': 'Toý köýnegi hereketde',
        'imageUrl': '/uploads/seed/reel-1.jpg',
        'width': 360,
        'height': 640,
        'author': _author,
        'mediaType': 'video',
        'commentsCount': 3,
        'images': [
          {
            'type': 'video',
            'url': '/uploads/seed/reel-1.webm',
            'posterUrl': '/uploads/seed/reel-1.jpg',
            'duration': 6.07,
            'width': 360,
            'height': 640,
            'color': '#2B2328',
          },
          {'type': 'image', 'url': '/a.jpg', 'width': 600, 'height': 800},
        ],
        'latestComments': [
          {
            'id': 1,
            'text': 'Örän owadan!',
            'author': _author,
            'canDelete': false,
          },
        ],
      });
      expect(pin.isVideo, isTrue);
      final v = pin.gallery.first;
      expect(v.isVideo, isTrue);
      expect(v.posterUrl, '/uploads/seed/reel-1.jpg');
      expect(v.stillUrl, '/uploads/seed/reel-1.jpg');
      expect(v.duration, closeTo(6.07, 1e-9));
      expect(pin.gallery.last.isVideo, isFalse);
      expect(pin.gallery.last.stillUrl, '/a.jpg');
      expect(pin.latestComments.single.text, 'Örän owadan!');
      // copyWith keeps the v3 fields.
      final liked = pin.copyWith(liked: true, likesCount: 1);
      expect(liked.isVideo, isTrue);
      expect(liked.latestComments, hasLength(1));
    });

    test('images default to type image', () {
      final img = PinImage.fromJson({'url': '/x.jpg'});
      expect(img.type, 'image');
      expect(img.isVideo, isFalse);
      expect(Pin.fromJson({'id': 1, 'title': 'x'}).mediaType, 'image');
    });

    test('video story', () {
      final s = Story.fromJson({
        'id': 4,
        'imageUrl': '/poster.jpg',
        'mediaType': 'video',
        'videoUrl': '/s.webm',
      });
      expect(s.isVideo, isTrue);
      expect(s.copyWith(seen: true).videoUrl, '/s.webm');
      expect(Story.fromJson({'id': 1, 'imageUrl': '/a'}).isVideo, isFalse);
    });

    test('picked media type detection', () {
      expect(mediaTypeFor('clip.webm'), 'video/webm');
      expect(mediaTypeFor('a.MOV'), 'video/quicktime');
      expect(mediaTypeFor('x.png'), 'image/png');
      expect(mediaTypeFor('blob', 'video/mp4'), 'video/mp4');
      final v = PickedImage(
        bytes: utf8.encode('x'),
        name: 'c.webm',
      ).copyWith(duration: 2.5);
      expect(v.isVideo, isTrue);
      expect(v.duration, 2.5);
    });
  });

  group('Search, visual results and AI', () {
    test('SearchResult', () {
      final r = SearchResult.fromJson({
        'users': [_author],
        'tags': [
          {'tag': 'toýköýnek', 'count': 12},
        ],
      });
      expect(r.users.single.username, 'aysoltan.style');
      expect(r.tags.single.count, 12);
      expect(r.isEmpty, isFalse);
      expect(SearchResult.fromJson({}).isEmpty, isTrue);
    });

    test('VisualResult', () {
      final v = VisualResult.fromJson({
        'items': [
          {'id': 5, 'title': 'A', 'author': _author},
          {'id': 6, 'title': 'B', 'author': _author},
        ],
        'scores': [0.93, 0.71],
        'category': 'toy',
        'source': 'ai+local',
      });
      expect(v.items.first.id, 5);
      expect(v.scoreAt(0), 0.93);
      expect(v.scoreAt(5), 0);
      expect(v.category, 'toy');
      expect(v.source, 'ai+local');
    });

    test('Suggestion and the inserted caption', () {
      final s = Suggestion.fromJson({
        'title': 'Gelin köýnegi kärendä',
        'description': 'Toýuňyz üçin owadan lybas.',
        'hashtags': ['#gelinköýnek', 'kärende', ''],
        'category': 'gelin',
        'priceLine': 'Günlük kärende: 250 TMT · Girew: 500 TMT',
        'details': ['Ölçegler: 42-48'],
        'source': 'template',
      });
      expect(s.hashtags, ['gelinköýnek', 'kärende']);
      expect(s.isTemplate, isTrue);
      expect(
        s.fullDescription,
        'Toýuňyz üçin owadan lybas.\n\n• Ölçegler: 42-48\n\n'
        'Günlük kärende: 250 TMT · Girew: 500 TMT\n\n'
        '#gelinköýnek #kärende',
      );
      expect(Suggestion.fromJson({'source': 'ai'}).isTemplate, isFalse);
    });
  });

  group('Business v3', () {
    test('social links and blocked profiles', () {
      final p = Profile.fromJson({
        'id': 33,
        'username': 'altyn.gelin',
        'name': 'Altyn Gelin Salony',
        'isBusiness': true,
        'isBlocked': true,
        'business': {
          'category': 'rental',
          'phone': '+993 65 778800',
          'instagram': 'altyn.gelin',
          'tiktok': 'altyn',
          'telegram': 'altyn.gelin',
          'whatsapp': '+993 65 778800',
          'imo': '+993 65 778800',
          'youtube': '',
          'website': 'https://altyn.tm',
        },
      });
      expect(p.isBlocked, isTrue);
      expect(p.copyWith(isBlocked: false).isBlocked, isFalse);
      final b = p.business!;
      expect(b.category, 'rental');
      expect(b.tiktok, 'altyn');
      expect(b.website, 'https://altyn.tm');

      final links = contactLinks(b, message: S.contactMessage('Gelin köýnegi'));
      expect(links.map((l) => l.kind).toList(), [
        'phone',
        'whatsapp',
        'telegram',
        'imo',
        'instagram',
        'tiktok',
        'website',
      ]);
      expect(links[0].uri.toString(), 'tel:+99365778800');
      final wa = links[1].uri!;
      expect(wa.host, 'wa.me');
      expect(wa.path, '/99365778800');
      expect(wa.queryParameters['text'], contains('«Gelin köýnegi»'));
      expect(links[2].uri.toString(), 'https://t.me/altyn.gelin');
      expect(links[3].uri, isNull);
      expect(links[3].copyText, '+993 65 778800');
      expect(links[5].uri.toString(), 'https://www.tiktok.com/@altyn');
    });

    test('BusinessInput sends social links', () {
      const input = BusinessInput(telegram: 'shop', website: 'https://a.tm');
      expect(input.toJson(), {'telegram': 'shop', 'website': 'https://a.tm'});
    });

    test('BusinessCard isFollowing', () {
      final c = BusinessCard.fromJson({
        'id': 1,
        'username': 'a',
        'name': 'A',
        'isFollowing': true,
      });
      expect(c.isFollowing, isTrue);
    });

    test('order notification step, current status and role', () {
      final n = Notification.fromJson({
        'id': 1,
        'type': 'order_status',
        'read': false,
        'actor': _author,
        'order': {
          'id': 5,
          'status': 'confirmed',
          'currentStatus': 'delivered',
          'total': 900,
          'role': 'buyer',
        },
      });
      expect(n.order!.status, OrderStatus.confirmed);
      expect(n.order!.currentStatus, OrderStatus.delivered);
      expect(n.order!.forSeller, isFalse);
    });
  });

  group('Captions', () {
    test('hashtags and mentions', () {
      final t = tokenizeCaption('Täze #toýköýnek we @aysoltan.style bilen.');
      expect(t.map((x) => x.text).toList(), [
        'Täze ',
        '#toýköýnek',
        ' we ',
        '@aysoltan.style',
        ' bilen.',
      ]);
      expect(t[1].tag, 'toýköýnek');
      expect(t[3].mention, 'aysoltan.style');
      // Not a hashtag in the middle of a word.
      expect(tokenizeCaption('abc#def').single.tag, isNull);
    });
  });

  group('Crop frame', () {
    test('move, resize and clamp', () {
      const f = CropFrame.centered();
      expect(f.x, closeTo(0.15, 1e-9));
      expect(f.w, closeTo(0.7, 1e-9));
      final moved = f.moved(0.5, 0);
      expect(moved.x + moved.w, closeTo(1, 1e-9));
      final small = f.resized(2, -1, -1);
      expect(small.w, closeTo(CropFrame.minSize, 1e-9));
      expect(small.h, closeTo(CropFrame.minSize, 1e-9));
      final big = f.resized(0, -1, -1);
      expect(big.x, 0);
      expect(big.y, 0);
      expect(big.record.$3, closeTo(0.85, 1e-9));
    });
  });
}
