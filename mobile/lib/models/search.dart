import 'json.dart';
import 'pin.dart';
import 'user.dart';

/// `{tag, count}` from `GET /search`.
class TagCount {
  const TagCount({required this.tag, this.count = 0});

  factory TagCount.fromJson(Json j) =>
      TagCount(tag: asString(j['tag']), count: asInt(j['count']));

  final String tag;
  final int count;
}

/// `GET /search?q=`: people and hashtags.
class SearchResult {
  const SearchResult({this.users = const [], this.tags = const []});

  factory SearchResult.fromJson(Json j) => SearchResult(
    users: asList(j['users'], (e) => UserBrief.fromJson(asJson(e))),
    tags: asList(j['tags'], (e) => TagCount.fromJson(asJson(e))),
  );

  final List<UserBrief> users;
  final List<TagCount> tags;

  bool get isEmpty => users.isEmpty && tags.isEmpty;
}

/// `POST /search/image` and `GET /pins/:id/visual`.
class VisualResult {
  const VisualResult({
    this.items = const [],
    this.scores = const [],
    this.category = '',
    this.source = 'local',
  });

  factory VisualResult.fromJson(Json j) => VisualResult(
    items: asList(j['items'], (e) => Pin.fromJson(asJson(e))),
    scores: asList(j['scores'], asDouble),
    category: asString(j['category']),
    source: asString(j['source']),
  );

  /// Most similar first.
  final List<Pin> items;

  /// 0..1, same order as [items].
  final List<double> scores;

  /// Category detected by AI ("" without AI).
  final String category;
  final String source;

  double scoreAt(int i) => i < scores.length ? scores[i] : 0;
}

/// `POST /ai/suggest`.
class Suggestion {
  const Suggestion({
    this.title = '',
    this.description = '',
    this.hashtags = const [],
    this.category = '',
    this.priceLine = '',
    this.details = const [],
    this.source = 'template',
  });

  factory Suggestion.fromJson(Json j) => Suggestion(
    title: asString(j['title']),
    description: asString(j['description']),
    hashtags: asList(
      j['hashtags'],
      (e) => asString(e).replaceFirst('#', ''),
    ).where((t) => t.isNotEmpty).toList(),
    category: asString(j['category']),
    priceLine: asString(j['priceLine']),
    details: asList(j['details'], asString),
    source: asString(j['source']),
  );

  final String title;
  final String description;

  /// Without "#".
  final List<String> hashtags;
  final String category;
  final String priceLine;
  final List<String> details;

  /// `ai` or `template`.
  final String source;

  bool get isTemplate => source != 'ai';

  /// Description + details + price line + hashtags, ready for the caption.
  String get fullDescription {
    final parts = <String>[
      if (description.isNotEmpty) description,
      if (details.isNotEmpty) details.map((d) => '• $d').join('\n'),
      if (priceLine.isNotEmpty) priceLine,
      if (hashtags.isNotEmpty) hashtags.map((t) => '#$t').join(' '),
    ];
    return parts.join('\n\n');
  }
}
