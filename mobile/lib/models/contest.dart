import 'json.dart';
import 'pin.dart';

enum ContestStatus {
  upcoming('upcoming'),
  active('active'),
  finished('finished');

  const ContestStatus(this.value);
  final String value;

  static ContestStatus parse(String v) => values.firstWhere(
    (s) => s.value == v,
    orElse: () => ContestStatus.upcoming,
  );
}

/// A post in a contest with its votes and place.
class ContestEntry {
  const ContestEntry({required this.pin, this.votes = 0, this.rank = 0});

  factory ContestEntry.fromJson(Json j) => ContestEntry(
    pin: Pin.fromJson(asJson(j['pin'])),
    votes: asInt(j['votes']),
    rank: asInt(j['rank']),
  );

  final Pin pin;
  final int votes;
  final int rank;
}

/// Ýaryş: users enter one own post, everyone else has one final vote.
class Contest {
  const Contest({
    required this.id,
    required this.title,
    this.description = '',
    this.category = '',
    this.prize = '',
    this.prizeCoins = 0,
    this.startsAt,
    this.endsAt,
    this.status = ContestStatus.upcoming,
    this.entriesCount = 0,
    this.votesCount = 0,
    this.winner,
    this.myVotePinId,
    this.myEntryPinId,
  });

  factory Contest.fromJson(Json j) => Contest(
    id: asInt(j['id']),
    title: asString(j['title']),
    description: asString(j['description']),
    category: asString(j['category']),
    prize: asString(j['prize']),
    prizeCoins: asInt(j['prizeCoins']),
    startsAt: asDate(j['startsAt']),
    endsAt: asDate(j['endsAt']),
    status: ContestStatus.parse(asString(j['status'])),
    entriesCount: asInt(j['entriesCount']),
    votesCount: asInt(j['votesCount']),
    winner: j['winner'] is Map
        ? ContestEntry.fromJson(asJson(j['winner']))
        : null,
    myVotePinId: asIntOrNull(j['myVotePinId']),
    myEntryPinId: asIntOrNull(j['myEntryPinId']),
  );

  final int id;
  final String title;
  final String description;

  /// Category slug; empty = posts of any category.
  final String category;

  /// Prize in words (e.g. "500 TMT sowgat").
  final String prize;

  /// Teňňe given to the winner's author.
  final int prizeCoins;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final ContestStatus status;
  final int entriesCount;
  final int votesCount;

  /// Set once finished (null when nobody entered).
  final ContestEntry? winner;

  /// The post I voted for (votes are final).
  final int? myVotePinId;

  /// My own post in this contest.
  final int? myEntryPinId;

  bool get isActive => status == ContestStatus.active;
  bool get isFinished => status == ContestStatus.finished;
  bool get voted => myVotePinId != null;
  bool get entered => myEntryPinId != null;
}

/// `GET /contests/:id`.
class ContestDetail {
  const ContestDetail({required this.contest, this.entries = const []});

  factory ContestDetail.fromJson(Json j) => ContestDetail(
    contest: Contest.fromJson(asJson(j['contest'])),
    entries: asList(j['entries'], (e) => ContestEntry.fromJson(asJson(e))),
  );

  final Contest contest;
  final List<ContestEntry> entries;
}
