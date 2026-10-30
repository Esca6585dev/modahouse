import 'json.dart';

/// One thing the server learned the user likes (`GET /me/interests`).
class Interest {
  const Interest({
    required this.kind,
    required this.key,
    required this.name,
    this.score = 0,
  });

  factory Interest.fromJson(Json j) => Interest(
    kind: asString(j['kind']),
    key: asString(j['key']),
    name: asString(j['name']),
    score: asDouble(j['score']),
  );

  /// `category` or `tag`.
  final String kind;

  /// Category slug or tag text.
  final String key;

  /// Category name, or the tag itself.
  final String name;
  final double score;

  bool get isTag => kind == 'tag';
}

/// `GET /me/interests`: [picked] false means the "what do you like?" screen
/// has not been answered yet (and nothing was learned).
class Interests {
  const Interests({this.items = const [], this.picked = false});

  factory Interests.fromJson(Json j) => Interests(
    items: asList(j['items'], (e) => Interest.fromJson(asJson(e))),
    picked: asBool(j['picked']),
  );

  final List<Interest> items;
  final bool picked;
}
