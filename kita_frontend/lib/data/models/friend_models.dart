/// Model for friends and pending friend requests.
class FriendItemModel {
  final String friendshipId;
  final String userId;
  final String username;
  final int avatarIndex;
  final String? avatarCustom;
  final int rating;
  final bool isProvisional;
  final String status;
  final String direction; // "friend", "incoming", "outgoing"
  final bool isOnline;
  final String presenceStatus; // "online", "afk", "offline"
  final DateTime createdAt;
  final DateTime lastInteractionAt;

  const FriendItemModel({
    required this.friendshipId,
    required this.userId,
    required this.username,
    this.avatarIndex = 0,
    this.avatarCustom,
    required this.rating,
    this.isProvisional = false,
    required this.status,
    required this.direction,
    required this.isOnline,
    this.presenceStatus = 'online',
    required this.createdAt,
    DateTime? lastInteractionAt,
  }) : lastInteractionAt = lastInteractionAt ?? createdAt;

  String get displayRating => isProvisional ? '$rating?' : '$rating';

  bool get isAfk => isOnline && presenceStatus == 'afk';

  factory FriendItemModel.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now();
    final lastInter = DateTime.tryParse(json['last_interaction_at']?.toString() ?? '') ?? created;
    final isOnlineVal = json['is_online'] as bool? ?? false;
    final presence = json['presence_status'] as String? ?? (isOnlineVal ? 'online' : 'offline');

    return FriendItemModel(
      friendshipId: json['friendship_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarIndex: (json['avatar_index'] as num?)?.toInt() ?? 0,
      avatarCustom: (json['avatar_custom'] as String?) ?? (json['avatarCustom'] as String?),
      rating: (json['rating'] as num?)?.toInt() ?? 1200,
      isProvisional: json['is_provisional'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      direction: json['direction'] as String? ?? 'friend',
      isOnline: isOnlineVal,
      presenceStatus: presence,
      createdAt: created,
      lastInteractionAt: lastInter,
    );
  }

  FriendItemModel copyWith({
    String? friendshipId,
    String? userId,
    String? username,
    int? avatarIndex,
    String? avatarCustom,
    int? rating,
    bool? isProvisional,
    String? status,
    String? direction,
    bool? isOnline,
    String? presenceStatus,
    DateTime? createdAt,
    DateTime? lastInteractionAt,
  }) {
    return FriendItemModel(
      friendshipId: friendshipId ?? this.friendshipId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      avatarCustom: avatarCustom ?? this.avatarCustom,
      rating: rating ?? this.rating,
      isProvisional: isProvisional ?? this.isProvisional,
      status: status ?? this.status,
      direction: direction ?? this.direction,
      isOnline: isOnline ?? this.isOnline,
      presenceStatus: presenceStatus ?? this.presenceStatus,
      createdAt: createdAt ?? this.createdAt,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
    );
  }
}

/// Model for user search results in global player search.
class PlayerSearchResultModel {
  final String id;
  final String username;
  final int avatarIndex;
  final String? avatarCustom;
  final int rating;
  final bool isProvisional;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;
  final List<String> roles;
  final String friendshipStatus; // 'none', 'friend', 'incoming', 'outgoing'
  final String? friendshipId;

  const PlayerSearchResultModel({
    required this.id,
    required this.username,
    this.avatarIndex = 0,
    this.avatarCustom,
    required this.rating,
    this.isProvisional = false,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.winRate = 0.0,
    this.roles = const [],
    this.friendshipStatus = 'none',
    this.friendshipId,
  });

  String get displayRating => isProvisional ? '$rating?' : '$rating';
  bool get isAdmin => roles.any((r) => r.toLowerCase() == 'admin');
  bool get isPremium => roles.any((r) => r.toLowerCase() == 'premium');
  bool hasRole(String role) => roles.any((r) => r.toLowerCase() == role.toLowerCase());

  factory PlayerSearchResultModel.fromJson(Map<String, dynamic> json) {
    final rawRoles = (json['roles'] as List<dynamic>?) ?? (json['tags'] as List<dynamic>?);
    return PlayerSearchResultModel(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarIndex: (json['avatar_index'] as num?)?.toInt() ?? 0,
      avatarCustom: (json['avatar_custom'] as String?) ?? (json['avatarCustom'] as String?),
      rating: (json['rating'] as num?)?.toInt() ?? 1200,
      isProvisional: json['is_provisional'] as bool? ?? false,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0.0,
      roles: rawRoles != null ? rawRoles.map((e) => e.toString()).toList() : const [],
      friendshipStatus: json['friendship_status'] as String? ?? 'none',
      friendshipId: json['friendship_id'] as String?,
    );
  }

  PlayerSearchResultModel copyWith({
    String? id,
    String? username,
    int? avatarIndex,
    String? avatarCustom,
    int? rating,
    bool? isProvisional,
    int? wins,
    int? losses,
    int? draws,
    double? winRate,
    List<String>? roles,
    String? friendshipStatus,
    String? friendshipId,
  }) {
    return PlayerSearchResultModel(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      avatarCustom: avatarCustom ?? this.avatarCustom,
      rating: rating ?? this.rating,
      isProvisional: isProvisional ?? this.isProvisional,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      winRate: winRate ?? this.winRate,
      roles: roles ?? this.roles,
      friendshipStatus: friendshipStatus ?? this.friendshipStatus,
      friendshipId: friendshipId ?? this.friendshipId,
    );
  }
}

