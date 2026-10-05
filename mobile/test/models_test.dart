import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modahouse/config.dart';
import 'package:modahouse/core/format.dart';
import 'package:modahouse/models/models.dart';

const _author = {
  'id': 1,
  'username': 'aylar.studio',
  'name': 'Aýlar Studio',
  'avatarUrl': '',
};

const _pinJson = {
  'id': 7,
  'title': 'Güýz üçin gatlakly geýim',
  'description': 'Salkyn günler üçin',
  'link': 'https://example.com',
  'category': 'moda',
  'tags': ['güýz', 'geýim'],
  'imageUrl': '/uploads/seed/pin-01.svg',
  'width': 600,
  'height': 840,
  'color': '#f2d0b6',
  'author': _author,
  'likesCount': 2,
  'commentsCount': 3,
  'liked': true,
  'savedBoardIds': [4, 9],
  'createdAt': '2026-10-05T02:37:30.106405673Z',
};

void main() {
  group('UserBrief / Profile / Me', () {
    test('UserBrief.fromJson', () {
      final u = UserBrief.fromJson(_author);
      expect(u.id, 1);
      expect(u.username, 'aylar.studio');
      expect(u.name, 'Aýlar Studio');
      expect(u.avatarUrl, '');
      expect(u.displayName, 'Aýlar Studio');
    });

    test('Me.fromJson keeps profile fields and email', () {
      final me = Me.fromJson({
        ..._author,
        'bio': 'Moda',
        'followersCount': 5,
        'followingCount': 2,
        'pinsCount': 7,
        'isFollowing': false,
        'isMe': true,
        'createdAt': '2026-10-05T02:37:30Z',
        'email': 'aylar@modahouse.tm',
      });
      expect(me.email, 'aylar@modahouse.tm');
      expect(me.followersCount, 5);
      expect(me.followingCount, 2);
      expect(me.pinsCount, 7);
      expect(me.isMe, isTrue);
      expect(me.bio, 'Moda');
      expect(me.createdAt, DateTime.utc(2026, 10, 5, 2, 37, 30));
    });

    test('AuthResponse.fromJson', () {
      final r = AuthResponse.fromJson({
        'token': 'jwt',
        'user': {..._author, 'email': 'a@b.tm'},
      });
      expect(r.token, 'jwt');
      expect(r.user.email, 'a@b.tm');
    });

    test('missing fields fall back to safe defaults', () {
      final p = Profile.fromJson({'id': '3'});
      expect(p.id, 3);
      expect(p.username, '');
      expect(p.followersCount, 0);
      expect(p.isFollowing, isFalse);
      expect(p.createdAt, isNull);
    });
  });

  group('Pin', () {
    test('fromJson reads every field', () {
      final p = Pin.fromJson(_pinJson);
      expect(p.id, 7);
      expect(p.title, 'Güýz üçin gatlakly geýim');
      expect(p.category, 'moda');
      expect(p.tags, ['güýz', 'geýim']);
      expect(p.imageUrl, '/uploads/seed/pin-01.svg');
      expect(p.width, 600);
      expect(p.height, 840);
      expect(p.color, '#f2d0b6');
      expect(p.author.username, 'aylar.studio');
      expect(p.likesCount, 2);
      expect(p.commentsCount, 3);
      expect(p.liked, isTrue);
      expect(p.savedBoardIds, [4, 9]);
      expect(p.isSaved, isTrue);
      // Nanosecond timestamps from Go are accepted.
      expect(p.createdAt?.year, 2026);
      expect(p.aspectRatio, closeTo(600 / 840, 1e-9));
    });

    test('aspect ratio is guarded', () {
      final noSize = Pin.fromJson({..._pinJson, 'width': 0, 'height': 0});
      expect(noSize.aspectRatio, 0.75);
      final veryTall = Pin.fromJson({
        ..._pinJson,
        'width': 100,
        'height': 1000,
      });
      expect(veryTall.aspectRatio, 0.45);
    });

    test('copyWith updates like and save state only', () {
      final p = Pin.fromJson(_pinJson)
          .copyWith(liked: false, likesCount: 1, savedBoardIds: []);
      expect(p.liked, isFalse);
      expect(p.likesCount, 1);
      expect(p.isSaved, isFalse);
      expect(p.title, 'Güýz üçin gatlakly geýim');
    });

    test('LikeState.fromJson', () {
      final l = LikeState.fromJson({'liked': true, 'likesCount': 12});
      expect(l.liked, isTrue);
      expect(l.likesCount, 12);
    });
  });

  test('Board.fromJson', () {
    final b = Board.fromJson({
      'id': 4,
      'name': 'Güýz geýimleri',
      'description': 'Ideýalar',
      'isPrivate': true,
      'pinsCount': 5,
      'covers': ['/uploads/a.svg', '/uploads/b.svg'],
      'owner': _author,
      'createdAt': '2026-10-05T02:37:30Z',
    });
    expect(b.id, 4);
    expect(b.name, 'Güýz geýimleri');
    expect(b.isPrivate, isTrue);
    expect(b.pinsCount, 5);
    expect(b.covers, hasLength(2));
    expect(b.owner.username, 'aylar.studio');
  });

  test('Comment.fromJson', () {
    final c = Comment.fromJson({
      'id': 1,
      'text': 'Örän owadan!',
      'author': _author,
      'canDelete': true,
      'createdAt': '2026-10-05T02:37:30Z',
    });
    expect(c.text, 'Örän owadan!');
    expect(c.canDelete, isTrue);
    expect(c.author.name, 'Aýlar Studio');
  });

  group('Notification', () {
    test('with pin', () {
      final n = Notification.fromJson({
        'id': 3,
        'type': 'comment',
        'read': false,
        'actor': _author,
        'pin': {'id': 7, 'title': 'Güýz', 'imageUrl': '/uploads/x.svg'},
        'createdAt': '2026-10-05T02:37:30Z',
      });
      expect(n.type, NotificationType.comment);
      expect(n.read, isFalse);
      expect(n.pin?.id, 7);
      expect(n.pin?.imageUrl, '/uploads/x.svg');
    });

    test('follow without pin and unknown types', () {
      final n = Notification.fromJson({
        'id': 4,
        'type': 'follow',
        'read': true,
        'actor': _author,
      });
      expect(n.type, NotificationType.follow);
      expect(n.pin, isNull);
      expect(notificationTypeFrom('like'), NotificationType.like);
      expect(notificationTypeFrom('save'), NotificationType.save);
      expect(notificationTypeFrom('other'), NotificationType.unknown);
    });
  });

  test('Category.fromJson and categoryName', () {
    final cats = [
      Category.fromJson({'slug': 'moda', 'name': 'Moda'}),
      Category.fromJson({'slug': 'ic-bezeg', 'name': 'Içki bezeg'}),
    ];
    expect(categoryName('ic-bezeg', cats), 'Içki bezeg');
    expect(categoryName('nameless', cats), 'nameless');
  });

  test('Page<T>.fromJson', () {
    final page = Page.fromJson({
      'items': [
        _pinJson,
        {..._pinJson, 'id': 8},
      ],
      'page': 2,
      'limit': 24,
      'hasMore': true,
    }, Pin.fromJson);
    expect(page.items.map((p) => p.id), [7, 8]);
    expect(page.page, 2);
    expect(page.limit, 24);
    expect(page.hasMore, isTrue);

    final empty = Page.fromJson({'items': null}, Pin.fromJson);
    expect(empty.items, isEmpty);
    expect(empty.hasMore, isFalse);
  });

  group('helpers', () {
    test('resolveImageUrl prefixes relative paths', () {
      expect(
        resolveImageUrl('/uploads/a.svg', origin: 'http://10.0.2.2:8080'),
        'http://10.0.2.2:8080/uploads/a.svg',
      );
      expect(
        resolveImageUrl('uploads/a.svg', origin: 'http://h'),
        'http://h/uploads/a.svg',
      );
      expect(
        resolveImageUrl('https://cdn/x.png', origin: 'http://h'),
        'https://cdn/x.png',
      );
      expect(resolveImageUrl(''), '');
    });

    test('isSvgUrl', () {
      expect(isSvgUrl('http://h/uploads/seed/pin-01.svg'), isTrue);
      expect(isSvgUrl('http://h/uploads/x.SVG?v=1'), isTrue);
      expect(isSvgUrl('http://h/uploads/x.jpg'), isFalse);
    });

    test('timeAgo in Turkmen', () {
      final now = DateTime(2026, 10, 5, 12);
      expect(
        timeAgo(now.subtract(const Duration(seconds: 10)), now: now),
        'şu wagt',
      );
      expect(
        timeAgo(now.subtract(const Duration(minutes: 3)), now: now),
        '3 minut öň',
      );
      expect(
        timeAgo(now.subtract(const Duration(hours: 2)), now: now),
        '2 sagat öň',
      );
      expect(timeAgo(now.subtract(const Duration(hours: 30)), now: now), 'dün');
      expect(
        timeAgo(now.subtract(const Duration(days: 4)), now: now),
        '4 gün öň',
      );
      expect(timeAgo(null), '');
    });

    test('compactCount', () {
      expect(compactCount(950), '950');
      expect(compactCount(1200), '1,2 müň');
      expect(compactCount(1000), '1 müň');
      expect(compactCount(12400), '12 müň');
      expect(compactCount(1400000), '1,4 mln');
    });

    test('parseHexColor and splitTags', () {
      expect(
        parseHexColor('#f2d0b6', const Color(0x00000000)).toARGB32(),
        0xFFF2D0B6,
      );
      expect(
        parseHexColor('#abc', const Color(0x00000000)).toARGB32(),
        0xFFAABBCC,
      );
      expect(
        parseHexColor('nope', const Color(0x11223344)).toARGB32(),
        0x11223344,
      );
      expect(splitTags(' güýz, palto ,, klassyk '), [
        'güýz',
        'palto',
        'klassyk',
      ]);
    });
  });
}
