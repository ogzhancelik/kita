/// Data models for the Direct Message (DM) system.

class DmMessage {
  final int id;
  final String conversationId;
  final String senderId;
  final String senderUsername;
  final String recipientId;
  final String content;
  final DateTime createdAt;

  const DmMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderUsername,
    required this.recipientId,
    required this.content,
    required this.createdAt,
  });

  factory DmMessage.fromJson(Map<String, dynamic> json) {
    return DmMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      conversationId: json['conversation_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      senderUsername: json['sender_username'] as String? ?? '',
      recipientId: json['recipient_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_username': senderUsername,
        'recipient_id': recipientId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Stable conversation identifier — alphabetically sorted user IDs joined with '_'.
String dmConversationId(String userA, String userB) {
  final ids = [userA, userB]..sort();
  return ids.join('_');
}

/// A single in-game chat message fetched from the match messages endpoint.
class InGameMessage {
  final int id;
  final String matchId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  const InGameMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  factory InGameMessage.fromJson(Map<String, dynamic> json) {
    return InGameMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      matchId: json['match_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// Represents a finished match between two friends, shown as a card in
/// their DM conversation. Messages are loaded lazily on expansion.
class MatchChatCard {
  final String matchId;
  final DateTime playedAt;
  final String whitePlayerId;
  final String blackPlayerId;
  final String? winnerId;
  final String result; // 'white', 'black', 'draw'

  const MatchChatCard({
    required this.matchId,
    required this.playedAt,
    required this.whitePlayerId,
    required this.blackPlayerId,
    this.winnerId,
    required this.result,
  });

  factory MatchChatCard.fromJson(Map<String, dynamic> json) {
    return MatchChatCard(
      matchId: json['id'] as String? ?? '',
      playedAt: DateTime.tryParse(
              json['ended_at']?.toString() ??
                  json['started_at']?.toString() ??
                  '') ??
          DateTime.now(),
      whitePlayerId: json['white_player_id'] as String? ?? '',
      blackPlayerId: json['black_player_id'] as String? ?? '',
      winnerId: json['winner_id'] as String?,
      result: json['result'] as String? ?? 'draw',
    );
  }
}
