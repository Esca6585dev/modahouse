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
  ideas('ideas');

  const PinType(this.value);
  final String value;
}

/// Shop fields sent when a business creates or edits a product.
class ProductInput {
  const ProductInput({
    required this.price,
    this.oldPrice = 0,
    this.stock,
    this.deliveryDays,
    this.returnDays,
    this.material = '',
    this.colors = const [],
    this.sizes = const [],
  });

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
    PinType type = PinType.any,
    String? author,
    int page = 1,
    int limit = AppConfig.pageSize,
  }) async => Page.fromJson(
    parseJson(
      await _api.get(
        '/pins',
        query: {
          'q': q?.trim(),
          'category': category,
          'feed': following ? 'following' : null,
          'type': type.value,
          'author': author,
          'page': page,
          'limit': limit,
        },
      ),
    ),
    Pin.fromJson,
  );

  Future<Pin> get(int id) async =>
      Pin.fromJson(parseJson(await _api.get('/pins/$id')));

  /// Creates a pin. One image goes as `image`, several as repeated `images`
  /// (max 8, the first is the cover). [product] makes it a product
  /// (business accounts only).
  Future<Pin> create({
    required List<PickedImage> images,
    required String title,
    required String category,
    String description = '',
    String link = '',
    String tags = '',
    int? boardId,
    ProductInput? product,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData();
    if (images.length == 1) {
      form.files.add(MapEntry('image', images.first.toMultipart()));
    } else {
      for (final img in images) {
        form.files.add(MapEntry('images', img.toMultipart()));
      }
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

  Future<LikeState> like(int id) async =>
      LikeState.fromJson(parseJson(await _api.post('/pins/$id/like')));

  Future<LikeState> unlike(int id) async =>
      LikeState.fromJson(parseJson(await _api.delete('/pins/$id/like')));
}
