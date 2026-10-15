/// Data models for the Direct Message (DM) system.
library;

import 'dart:convert';

class DmMessage {
  final int id;
  final String conversationId;
  final String senderId;
  final String senderUsername;
  final int senderAvatarIndex;
  final String? senderAvatarCustom;
  final String recipientId;
  final String recipientUsername;
  final int recipientAvatarIndex;
  final String? recipientAvatarCustom;
  final String content;
  final DateTime createdAt;

  const DmMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderUsername,
    this.senderAvatarIndex = 0,
    this.senderAvatarCustom,
    required this.recipientId,
    this.recipientUsername = '',
    this.recipientAvatarIndex = 0,
    this.recipientAvatarCustom,
    required this.content,
    required this.createdAt,
  });

  factory DmMessage.fromJson(Map<String, dynamic> json) {
    return DmMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      conversationId: json['conversation_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      senderUsername: json['sender_username'] as String? ?? '',
      senderAvatarIndex: (json['sender_avatar_index'] as num?)?.toInt() ?? 0,
      senderAvatarCustom: (json['sender_avatar_custom'] as String?) ?? (json['senderAvatarCustom'] as String?),
      recipientId: json['recipient_id'] as String? ?? '',
      recipientUsername: json['recipient_username'] as String? ?? '',
      recipientAvatarIndex: (json['recipient_avatar_index'] as num?)?.toInt() ?? 0,
      recipientAvatarCustom: (json['recipient_avatar_custom'] as String?) ?? (json['recipientAvatarCustom'] as String?),
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
        'sender_avatar_index': senderAvatarIndex,
        if (senderAvatarCustom != null) 'sender_avatar_custom': senderAvatarCustom,
        'recipient_id': recipientId,
        'recipient_username': recipientUsername,
        'recipient_avatar_index': recipientAvatarIndex,
        if (recipientAvatarCustom != null) 'recipient_avatar_custom': recipientAvatarCustom,
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

/// Represents a structured match replay share payload sent within a direct message.
class DmReplayPayload {
  static const String prefix = '[KITA_REPLAY]';

  final String matchId;
  final String? shareCode;
  final String? whiteUsername;
  final String? blackUsername;
  final String? result; // 'white', 'black', 'draw'

  const DmReplayPayload({
    required this.matchId,
    this.shareCode,
    this.whiteUsername,
    this.blackUsername,
    this.result,
  });

  String encode() {
    final map = <String, dynamic>{
      'match_id': matchId,
      if (shareCode != null && shareCode!.isNotEmpty) 'code': shareCode,
      if (whiteUsername != null && whiteUsername!.isNotEmpty) 'white': whiteUsername,
      if (blackUsername != null && blackUsername!.isNotEmpty) 'black': blackUsername,
      if (result != null && result!.isNotEmpty) 'result': result,
    };
    return '$prefix${jsonEncode(map)}';
  }

  static DmReplayPayload? tryParse(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith(prefix)) {
      try {
        final jsonStr = trimmed.substring(prefix.length).trim();
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final matchId = (map['match_id'] ?? map['id'] ?? map['code'])?.toString();
        if (matchId == null || matchId.isEmpty) return null;
        return DmReplayPayload(
          matchId: matchId,
          shareCode: map['code']?.toString(),
          whiteUsername: map['white']?.toString(),
          blackUsername: map['black']?.toString(),
          result: map['result']?.toString(),
        );
      } catch (_) {
        return null;
      }
    }

    // Bare link fallback: https://kita.app/replay/{code}
    final uriRegex = RegExp(r'https?://[^\s]+/replay/([A-Za-z0-9_-]+)');
    final match = uriRegex.firstMatch(trimmed);
    if (match != null) {
      final code = match.group(1);
      if (code != null && code.isNotEmpty) {
        return DmReplayPayload(
          matchId: code,
          shareCode: code,
        );
      }
    }

    return null;
  }
}
