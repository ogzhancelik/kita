/// WebSocket message models that mirror the backend game/messages.go DTOs.
/// All message types and payload structures are 1:1 with the Go backend.
library;

// ─── WebSocket Message Types ─────────────────────────────────────────

/// Client → Server message types
class WsClientType {
  WsClientType._();

  static const String joinQueue = 'join_queue';
  static const String leaveQueue = 'leave_queue';
  static const String makeMove = 'make_move';
  static const String chatMessage = 'chat_message';
  static const String resign = 'resign';
  static const String createRoom = 'create_room';
  static const String joinRoom = 'join_room';
  static const String getOnlineCount = 'get_online_count';
  static const String listRooms = 'list_rooms';
  static const String rematchRequest = 'rematch_request';
  static const String rematchAccept = 'rematch_accept';
  static const String rematchDecline = 'rematch_decline';
  static const String rematchCancel = 'rematch_cancel';
  static const String inviteToMatch = 'invite_to_match';
  static const String acceptInvitation = 'accept_invitation';
  static const String declineInvitation = 'decline_invitation';
  static const String cancelInvitation = 'cancel_invitation';
  static const String leaveRoom = 'leave_room';
  static const String updateAvatar = 'update_avatar';
  static const String drawOffer = 'draw_offer';
  static const String drawAccept = 'draw_accept';
  static const String drawDecline = 'draw_decline';
}

/// Server → Client message types
class WsServerType {
  WsServerType._();

  static const String connected = 'connected';
  static const String queueJoined = 'queue_joined';
  static const String matchFound = 'match_found';
  static const String roomCreated = 'room_created';
  static const String roomJoined = 'room_joined';
  static const String roomLeft = 'room_left';
  static const String gameState = 'game_state';
  static const String gameOver = 'game_over';
  static const String chatBroadcast = 'chat_broadcast';
  static const String error = 'error';
  static const String onlineCount = 'online_count';
  static const String roomsList = 'rooms_list';
  static const String rematchOffered = 'rematch_offered';
  static const String rematchAccepted = 'rematch_accepted';
  static const String rematchDeclined = 'rematch_declined';
  static const String matchInvitation = 'match_invitation';
  static const String matchInvitationSent = 'match_invitation_sent';
  static const String invitationDeclined = 'invitation_declined';
  static const String invitationCancelled = 'invitation_cancelled';
  static const String queueLeft = 'queue_left';
  static const String friendRequest = 'friend_request';
  static const String friendRequestDeclined = 'friend_request_declined';
  static const String friendRequestAccepted = 'friend_request_accepted';
  static const String friendPresence = 'friend_presence';
  static const String matchClosed = 'match_closed';
  static const String drawOffered = 'draw_offered';
  static const String drawDeclined = 'draw_declined';
}

// ─── Time Control Presets (ms) ────────────────────────────────────────

class TimeControlPreset {
  TimeControlPreset._();

  static const int oneMin = 60000;
  static const int threeMin = 180000;
  static const int fiveMin = 300000;
  static const int unlimited = 0;

  static String label(int ms) {
    switch (ms) {
      case oneMin:
        return '1 min';
      case threeMin:
        return '3 min';
      case fiveMin:
        return '5 min';
      case unlimited:
        return '∞';
      default:
        return '${(ms / 60000).round()} min';
    }
  }
}

// ─── Base WS Message ──────────────────────────────────────────────────

class WsMessage {
  final String type;
  final Map<String, dynamic>? payload;

  const WsMessage({required this.type, this.payload});

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    return WsMessage(
      type: json['type'] as String? ?? '',
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (payload != null) 'payload': payload,
    };
  }
}

// ─── Connected Payload ────────────────────────────────────────────────

class ConnectedPayload {
  final String userId;
  final String username;
  final int rating;
  final int avatarIndex;
  final String? activeMatchId;
  final String? activeRoomCode;

  const ConnectedPayload({
    required this.userId,
    required this.username,
    required this.rating,
    this.avatarIndex = 0,
    this.activeMatchId,
    this.activeRoomCode,
  });

  factory ConnectedPayload.fromJson(Map<String, dynamic> json) {
    return ConnectedPayload(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 1200,
      avatarIndex: (json['avatar_index'] as num?)?.toInt() ?? 0,
      activeMatchId: json['active_match_id'] as String?,
      activeRoomCode: json['active_room_code'] as String?,
    );
  }
}

// ─── Online Move Record ───────────────────────────────────────────────

class OnlineMoveRecord {
  final int plyIndex;
  final String pieceId;
  final int fromCol;
  final int fromRow;
  final int toCol;
  final int toRow;
  final String playerTeam; // "white" or "black"

  const OnlineMoveRecord({
    required this.plyIndex,
    required this.pieceId,
    required this.fromCol,
    required this.fromRow,
    required this.toCol,
    required this.toRow,
    required this.playerTeam,
  });

  Map<String, dynamic> toJson() => {
    'plyIndex': plyIndex,
    'pieceId': pieceId,
    'fromCol': fromCol,
    'fromRow': fromRow,
    'toCol': toCol,
    'toRow': toRow,
    'playerTeam': playerTeam,
  };

  factory OnlineMoveRecord.fromJson(Map<String, dynamic> json) {
    final piece = (json['pieceId'] as String?) ??
        (json['piece_id'] as String?) ??
        (json['piece'] as String?) ??
        '';
    String team = (json['playerTeam'] as String?) ??
        (json['player_team'] as String?) ??
        '';
    if (team.isEmpty) {
      team = piece.startsWith('W') ? 'white' : 'black';
    }

    return OnlineMoveRecord(
      plyIndex: (json['plyIndex'] as num?)?.toInt() ??
          (json['ply_index'] as num?)?.toInt() ??
          (json['ply'] as num?)?.toInt() ??
          0,
      pieceId: piece,
      fromCol: (json['fromCol'] as num?)?.toInt() ??
          (json['from_col'] as num?)?.toInt() ??
          0,
      fromRow: (json['fromRow'] as num?)?.toInt() ??
          (json['from_row'] as num?)?.toInt() ??
          0,
      toCol: (json['toCol'] as num?)?.toInt() ??
          (json['to_col'] as num?)?.toInt() ??
          0,
      toRow: (json['toRow'] as num?)?.toInt() ??
          (json['to_row'] as num?)?.toInt() ??
          0,
      playerTeam: team,
    );
  }
}

// ─── Chat Message ─────────────────────────────────────────────────────

class ChatMessage {
  final String senderId;
  final String username;
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.senderId,
    required this.username,
    required this.content,
    required this.createdAt,
  });
}

// ─── Match Found Payload ──────────────────────────────────────────────

class MatchFoundPayload {
  final String matchId;
  final String yourTeam; // "white" or "black"
  final String opponentId;
  final String opponentName;
  final int opponentRating;
  final int opponentAvatarIndex;
  final int timeControl;
  final bool isReconnect;
  final DateTime? startedAt;
  final int elapsedSeconds;
  final List<OnlineMoveRecord> moveHistory;
  final List<ChatMessage> chatHistory;

  const MatchFoundPayload({
    required this.matchId,
    required this.yourTeam,
    required this.opponentId,
    required this.opponentName,
    required this.opponentRating,
    this.opponentAvatarIndex = 0,
    required this.timeControl,
    this.isReconnect = false,
    this.startedAt,
    this.elapsedSeconds = 0,
    this.moveHistory = const [],
    this.chatHistory = const [],
  });

  factory MatchFoundPayload.fromJson(Map<String, dynamic> json) {
    DateTime? started;
    if (json['started_at'] != null) {
      started = DateTime.tryParse(json['started_at'].toString());
    }

    final rawMoves = json['move_history'] as List<dynamic>? ?? [];
    final moves = rawMoves
        .map((m) => OnlineMoveRecord.fromJson(m as Map<String, dynamic>))
        .toList();

    final rawChat = json['chat_history'] as List<dynamic>? ?? [];
    final chat = rawChat.map((c) {
      final map = c as Map<String, dynamic>;
      DateTime created;
      if (map['created_at'] != null) {
        created = DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now();
      } else {
        created = DateTime.now();
      }
      return ChatMessage(
        senderId: map['sender_id'] as String? ?? '',
        username: map['username'] as String? ?? '',
        content: map['content'] as String? ?? '',
        createdAt: created,
      );
    }).toList();

    return MatchFoundPayload(
      matchId: json['match_id'] as String? ?? '',
      yourTeam: json['your_team'] as String? ?? 'white',
      opponentId: json['opponent_id'] as String? ?? '',
      opponentName: json['opponent_name'] as String? ?? 'Opponent',
      opponentRating: (json['opponent_rating'] as num?)?.toInt() ?? 1200,
      opponentAvatarIndex: (json['opponent_avatar_index'] as num?)?.toInt() ?? 0,
      timeControl: (json['time_control'] as num?)?.toInt() ?? 0,
      isReconnect: json['is_reconnect'] as bool? ?? false,
      startedAt: started,
      elapsedSeconds: (json['elapsed_seconds'] as num?)?.toInt() ?? 0,
      moveHistory: moves,
      chatHistory: chat,
    );
  }
}

/// Represents an outgoing friend challenge awaiting response.
class PendingOutgoingChallenge {
  final String? inviteId;
  final String friendId;
  final String friendName;
  final int? friendRating;
  final int timeControl;
  final String colorPreference;
  final DateTime sentAt;

  const PendingOutgoingChallenge({
    this.inviteId,
    required this.friendId,
    required this.friendName,
    this.friendRating,
    required this.timeControl,
    required this.colorPreference,
    required this.sentAt,
  });

  PendingOutgoingChallenge copyWith({
    String? inviteId,
    String? friendId,
    String? friendName,
    int? friendRating,
    int? timeControl,
    String? colorPreference,
    DateTime? sentAt,
  }) {
    return PendingOutgoingChallenge(
      inviteId: inviteId ?? this.inviteId,
      friendId: friendId ?? this.friendId,
      friendName: friendName ?? this.friendName,
      friendRating: friendRating ?? this.friendRating,
      timeControl: timeControl ?? this.timeControl,
      colorPreference: colorPreference ?? this.colorPreference,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}

// ─── Game State Payload ───────────────────────────────────────────────

class GameStatePayload {
  final String matchId;
  final String turn;
  final String status;
  final int moveCount;
  final String kingEatenBy;
  final Map<String, dynamic> positions; // piece_id -> {col, row} or null
  final List<MoveDtoPayload> legalMoves;
  final int whiteRemainingMs;
  final int blackRemainingMs;
  final int timeControl;
  final MoveDtoPayload? lastMove;
  final DateTime? startedAt;
  final int elapsedSeconds;

  const GameStatePayload({
    required this.matchId,
    required this.turn,
    required this.status,
    required this.moveCount,
    required this.kingEatenBy,
    required this.positions,
    required this.legalMoves,
    required this.whiteRemainingMs,
    required this.blackRemainingMs,
    required this.timeControl,
    this.lastMove,
    this.startedAt,
    this.elapsedSeconds = 0,
  });

  factory GameStatePayload.fromJson(Map<String, dynamic> json) {
    final rawMoves = json['legal_moves'] as List<dynamic>? ?? [];
    final lmJson = json['last_move'] as Map<String, dynamic>?;
    DateTime? started;
    if (json['started_at'] != null) {
      started = DateTime.tryParse(json['started_at'].toString());
    }

    return GameStatePayload(
      matchId: json['match_id'] as String? ?? '',
      turn: json['turn'] as String? ?? 'white',
      status: json['status'] as String? ?? 'ongoing',
      moveCount: (json['move_count'] as num?)?.toInt() ?? 0,
      kingEatenBy: json['king_eaten_by'] as String? ?? '',
      positions: json['positions'] as Map<String, dynamic>? ?? {},
      legalMoves: rawMoves
          .map((e) => MoveDtoPayload.fromJson(e as Map<String, dynamic>))
          .toList(),
      whiteRemainingMs: (json['white_remaining_ms'] as num?)?.toInt() ?? 0,
      blackRemainingMs: (json['black_remaining_ms'] as num?)?.toInt() ?? 0,
      timeControl: (json['time_control'] as num?)?.toInt() ?? 0,
      lastMove: lmJson != null ? MoveDtoPayload.fromJson(lmJson) : null,
      startedAt: started,
      elapsedSeconds: (json['elapsed_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Move DTO Payload ─────────────────────────────────────────────────

class MoveDtoPayload {
  final String pieceId;
  final int fromCol;
  final int fromRow;
  final int toCol;
  final int toRow;

  const MoveDtoPayload({
    required this.pieceId,
    required this.fromCol,
    required this.fromRow,
    required this.toCol,
    required this.toRow,
  });

  factory MoveDtoPayload.fromJson(Map<String, dynamic> json) {
    return MoveDtoPayload(
      pieceId: json['piece_id'] as String? ?? '',
      fromCol: (json['from_col'] as num?)?.toInt() ?? 0,
      fromRow: (json['from_row'] as num?)?.toInt() ?? 0,
      toCol: (json['to_col'] as num?)?.toInt() ?? 0,
      toRow: (json['to_row'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'piece_id': pieceId,
    'from_col': fromCol,
    'from_row': fromRow,
    'to_col': toCol,
    'to_row': toRow,
  };
}

// ─── Game Over Payload ────────────────────────────────────────────────

class GameOverPayload {
  final String matchId;
  final String? winnerId;
  final String? winnerTeam;
  final String result;
  final String reason;
  final Map<String, dynamic>? ratingChanges;

  const GameOverPayload({
    required this.matchId,
    this.winnerId,
    this.winnerTeam,
    required this.result,
    required this.reason,
    this.ratingChanges,
  });

  bool get isDraw => winner == 'draw' || result == 'draw';

  String get winner {
    if (winnerTeam != null && winnerTeam!.isNotEmpty) {
      return winnerTeam!;
    }
    if (result == 'white_wins' || result == 'white_won') return 'white';
    if (result == 'black_wins' || result == 'black_won') return 'black';
    return 'draw';
  }

  factory GameOverPayload.fromJson(Map<String, dynamic> json) {
    return GameOverPayload(
      matchId: json['match_id'] as String? ?? '',
      winnerId: json['winner_id'] as String?,
      winnerTeam: json['winner_team'] as String?,
      result: json['result'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      ratingChanges: json['rating_changes'] as Map<String, dynamic>?,
    );
  }
}

// ─── Chat Broadcast Payload ───────────────────────────────────────────

class ChatBroadcastPayload {
  final String matchId;
  final String senderId;
  final String username;
  final String content;
  final DateTime createdAt;

  const ChatBroadcastPayload({
    required this.matchId,
    required this.senderId,
    required this.username,
    required this.content,
    required this.createdAt,
  });

  factory ChatBroadcastPayload.fromJson(Map<String, dynamic> json) {
    return ChatBroadcastPayload(
      matchId: json['match_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// ─── Error Payload ────────────────────────────────────────────────────

class WsErrorPayload {
  final String code;
  final String message;

  const WsErrorPayload({required this.code, required this.message});

  factory WsErrorPayload.fromJson(Map<String, dynamic> json) {
    return WsErrorPayload(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

// ─── Room Created Payload ─────────────────────────────────────────────

class RoomCreatedPayload {
  final String roomCode;
  final int timeControl;
  final bool isPrivate;

  const RoomCreatedPayload({
    required this.roomCode,
    required this.timeControl,
    this.isPrivate = false,
  });

  factory RoomCreatedPayload.fromJson(Map<String, dynamic> json) {
    return RoomCreatedPayload(
      roomCode: json['room_code'] as String? ?? '',
      timeControl: (json['time_control'] as num?)?.toInt() ?? 0,
      isPrivate: json['is_private'] as bool? ?? false,
    );
  }
}

// ─── Online Count Payload ─────────────────────────────────────────────

class OnlineCountPayload {
  final int count;
  final int inQueue;

  const OnlineCountPayload({required this.count, required this.inQueue});

  int get totalOnline => count;

  factory OnlineCountPayload.fromJson(Map<String, dynamic> json) {
    return OnlineCountPayload(
      count: (json['count'] as num?)?.toInt() ?? 0,
      inQueue: (json['in_queue'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Rooms List Payload ───────────────────────────────────────────────

class RoomInfoPayload {
  final String roomCode;
  final String? hostId;
  final String hostName;
  final int hostRating;
  final int hostAvatarIndex;
  final int timeControl;
  final bool isPrivate;

  const RoomInfoPayload({
    required this.roomCode,
    this.hostId,
    required this.hostName,
    required this.hostRating,
    this.hostAvatarIndex = 0,
    required this.timeControl,
    required this.isPrivate,
  });

  factory RoomInfoPayload.fromJson(Map<String, dynamic> json) {
    return RoomInfoPayload(
      roomCode: json['room_code'] as String? ?? '',
      hostId: json['host_id'] as String?,
      hostName: json['host_name'] as String? ?? 'Unknown',
      hostRating: (json['host_rating'] as num?)?.toInt() ?? 1200,
      hostAvatarIndex: (json['host_avatar_index'] as num?)?.toInt() ?? 0,
      timeControl: (json['time_control'] as num?)?.toInt() ?? 0,
      isPrivate: json['is_private'] as bool? ?? false,
    );
  }
}

class RoomsListPayload {
  final List<RoomInfoPayload> rooms;
  final int page;
  final int totalPages;
  final int total;

  const RoomsListPayload({
    required this.rooms,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  factory RoomsListPayload.fromJson(Map<String, dynamic> json) {
    final rawRooms = json['rooms'] as List<dynamic>? ?? [];
    return RoomsListPayload(
      rooms: rawRooms
          .map((e) => RoomInfoPayload.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Rematch Payload ──────────────────────────────────────────────────

class RematchOfferedPayload {
  final String matchId;
  final String requesterId;
  final String requesterName;
  final int requesterAvatarIndex;
  final int timeControl;

  const RematchOfferedPayload({
    required this.matchId,
    required this.requesterId,
    required this.requesterName,
    this.requesterAvatarIndex = 0,
    required this.timeControl,
  });

  factory RematchOfferedPayload.fromJson(Map<String, dynamic> json) {
    return RematchOfferedPayload(
      matchId: json['match_id'] as String? ?? '',
      requesterId: json['requester_id'] as String? ?? '',
      requesterName: json['requester_name'] as String? ?? '',
      requesterAvatarIndex: (json['requester_avatar_index'] as num?)?.toInt() ?? 0,
      timeControl: (json['time_control'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Match Invitation Payload ─────────────────────────────────────────

class MatchInvitationPayload {
  final String inviteId;
  final String inviterId;
  final String inviterName;
  final int inviterRating;
  final int inviterAvatarIndex;
  final int timeControl;
  final String colorPreference;

  const MatchInvitationPayload({
    required this.inviteId,
    required this.inviterId,
    required this.inviterName,
    required this.inviterRating,
    this.inviterAvatarIndex = 0,
    required this.timeControl,
    this.colorPreference = 'random',
  });

  factory MatchInvitationPayload.fromJson(Map<String, dynamic> json) {
    return MatchInvitationPayload(
      inviteId: json['invite_id'] as String? ?? '',
      inviterId: json['inviter_id'] as String? ?? '',
      inviterName: json['inviter_name'] as String? ?? '',
      inviterRating: (json['inviter_rating'] as num?)?.toInt() ?? 1200,
      inviterAvatarIndex: (json['inviter_avatar_index'] as num?)?.toInt() ?? 0,
      timeControl: (json['time_control'] as num?)?.toInt() ?? 0,
      colorPreference: json['color_preference'] as String? ?? 'random',
    );
  }
}

// ─── Unified Incoming Match Request (Rematch & Friend Challenge) ──────

enum IncomingMatchRequestType {
  rematch,
  friendInvite,
}

class IncomingMatchRequest {
  final IncomingMatchRequestType type;
  final String id; // matchId for rematch, inviteId for friend challenge
  final String? senderId;
  final String senderName;
  final int senderRating;
  final int timeControl;
  final String colorPreference;
  final DateTime createdAt;

  IncomingMatchRequest({
    required this.type,
    required this.id,
    this.senderId,
    required this.senderName,
    this.senderRating = 1200,
    required this.timeControl,
    this.colorPreference = 'random',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class PendingOutgoingRematch {
  final String matchId;
  final String opponentId;
  final String opponentName;
  final int? opponentRating;
  final int? opponentAvatarIndex;
  final int timeControl;
  final DateTime sentAt;

  const PendingOutgoingRematch({
    required this.matchId,
    required this.opponentId,
    required this.opponentName,
    this.opponentRating,
    this.opponentAvatarIndex,
    required this.timeControl,
    required this.sentAt,
  });
}

// ─── Draw Offer Payloads ──────────────────────────────────────────────

class DrawOfferPayload {
  final String matchId;
  final String playerId;
  final String username;

  const DrawOfferPayload({
    required this.matchId,
    required this.playerId,
    required this.username,
  });

  factory DrawOfferPayload.fromJson(Map<String, dynamic> json) {
    return DrawOfferPayload(
      matchId: json['match_id'] as String? ?? '',
      playerId: json['player_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'match_id': matchId,
    'player_id': playerId,
    'username': username,
  };
}

class DrawDeclinedPayload {
  final String matchId;
  final String playerId;

  const DrawDeclinedPayload({
    required this.matchId,
    required this.playerId,
  });

  factory DrawDeclinedPayload.fromJson(Map<String, dynamic> json) {
    return DrawDeclinedPayload(
      matchId: json['match_id'] as String? ?? '',
      playerId: json['player_id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'match_id': matchId,
    'player_id': playerId,
  };
}

