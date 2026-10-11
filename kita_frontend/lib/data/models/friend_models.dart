/// Model for friends and pending friend requests.
class FriendItemModel {
  final String friendshipId;
  final String userId;
  final String username;
  final int avatarIndex;
  final int rating;
  final bool isProvisional;
  final String status;
  final String direction; // "friend", "incoming", "outgoing"
  final bool isOnline;
  final DateTime createdAt;
  final DateTime lastInteractionAt;

  const FriendItemModel({
    required this.friendshipId,
    required this.userId,
    required this.username,
    this.avatarIndex = 0,
    required this.rating,
    this.isProvisional = false,
    required this.status,
    required this.direction,
    required this.isOnline,
    required this.createdAt,
    DateTime? lastInteractionAt,
  }) : lastInteractionAt = lastInteractionAt ?? createdAt;

  String get displayRating => isProvisional ? '$rating?' : '$rating';

  factory FriendItemModel.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now();
    final lastInter = DateTime.tryParse(json['last_interaction_at']?.toString() ?? '') ?? created;
    return FriendItemModel(
      friendshipId: json['friendship_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarIndex: (json['avatar_index'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? 1200,
      isProvisional: json['is_provisional'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      direction: json['direction'] as String? ?? 'friend',
      isOnline: json['is_online'] as bool? ?? false,
      createdAt: created,
      lastInteractionAt: lastInter,
    );
  }

  FriendItemModel copyWith({
    String? friendshipId,
    String? userId,
    String? username,
    int? avatarIndex,
    int? rating,
    bool? isProvisional,
    String? status,
    String? direction,
    bool? isOnline,
    DateTime? createdAt,
    DateTime? lastInteractionAt,
  }) {
    return FriendItemModel(
      friendshipId: friendshipId ?? this.friendshipId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      rating: rating ?? this.rating,
      isProvisional: isProvisional ?? this.isProvisional,
      status: status ?? this.status,
      direction: direction ?? this.direction,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt ?? this.createdAt,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
    );
  }
}
