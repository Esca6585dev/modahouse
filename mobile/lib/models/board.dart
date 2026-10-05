import 'json.dart';
import 'user.dart';

class Board {
  const Board({
    required this.id,
    required this.name,
    this.description = '',
    this.isPrivate = false,
    this.pinsCount = 0,
    this.covers = const [],
    required this.owner,
    this.createdAt,
  });

  factory Board.fromJson(Json j) => Board(
        id: asInt(j['id']),
        name: asString(j['name']),
        description: asString(j['description']),
        isPrivate: asBool(j['isPrivate']),
        pinsCount: asInt(j['pinsCount']),
        covers: asList(j['covers'], asString),
        owner: UserBrief.fromJson(asJson(j['owner'])),
        createdAt: asDate(j['createdAt']),
      );

  final int id;
  final String name;
  final String description;
  final bool isPrivate;
  final int pinsCount;

  /// Up to 3 latest pin image URLs (relative).
  final List<String> covers;
  final UserBrief owner;
  final DateTime? createdAt;

  Board copyWith({int? pinsCount, List<String>? covers}) => Board(
        id: id,
        name: name,
        description: description,
        isPrivate: isPrivate,
        pinsCount: pinsCount ?? this.pinsCount,
        covers: covers ?? this.covers,
        owner: owner,
        createdAt: createdAt,
      );
}
