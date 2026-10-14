import 'business.dart';
import 'json.dart';

class UserBrief {
  const UserBrief({
    required this.id,
    required this.username,
    required this.name,
    this.avatarUrl = '',
    this.isBusiness = false,
    this.verified = false,
  });

  factory UserBrief.fromJson(Json j) => UserBrief(
    id: asInt(j['id']),
    username: asString(j['username']),
    name: asString(j['name']),
    avatarUrl: asString(j['avatarUrl']),
    isBusiness: asBool(j['isBusiness']),
    verified: asBool(j['verified']),
  );

  final int id;
  final String username;
  final String name;

  /// Relative path, empty when the user has no avatar.
  final String avatarUrl;

  /// Instagram-style professional (shop) account.
  final bool isBusiness;

  /// Blue check next to the name.
  final bool verified;

  String get displayName => name.isNotEmpty ? name : username;

  @override
  bool operator ==(Object other) =>
      other is UserBrief && other.id == id && other.username == username;

  @override
  int get hashCode => Object.hash(id, username);
}

class Profile extends UserBrief {
  const Profile({
    required super.id,
    required super.username,
    required super.name,
    super.avatarUrl,
    super.isBusiness,
    super.verified,
    this.bio = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.pinsCount = 0,
    this.isFollowing = false,
    this.isMe = false,
    this.createdAt,
    this.hasStory = false,
    this.storySeen = false,
    this.business,
    this.isBlocked = false,
  });

  factory Profile.fromJson(Json j) => Profile(
    id: asInt(j['id']),
    username: asString(j['username']),
    name: asString(j['name']),
    avatarUrl: asString(j['avatarUrl']),
    isBusiness: asBool(j['isBusiness']),
    verified: asBool(j['verified']),
    bio: asString(j['bio']),
    followersCount: asInt(j['followersCount']),
    followingCount: asInt(j['followingCount']),
    pinsCount: asInt(j['pinsCount']),
    isFollowing: asBool(j['isFollowing']),
    isMe: asBool(j['isMe']),
    createdAt: asDate(j['createdAt']),
    hasStory: asBool(j['hasStory']),
    storySeen: asBool(j['storySeen']),
    business: j['business'] is Map
        ? Business.fromJson(asJson(j['business']))
        : null,
    isBlocked: asBool(j['isBlocked']),
  );

  final String bio;
  final int followersCount;
  final int followingCount;
  final int pinsCount;
  final bool isFollowing;
  final bool isMe;
  final DateTime? createdAt;

  /// The user has an active (24 h) story; [storySeen] = the viewer saw it all.
  final bool hasStory;
  final bool storySeen;

  /// Shop details, set when [isBusiness].
  final Business? business;

  /// I blocked this user.
  final bool isBlocked;

  Profile copyWith({
    bool? isFollowing,
    int? followersCount,
    bool? storySeen,
    bool? isBlocked,
  }) => Profile(
    id: id,
    username: username,
    name: name,
    avatarUrl: avatarUrl,
    isBusiness: isBusiness,
    verified: verified,
    bio: bio,
    followersCount: followersCount ?? this.followersCount,
    followingCount: followingCount,
    pinsCount: pinsCount,
    isFollowing: isFollowing ?? this.isFollowing,
    isMe: isMe,
    createdAt: createdAt,
    hasStory: hasStory,
    storySeen: storySeen ?? this.storySeen,
    business: business,
    isBlocked: isBlocked ?? this.isBlocked,
  );
}

class Me extends Profile {
  const Me({
    required super.id,
    required super.username,
    required super.name,
    super.avatarUrl,
    super.isBusiness,
    super.verified,
    super.bio,
    super.followersCount,
    super.followingCount,
    super.pinsCount,
    super.isFollowing,
    super.isMe = true,
    super.createdAt,
    super.hasStory,
    super.storySeen,
    super.business,
    this.email = '',
    this.isAdmin = false,
  });

  factory Me.fromJson(Json j) {
    final p = Profile.fromJson(j);
    return Me(
      id: p.id,
      username: p.username,
      name: p.name,
      avatarUrl: p.avatarUrl,
      isBusiness: p.isBusiness,
      verified: p.verified,
      bio: p.bio,
      followersCount: p.followersCount,
      followingCount: p.followingCount,
      pinsCount: p.pinsCount,
      isFollowing: p.isFollowing,
      isMe: true,
      createdAt: p.createdAt,
      hasStory: p.hasStory,
      storySeen: p.storySeen,
      business: p.business,
      email: asString(j['email']),
      isAdmin: asBool(j['isAdmin']),
    );
  }

  final String email;

  /// Can open the web admin panel.
  final bool isAdmin;
}

class AuthResponse {
  const AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Json j) => AuthResponse(
    token: asString(j['token']),
    user: Me.fromJson(asJson(j['user'])),
  );

  final String token;
  final Me user;
}
