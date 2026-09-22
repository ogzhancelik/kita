/// Model for friends and pending friend requests.
class FriendItemModel {
  final String friendshipId;
  final String userId;
  final String username;
  final int rating;
  final String status;
  final String direction; // "friend", "incoming", "outgoing"
  final bool isOnline;
  final DateTime createdAt;

  const FriendItemModel({
    required this.friendshipId,
    required this.userId,
    required this.username,
    required this.rating,
    required this.status,
    required this.direction,
    required this.isOnline,
    required this.createdAt,
  });

  factory FriendItemModel.fromJson(Map<String, dynamic> json) {
    return FriendItemModel(
      friendshipId: json['friendship_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 1200,
      status: json['status'] as String? ?? 'pending',
      direction: json['direction'] as String? ?? 'friend',
      isOnline: json['is_online'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
