import 'dart:convert';

import 'package:dio/dio.dart';

import '../config.dart';
import '../core/api_client.dart';
import '../models/models.dart';
import 'common.dart';

/// `type` filter of `GET /pins`.
enum PinType {
  any(''),
  products('products'),
  ideas('ideas'),
  videos('videos');

  const PinType(this.value);
  final String value;
}

/// Shop fields sent when a business creates or edits a product.
class ProductInput {
  const ProductInput({
    this.listingType = ListingType.sale,
    this.deposit = 0,
    this.minDays = 0,
    this.readyDays = 0,
    required this.price,
    this.oldPrice = 0,
    this.stock,
    this.deliveryDays,
    this.returnDays,
    this.material = '',
    this.colors = const [],
    this.sizes = const [],
  });

  final ListingType listingType;

  /// Rent only.
  final int deposit;
  final int minDays;

  /// Custom only.
  final int readyDays;
  final int price;
  final int oldPrice;

  /// null = not tracked.
  final int? stock;
  final int? deliveryDays;
  final int? returnDays;
  final String material;
  final List<ColorOption> colors;
  final List<String> sizes;

  /// Multipart fields for `POST /pins`.
  Map<String, String> toFormFields() => {
    'listingType': listingType.value,
    'deposit': '$deposit',
    'minDays': '$minDays',
    'readyDays': '$readyDays',
    'price': '$price',
    'oldPrice': '$oldPrice',
    'stock': stock == null ? '' : '$stock',
    if (deliveryDays != null) 'deliveryDays': '$deliveryDays',
    if (returnDays != null) 'returnDays': '$returnDays',
    'material': material,
    'colors': jsonEncode([for (final c in colors) c.toJson()]),
    'sizes': sizes.join(','),
  };

  /// JSON body fields for `PUT /pins/:id` (`stock: null` = untracked).
  Json toJson() => {
    'listingType': listingType.value,
    'deposit': deposit,
    'minDays': minDays,
    'readyDays': readyDays,
    'price': price,
    'oldPrice': oldPrice,
    'stock': stock,
    'deliveryDays': ?deliveryDays,
    'returnDays': ?returnDays,
    'material': material,
    'colors': [for (final c in colors) c.toJson()],
    'sizes': sizes,
  };
}

class PinsRepository {
  PinsRepository(this._api);
  final ApiClient _api;

  Future<List<Category>> categories() async =>
      parseList(await _api.get('/categories'), Category.fromJson);

  Future<Page<Pin>> list({
    String? q,
    String? category,
    bool following = false,
    bool forYou = false,
    PinType type = PinType.any,
    String? author,
    String? tag,
    bool withComments = false,
    int page = 1,
    int limit = AppConfig.pageSize,
  }) async => Page.fromJson(
    parseJson(
      await _api.get(
        '/pins',
        query: {
          'q': q?.trim(),
          'category': category,
          'feed': following
              ? 'following'
              : forYou
              ? 'foryou'
              : null,
          'type': type.value,
          'author': author,
          'tag': tag?.replaceFirst('#', ''),
          'withComments': withComments ? 1 : null,
          'page': page,
          'limit': limit,
        },
      ),
    ),
    Pin.fromJson,
  );

  Future<Pin> get(int id) async =>
      Pin.fromJson(parseJson(await _api.get('/pins/$id')));

  /// Creates a post. Media go as repeated `images` (photos and videos, the
  /// first is the cover); the k-th video's poster and length go as the k-th
  /// `posters` / `durations`. [product] sets the listing type and its fields
  /// (sale/rent/custom need a business account); [listingType] `post`
  /// explicitly marks a plain post.
  Future<Pin> create({
    required List<PickedImage> images,
    required String title,
    required String category,
    String description = '',
    String link = '',
    String tags = '',
    int? boardId,
    ProductInput? product,
    ListingType? listingType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData();
    for (final img in images) {
      form.files.add(MapEntry('images', img.toMultipart()));
    }
    for (final v in images.where((m) => m.isVideo)) {
      if (v.poster != null) {
        form.files.add(MapEntry('posters', v.poster!.toMultipart()));
      }
    }
    final videos = images.where((m) => m.isVideo).toList();
    final withDurations = videos.every((v) => v.duration != null);
    if (videos.isNotEmpty && withDurations) {
      for (final v in videos) {
        form.fields.add(MapEntry('durations', v.duration!.toStringAsFixed(2)));
      }
    }
    if (product == null && listingType != null) {
      form.fields.add(MapEntry('listingType', listingType.value));
    }
    form.fields.addAll(
      {
        'title': title,
        'category': category,
        'description': description,
        'link': link,
        'tags': tags,
        if (boardId != null) 'boardId': '$boardId',
        ...?product?.toFormFields(),
      }.entries,
    );
    return Pin.fromJson(
      parseJson(
        await _api.post('/pins', data: form, onSendProgress: onProgress),
      ),
    );
  }

  Future<Pin> update(
    int id, {
    String? title,
    String? description,
    String? link,
    String? category,
    String? tags,
    ProductInput? product,
  }) async => Pin.fromJson(
    parseJson(
      await _api.put(
        '/pins/$id',
        data: {
          'title': ?title,
          'description': ?description,
          'link': ?link,
          'category': ?category,
          'tags': ?tags,
          ...?product?.toJson(),
        },
      ),
    ),
  );

  /// "Gyzyklanmaýaryn": hide from my feeds.
  Future<void> hide(int id) => _api.post('/pins/$id/hide');

  Future<void> unhide(int id) => _api.delete('/pins/$id/hide');

  /// reason: spam, inappropriate, copyright, fake, other.
  Future<void> report(int id, String reason, {String note = ''}) =>
      _api.post('/pins/$id/report', data: {'reason': reason, 'note': note});

  /// "Meňzeşini tap" for an existing post.
  Future<VisualResult> visual(
    int id, {
    bool productsOnly = false,
    int limit = 30,
  }) async => VisualResult.fromJson(
    parseJson(
      await _api.get(
        '/pins/$id/visual',
        query: {'type': productsOnly ? 'products' : null, 'limit': limit},
      ),
    ),
  );

  /// Search by photo. [crop] = (x, y, w, h) fractions of the image.
  Future<VisualResult> searchImage(
    PickedImage image, {
    (double, double, double, double)? crop,
    bool productsOnly = false,
    int limit = 30,
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({
      'image': image.toMultipart(),
      if (crop != null) ...{
        'x': crop.$1.toStringAsFixed(4),
        'y': crop.$2.toStringAsFixed(4),
        'w': crop.$3.toStringAsFixed(4),
        'h': crop.$4.toStringAsFixed(4),
      },
      if (productsOnly) 'type': 'products',
      'limit': '$limit',
    });
    return VisualResult.fromJson(
      parseJson(
        await _api.post('/search/image', data: form, cancelToken: cancelToken),
      ),
    );
  }

  /// `GET /search?q=`: people and hashtags.
  Future<SearchResult> search(String q) async => SearchResult.fromJson(
    parseJson(await _api.get('/search', query: {'q': q.trim()})),
  );

  /// Posts I liked, newest like first.
  Future<Page<Pin>> likes(int page, {int limit = AppConfig.pageSize}) async =>
      Page.fromJson(
        parseJson(
          await _api.get('/me/likes', query: {'page': page, 'limit': limit}),
        ),
        Pin.fromJson,
      );

  /// Counts a view (once per viewer per day). Returns the new count.
  Future<int> view(int id) async =>
      asInt(parseJson(await _api.post('/pins/$id/view'))['viewsCount']);

  Future<void> delete(int id) => _api.delete('/pins/$id');

  Future<Page<Pin>> similar(
    int id,
    int page, {
    int limit = AppConfig.pageSize,
  }) async => Page.fromJson(
    parseJson(
      await _api.get(
        '/pins/$id/similar',
        query: {'page': page, 'limit': limit},
      ),
    ),
    Pin.fromJson,
  );

  /// "Öňe çykar": spends teňňe to boost my post for [days] (402 when the
  /// balance is short; a running boost is extended).
  Future<BoostResult> boost(int id, int days) async => BoostResult.fromJson(
    parseJson(await _api.post('/pins/$id/boost', data: {'days': days})),
  );

  /// `GET /pins/promoted`: every post boosted right now.
  Future<List<Pin>> promoted() async => parseList(
    await _api.get('/pins/promoted'),
    (j) => Pin.fromJson({...j, 'promoted': true}),
  );

  Future<LikeState> like(int id) async =>
      LikeState.fromJson(parseJson(await _api.post('/pins/$id/like')));

  Future<LikeState> unlike(int id) async =>
      LikeState.fromJson(parseJson(await _api.delete('/pins/$id/like')));
}
