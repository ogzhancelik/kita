class UserProfile {
  final String id;
  final String username;
  final int avatarIndex;
  final int rating;
  final bool isProvisional;
  final int wins;
  final int losses;
  final int draws;
  final int totalGames;
  final double winRate;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.username,
    this.avatarIndex = 0,
    this.rating = 1200,
    this.isProvisional = false,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.totalGames = 0,
    this.winRate = 0.0,
    this.createdAt,
  });

  String get displayRating => isProvisional ? '$rating?' : '$rating';

  UserProfile copyWith({
    String? id,
    String? username,
    int? avatarIndex,
    int? rating,
    bool? isProvisional,
    int? wins,
    int? losses,
    int? draws,
    int? totalGames,
    double? winRate,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      rating: rating ?? this.rating,
      isProvisional: isProvisional ?? this.isProvisional,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      totalGames: totalGames ?? this.totalGames,
      winRate: winRate ?? this.winRate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final totalGames = (json['total_games'] as num?)?.toInt() ?? 0;
    final isProv = json['is_provisional'] as bool? ?? (totalGames < 5);
    return UserProfile(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? 'Player',
      avatarIndex: (json['avatar_index'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? 1200,
      isProvisional: isProv,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      totalGames: totalGames,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0.0,
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
      'rating': rating,
      'is_provisional': isProvisional,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'total_games': totalGames,
      'win_rate': winRate,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class GuestProfile {
  final String nickname;
  final int avatarIndex;

  const GuestProfile({
    required this.nickname,
    required this.avatarIndex,
  });

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'avatar_index': avatarIndex,
      };

  factory GuestProfile.fromJson(Map<String, dynamic> json) => GuestProfile(
        nickname: json['nickname'] as String? ?? 'Guest',
        avatarIndex: (json['avatar_index'] as num?)?.toInt() ?? 0,
      );
}
