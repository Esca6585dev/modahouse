import 'json.dart';

class UserBrief {
  const UserBrief({
    required this.id,
    required this.username,
    required this.name,
    this.avatarUrl = '',
  });

  factory UserBrief.fromJson(Json j) => UserBrief(
    id: asInt(j['id']),
    username: asString(j['username']),
    name: asString(j['name']),
    avatarUrl: asString(j['avatarUrl']),
  );

  final int id;
  final String username;
  final String name;

  /// Relative path, empty when the user has no avatar.
  final String avatarUrl;

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
    this.bio = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.pinsCount = 0,
    this.isFollowing = false,
    this.isMe = false,
    this.createdAt,
  });

  factory Profile.fromJson(Json j) => Profile(
    id: asInt(j['id']),
    username: asString(j['username']),
    name: asString(j['name']),
    avatarUrl: asString(j['avatarUrl']),
    bio: asString(j['bio']),
    followersCount: asInt(j['followersCount']),
    followingCount: asInt(j['followingCount']),
    pinsCount: asInt(j['pinsCount']),
    isFollowing: asBool(j['isFollowing']),
    isMe: asBool(j['isMe']),
    createdAt: asDate(j['createdAt']),
  );

  final String bio;
  final int followersCount;
  final int followingCount;
  final int pinsCount;
  final bool isFollowing;
  final bool isMe;
  final DateTime? createdAt;

  Profile copyWith({bool? isFollowing, int? followersCount}) => Profile(
    id: id,
    username: username,
    name: name,
    avatarUrl: avatarUrl,
    bio: bio,
    followersCount: followersCount ?? this.followersCount,
    followingCount: followingCount,
    pinsCount: pinsCount,
    isFollowing: isFollowing ?? this.isFollowing,
    isMe: isMe,
    createdAt: createdAt,
  );
}

class Me extends Profile {
  const Me({
    required super.id,
    required super.username,
    required super.name,
    super.avatarUrl,
    super.bio,
    super.followersCount,
    super.followingCount,
    super.pinsCount,
    super.isFollowing,
    super.isMe = true,
    super.createdAt,
    this.email = '',
  });

  factory Me.fromJson(Json j) {
    final p = Profile.fromJson(j);
    return Me(
      id: p.id,
      username: p.username,
      name: p.name,
      avatarUrl: p.avatarUrl,
      bio: p.bio,
      followersCount: p.followersCount,
      followingCount: p.followingCount,
      pinsCount: p.pinsCount,
      isFollowing: p.isFollowing,
      isMe: true,
      createdAt: p.createdAt,
      email: asString(j['email']),
    );
  }

  final String email;
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
