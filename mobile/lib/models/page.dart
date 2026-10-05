import 'json.dart';

/// `{"items": [...], "page": 1, "limit": 24, "hasMore": true}`.
///
/// Flutter's navigator also has a `Page` class; files that use both import
/// material with `hide Page`.
class Page<T> {
  const Page({
    required this.items,
    this.page = 1,
    this.limit = 24,
    this.hasMore = false,
  });

  factory Page.fromJson(Json j, T Function(Json item) fromJson) => Page(
    items: asList(j['items'], (e) => fromJson(asJson(e))),
    page: asInt(j['page']),
    limit: asInt(j['limit']),
    hasMore: asBool(j['hasMore']),
  );

  final List<T> items;
  final int page;
  final int limit;
  final bool hasMore;
}
