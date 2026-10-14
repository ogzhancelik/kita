class UserProfile {
  final String id;
  final String username;
  final int avatarIndex;
  final String? avatarCustom;
  final int rating;
  final bool isProvisional;
  final int wins;
  final int losses;
  final int draws;
  final int totalGames;
  final double winRate;
  final List<String> roles;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.username,
    this.avatarIndex = 0,
    this.avatarCustom,
    this.rating = 1200,
    this.isProvisional = false,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.totalGames = 0,
    this.winRate = 0.0,
    this.roles = const [],
    this.createdAt,
  });

  String get displayRating => isProvisional ? '$rating?' : '$rating';
  bool get isAdmin => roles.any((r) => r.toLowerCase() == 'admin');
  bool get isPremium => roles.any((r) => r.toLowerCase() == 'premium');
  bool hasRole(String role) => roles.any((r) => r.toLowerCase() == role.toLowerCase());

  UserProfile copyWith({
    String? id,
    String? username,
    int? avatarIndex,
    String? avatarCustom,
    bool clearAvatarCustom = false,
    int? rating,
    bool? isProvisional,
    int? wins,
    int? losses,
    int? draws,
    int? totalGames,
    double? winRate,
    List<String>? roles,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      avatarCustom: clearAvatarCustom ? null : (avatarCustom ?? this.avatarCustom),
      rating: rating ?? this.rating,
      isProvisional: isProvisional ?? this.isProvisional,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      totalGames: totalGames ?? this.totalGames,
      winRate: winRate ?? this.winRate,
      roles: roles ?? this.roles,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final totalGames = (json['total_games'] as num?)?.toInt() ?? 0;
    final isProv = json['is_provisional'] as bool? ?? (totalGames < 5);
    final rawRoles = (json['roles'] as List<dynamic>?) ?? (json['tags'] as List<dynamic>?);
    return UserProfile(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? 'Player',
      avatarIndex: (json['avatar_index'] as num?)?.toInt() ?? 0,
      avatarCustom: (json['avatar_custom'] as String?) ?? (json['avatarCustom'] as String?),
      rating: (json['rating'] as num?)?.toInt() ?? 1200,
      isProvisional: isProv,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      totalGames: totalGames,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0.0,
      roles: rawRoles != null ? rawRoles.map((e) => e.toString()).toList() : const [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatar_index': avatarIndex,
      if (avatarCustom != null) 'avatar_custom': avatarCustom,
      'rating': rating,
      'is_provisional': isProvisional,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'total_games': totalGames,
      'win_rate': winRate,
      'roles': roles,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class GuestProfile {
  final String nickname;
  final int avatarIndex;
  final String? avatarCustom;

  const GuestProfile({
    required this.nickname,
    required this.avatarIndex,
    this.avatarCustom,
  });

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'avatar_index': avatarIndex,
        if (avatarCustom != null) 'avatar_custom': avatarCustom,
      };

  factory GuestProfile.fromJson(Map<String, dynamic> json) => GuestProfile(
        nickname: json['nickname'] as String? ?? 'Guest',
        avatarIndex: (json['avatar_index'] as num?)?.toInt() ?? 0,
        avatarCustom: (json['avatar_custom'] as String?) ?? (json['avatarCustom'] as String?),
      );
}
