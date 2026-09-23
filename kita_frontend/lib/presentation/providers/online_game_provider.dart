import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import '../../core/feedback/sound_service.dart';
import '../../core/feedback/toast_service.dart';
import '../../data/models/game_models.dart';
import '../../data/models/ws_message_models.dart';
import '../../data/services/websocket_service.dart';

/// Represents the current state of the online game lifecycle.
enum OnlineMatchState {
  idle, // Not in any game activity
  connecting, // Connecting to WebSocket
  inQueue, // Waiting in matchmaking queue
  inRoom, // Waiting in a room for opponent
  inMatch, // Active game in progress
  gameOver, // Game has ended
}

/// Represents a single move record for the move history panel.
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
}

/// Chat message model for in-game messaging.
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

/// Opponent information.
class OpponentInfo {
  final String id;
  final String name;
  final int rating;

  const OpponentInfo({
    required this.id,
    required this.name,
    required this.rating,
  });
}

/// Central provider for all online game state.
///
/// Uses granular [ValueNotifier]s for each state slice so that widgets
/// can subscribe to only the data they need, avoiding unnecessary rebuilds.
class OnlineGameProvider extends ChangeNotifier {
  final WebSocketService _ws = WebSocketService.instance;
  StreamSubscription<WsMessage>? _wsSubscription;
  Timer? _clockTimer;

  // ─── Core Match State ─────────────────────────────────────────────

  final ValueNotifier<OnlineMatchState> matchState = ValueNotifier(
    OnlineMatchState.idle,
  );
  String? matchId;
  String? myTeam; // "white" or "black"
  String? myUserId;
  String? myUsername;
  int myRating = 1200;
  OpponentInfo? opponentInfo;
  int timeControl = 0;
  final ValueNotifier<String?> roomCode = ValueNotifier(null); // For custom rooms
  String? get currentRoomCode => roomCode.value;

  // ─── Game Engine (dual validation) ────────────────────────────────

  /// Frontend game engine for local move validation + board display.
  final ValueNotifier<KitaGameEngine> gameEngine = ValueNotifier(
    KitaGameEngine(),
  );

  /// Legal moves from the backend (authoritative).
  final ValueNotifier<List<KitaMove>> legalMoves = ValueNotifier([]);

  /// Last move for board highlighting.
  final ValueNotifier<KitaMove?> lastMove = ValueNotifier(null);

  // ─── Move History ─────────────────────────────────────────────────

  final ValueNotifier<List<OnlineMoveRecord>> moveHistory = ValueNotifier([]);

  /// Index of move being viewed. -1 = live (current state).
  final ValueNotifier<int> viewingMoveIndex = ValueNotifier(-1);

  /// Game engine snapshots for each move index (for scrubbing).
  final List<KitaGameEngine> _engineSnapshots = [];

  bool get isViewingHistory => viewingMoveIndex.value >= 0;

  // ─── Chess Clock ──────────────────────────────────────────────────

  final ValueNotifier<int> whiteRemainingMs = ValueNotifier(0);
  final ValueNotifier<int> blackRemainingMs = ValueNotifier(0);

  /// Whose turn it is (for clock active indicator).
  final ValueNotifier<String> currentTurn = ValueNotifier('white');

  // ─── Chat ─────────────────────────────────────────────────────────

  final ValueNotifier<List<ChatMessage>> chatMessages = ValueNotifier([]);
  final ValueNotifier<int> unreadChatCount = ValueNotifier(0);
  bool isChatOpen = true;

  // ─── Game Over ────────────────────────────────────────────────────

  final ValueNotifier<GameOverPayload?> gameOverData = ValueNotifier(null);

  // ─── Online Count ─────────────────────────────────────────────────

  final ValueNotifier<OnlineCountPayload?> onlineCount = ValueNotifier(null);

  // ─── Room Browser ─────────────────────────────────────────────────

  final ValueNotifier<RoomsListPayload?> roomsList = ValueNotifier(null);

  // ─── Rematch ──────────────────────────────────────────────────────

  final ValueNotifier<RematchOfferedPayload?> rematchOffer = ValueNotifier(
    null,
  );
  final ValueNotifier<bool> isRematchRequested = ValueNotifier(false);

  // ─── Match Invitation ─────────────────────────────────────────────

  final ValueNotifier<MatchInvitationPayload?> matchInvitation = ValueNotifier(
    null,
  );

  // ─── Unified Incoming Match Request (Rematch & Friend Challenge) ──

  final ValueNotifier<IncomingMatchRequest?> incomingMatchRequest = ValueNotifier(
    null,
  );

  final ValueNotifier<bool> isGameOverDialogActive = ValueNotifier(false);
  final ValueNotifier<Map<String, dynamic>?> onWsNotificationEvent = ValueNotifier(null);

  // ─── Elapsed Time ─────────────────────────────────────────────────

  final ValueNotifier<int> elapsedSeconds = ValueNotifier(0);
  DateTime? _matchStartedAt;

  // ─── Queue Timer ──────────────────────────────────────────────────

  final ValueNotifier<int> queueElapsedSeconds = ValueNotifier(0);
  Timer? _queueTimer;

  // ─── Error Notification ──────────────────────────────────────────

  final ValueNotifier<WsErrorPayload?> lastError = ValueNotifier(null);

  // ─── Initialization ───────────────────────────────────────────────

  OnlineGameProvider() {
    _wsSubscription = _ws.messages.listen(_handleWsMessage);
    matchState.addListener(notifyListeners);
  }

  void clearError() {
    lastError.value = null;
  }

  /// Connect to WebSocket and start listening.
  void connectAndListen({String? token, String? nickname}) {
    myUserId = null;
    myUsername = null;
    myRating = 1200;
    _ws.connect(token: token, nickname: nickname);
  }

  // ─── Matchmaking ──────────────────────────────────────────────────

  void joinQueue() {
    if (matchState.value != OnlineMatchState.idle) return;
    _ws.send(WsClientType.joinQueue);
  }

  void leaveQueue() {
    _ws.send(WsClientType.leaveQueue);
    _stopQueueTimer();
    matchState.value = OnlineMatchState.idle;
  }

  // ─── Room Management ──────────────────────────────────────────────

  void createRoom({bool isPrivate = false, int timeControl = 180000}) {
    if (matchState.value == OnlineMatchState.inMatch ||
        matchState.value == OnlineMatchState.inQueue) {
      return;
    }
    // Clean any prior or stale state before creating a room
    if (matchState.value != OnlineMatchState.idle) {
      resetToIdle();
    }
    clearError();
    _ws.send(WsClientType.createRoom, {
      'is_private': isPrivate,
      'time_control': timeControl,
    });
  }

  void joinRoom(String code) {
    if (matchState.value == OnlineMatchState.inMatch ||
        matchState.value == OnlineMatchState.inQueue) {
      return;
    }
    if (matchState.value != OnlineMatchState.idle) {
      resetToIdle();
    }
    clearError();
    _ws.send(WsClientType.joinRoom, {'room_code': code.toUpperCase()});
  }

  void leaveRoom() {
    _ws.send(WsClientType.leaveRoom);
    resetToIdle();
  }

  // ─── Online Count ─────────────────────────────────────────────────

  void requestOnlineCount() {
    _ws.send(WsClientType.getOnlineCount);
  }

  // ─── Room Browser ─────────────────────────────────────────────────

  void requestRoomsList({int page = 1, int limit = 20}) {
    _ws.send(WsClientType.listRooms, {'page': page, 'limit': limit});
  }

  // ─── Game Actions ─────────────────────────────────────────────────

  /// Make a move. Validates locally first (dual validation), then sends to backend.
  void makeMove(KitaMove move) {
    if (matchState.value != OnlineMatchState.inMatch) return;
    if (isViewingHistory) return; // Can't move while scrubbing history

    // Frontend validation (dual validation — avoid unnecessary backend requests)
    final engine = gameEngine.value;
    final frontendLegal = engine.getLegalMoves();
    final isLocallyValid = frontendLegal.any(
      (m) =>
          m.pieceId == move.pieceId &&
          m.fromPos == move.fromPos &&
          m.toPos == move.toPos,
    );

    if (!isLocallyValid) {
      debugPrint('[OnlineGame] Move rejected by frontend validation: $move');
      return;
    }

    _ws.send(WsClientType.makeMove, {
      'piece_id': move.pieceId,
      'from_col': move.fromPos.col,
      'from_row': move.fromPos.row,
      'to_col': move.toPos.col,
      'to_row': move.toPos.row,
    });
  }

  void resign() {
    if (matchState.value != OnlineMatchState.inMatch) return;
    _ws.send(WsClientType.resign);
  }

  void sendChat(String content) {
    if (content.trim().isEmpty) return;
    if (content.length > 200) content = content.substring(0, 200);
    _ws.send(WsClientType.chatMessage, {'content': content.trim()});
  }

  // ─── Rematch ──────────────────────────────────────────────────────

  void requestRematch() {
    if (matchId == null) return;
    isRematchRequested.value = true;
    _ws.send(WsClientType.rematchRequest, {'match_id': matchId});
    notifyListeners();
  }

  void cancelRematchRequest() {
    isRematchRequested.value = false;
    notifyListeners();
  }

  void acceptRematch([String? matchId]) {
    final offer = rematchOffer.value;
    final mId = matchId ?? offer?.matchId ?? incomingMatchRequest.value?.id;
    if (mId != null && mId.isNotEmpty) {
      _ws.send(WsClientType.rematchAccept, {'match_id': mId});
    }
    rematchOffer.value = null;
    incomingMatchRequest.value = null;
    notifyListeners();
  }

  void declineRematch([String? matchId]) {
    final offer = rematchOffer.value;
    final mId = matchId ?? offer?.matchId ?? incomingMatchRequest.value?.id;
    if (mId != null && mId.isNotEmpty) {
      _ws.send(WsClientType.rematchDecline, {'match_id': mId});
    }
    rematchOffer.value = null;
    incomingMatchRequest.value = null;
    notifyListeners();
  }

  // ─── Friend Invite ────────────────────────────────────────────────

  void inviteToMatch(String friendId, {int timeControl = 180000, String colorPreference = 'random'}) {
    _ws.send(WsClientType.inviteToMatch, {
      'friend_id': friendId,
      'time_control': timeControl,
      'color_preference': colorPreference,
    });
  }

  void acceptInvitation(String inviteId) {
    _ws.send(WsClientType.acceptInvitation, {'invite_id': inviteId});
    matchInvitation.value = null;
    if (incomingMatchRequest.value?.id == inviteId) {
      incomingMatchRequest.value = null;
    }
    notifyListeners();
  }

  void declineInvitation(String inviteId) {
    _ws.send(WsClientType.declineInvitation, {'invite_id': inviteId});
    matchInvitation.value = null;
    if (incomingMatchRequest.value?.id == inviteId) {
      incomingMatchRequest.value = null;
    }
    notifyListeners();
  }

  // ─── Unified Incoming Request Handlers ────────────────────────────

  void acceptIncomingRequest() {
    final req = incomingMatchRequest.value;
    if (req == null) return;
    if (req.type == IncomingMatchRequestType.friendInvite) {
      acceptInvitation(req.id);
    } else {
      acceptRematch();
    }
  }

  void declineIncomingRequest() {
    final req = incomingMatchRequest.value;
    if (req == null) return;
    if (req.type == IncomingMatchRequestType.friendInvite) {
      declineInvitation(req.id);
    } else {
      declineRematch();
    }
  }

  // ─── Move History Scrubbing ───────────────────────────────────────

  /// View the board state at a specific move index.
  /// Index 0 = initial position, 1 = after first move, etc.
  void viewMoveAt(int index) {
    if (index < 0 ||
        index >= _engineSnapshots.length ||
        index == _engineSnapshots.length - 1) {
      viewingMoveIndex.value = -1; // Go live
      notifyListeners();
      return;
    }
    viewingMoveIndex.value = index;
    notifyListeners();
  }

  /// Return to live (current) board state.
  void goLive() {
    viewingMoveIndex.value = -1;
    notifyListeners();
  }

  /// Get the board state for the currently viewed move index (or live state).
  KitaGameEngine get displayEngine {
    if (!isViewingHistory || _engineSnapshots.isEmpty) {
      return gameEngine.value;
    }
    final idx = viewingMoveIndex.value;
    if (idx >= 0 && idx < _engineSnapshots.length) {
      return _engineSnapshots[idx];
    }
    return gameEngine.value;
  }

  bool get canStepBackward {
    if (_engineSnapshots.length <= 1) return false;
    if (viewingMoveIndex.value == -1) return true;
    return viewingMoveIndex.value > 0;
  }

  bool get canStepForward {
    if (_engineSnapshots.length <= 1) return false;
    return viewingMoveIndex.value >= 0;
  }

  /// Step backward one move in history.
  void stepBackward() {
    if (!canStepBackward) return;
    if (viewingMoveIndex.value == -1) {
      if (_engineSnapshots.length > 1) {
        viewMoveAt(_engineSnapshots.length - 2);
      }
    } else if (viewingMoveIndex.value > 0) {
      viewMoveAt(viewingMoveIndex.value - 1);
    }
  }

  /// Step forward one move in history (or return to live).
  void stepForward() {
    if (!canStepForward) return;
    final current = viewingMoveIndex.value;
    if (current == -1) return;
    if (current < _engineSnapshots.length - 2) {
      viewMoveAt(current + 1);
    } else {
      goLive();
    }
  }

  /// Send a draw offer to opponent via in-game chat.
  void sendDrawOffer() {
    sendChat('🏳️ [Draw Offer]');
  }

  // ─── Chat Panel ───────────────────────────────────────────────────

  void toggleChat() {
    isChatOpen = !isChatOpen;
    if (isChatOpen) {
      unreadChatCount.value = 0;
    }
    notifyListeners();
  }

  // ─── WS Message Handler ───────────────────────────────────────────

  @visibleForTesting
  void handleWsMessageForTesting(WsMessage msg) => _handleWsMessage(msg);

  void _handleWsMessage(WsMessage msg) {
    switch (msg.type) {
      case WsServerType.connected:
        if (msg.payload != null) {
          final data = ConnectedPayload.fromJson(msg.payload!);
          myUserId = data.userId;
          myUsername = data.username;
          myRating = data.rating;
        }
        notifyListeners();

      case WsServerType.queueJoined:
        matchState.value = OnlineMatchState.inQueue;
        _startQueueTimer();

      case WsServerType.queueLeft:
        matchState.value = OnlineMatchState.idle;
        _stopQueueTimer();

      case WsServerType.roomCreated:
        if (msg.payload != null) {
          final data = RoomCreatedPayload.fromJson(msg.payload!);
          roomCode.value = data.roomCode;
          timeControl = data.timeControl;
          matchState.value = OnlineMatchState.inRoom;
        }
        notifyListeners();

      case WsServerType.roomJoined:
        if (matchState.value != OnlineMatchState.inMatch) {
          matchState.value = OnlineMatchState.inRoom;
        }
        notifyListeners();

      case WsServerType.roomLeft:
        matchState.value = OnlineMatchState.idle;
        notifyListeners();

      case WsServerType.matchFound:
        _handleMatchFound(msg.payload);

      case WsServerType.gameState:
        _handleGameState(msg.payload);

      case WsServerType.gameOver:
        _handleGameOver(msg.payload);

      case WsServerType.chatBroadcast:
        _handleChatBroadcast(msg.payload);

      case WsServerType.onlineCount:
        if (msg.payload != null) {
          onlineCount.value = OnlineCountPayload.fromJson(msg.payload!);
        }

      case WsServerType.roomsList:
        if (msg.payload != null) {
          roomsList.value = RoomsListPayload.fromJson(msg.payload!);
        }

      case WsServerType.rematchOffered:
        if (msg.payload != null) {
          final payload = RematchOfferedPayload.fromJson(msg.payload!);
          rematchOffer.value = payload;
          incomingMatchRequest.value = IncomingMatchRequest(
            type: IncomingMatchRequestType.rematch,
            id: payload.matchId,
            senderName: payload.requesterName,
            senderRating: opponentInfo?.rating ?? 1200,
            timeControl: payload.timeControl,
          );
          notifyListeners();
        }

      case WsServerType.rematchAccepted:
        isRematchRequested.value = false;
        rematchOffer.value = null;
        incomingMatchRequest.value = null;
        notifyListeners();

      case WsServerType.rematchDeclined:
        rematchOffer.value = null;
        final rematchDecliner = (msg.payload != null && msg.payload!['decliner_name'] != null)
            ? msg.payload!['decliner_name'] as String
            : (opponentInfo?.name ?? '');
        if (isRematchRequested.value) {
          isRematchRequested.value = false;
          KitaToast.info('online.rematchDeclinedToast'.tr());
        }
        if (incomingMatchRequest.value?.type == IncomingMatchRequestType.rematch) {
          incomingMatchRequest.value = null;
        }
        onWsNotificationEvent.value = {
          'type': 'rematch_declined',
          'decliner': rematchDecliner,
        };
        notifyListeners();

      case WsServerType.matchInvitation:
        if (msg.payload != null) {
          final payload = MatchInvitationPayload.fromJson(msg.payload!);
          matchInvitation.value = payload;
          incomingMatchRequest.value = IncomingMatchRequest(
            type: IncomingMatchRequestType.friendInvite,
            id: payload.inviteId,
            senderName: payload.inviterName,
            senderRating: payload.inviterRating,
            timeControl: payload.timeControl,
            colorPreference: payload.colorPreference,
          );
          notifyListeners();
        }

      case WsServerType.invitationDeclined:
        final inviteDecliner = (msg.payload != null && msg.payload!['decliner_name'] != null)
            ? msg.payload!['decliner_name'] as String
            : '';
        if (incomingMatchRequest.value?.type == IncomingMatchRequestType.friendInvite) {
          incomingMatchRequest.value = null;
        }
        onWsNotificationEvent.value = {
          'type': 'invitation_declined',
          'decliner': inviteDecliner,
        };
        notifyListeners();

      case WsServerType.friendRequest:
        if (msg.payload != null) {
          onWsNotificationEvent.value = {
            'type': 'friend_request',
            'payload': msg.payload,
          };
          notifyListeners();
        }

      case WsServerType.friendRequestDeclined:
        final frDecliner = (msg.payload != null && msg.payload!['decliner_name'] != null)
            ? msg.payload!['decliner_name'] as String
            : '';
        onWsNotificationEvent.value = {
          'type': 'friend_request_declined',
          'decliner': frDecliner,
        };
        notifyListeners();

      case WsServerType.friendRequestAccepted:
        final frAccepter = (msg.payload != null && msg.payload!['accepter_name'] != null)
            ? msg.payload!['accepter_name'] as String
            : '';
        onWsNotificationEvent.value = {
          'type': 'friend_request_accepted',
          'accepter': frAccepter,
        };
        notifyListeners();

      case WsServerType.error:
        _handleError(msg.payload);

      default:
        debugPrint('[OnlineGame] Unhandled WS message type: ${msg.type}');
    }
  }

  void _handleMatchFound(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final data = MatchFoundPayload.fromJson(payload);

    matchId = data.matchId;
    myTeam = data.yourTeam;
    timeControl = data.timeControl;
    opponentInfo = OpponentInfo(
      id: data.opponentId,
      name: data.opponentName,
      rating: data.opponentRating,
    );

    // Clear rematch & invite requests
    isRematchRequested.value = false;
    incomingMatchRequest.value = null;
    rematchOffer.value = null;
    matchInvitation.value = null;

    // Reset game state
    gameEngine.value = KitaGameEngine();
    legalMoves.value = [];
    lastMove.value = null;
    moveHistory.value = [];
    chatMessages.value = [];
    unreadChatCount.value = 0;
    viewingMoveIndex.value = -1;
    gameOverData.value = null;
    rematchOffer.value = null;
    elapsedSeconds.value = 0;
    isChatOpen = true;
    _engineSnapshots.clear();
    _engineSnapshots.add(KitaGameEngine()); // Initial state at index 0

    // Initialize clock
    whiteRemainingMs.value = timeControl;
    blackRemainingMs.value = timeControl;
    currentTurn.value = 'white';

    matchState.value = OnlineMatchState.inMatch;
    _matchStartedAt = DateTime.now();
    _stopQueueTimer();
    _startClockTimer();

    notifyListeners();
  }

  void _handleGameState(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final data = GameStatePayload.fromJson(payload);

    // Update clock from backend (authoritative sync)
    whiteRemainingMs.value = data.whiteRemainingMs;
    blackRemainingMs.value = data.blackRemainingMs;
    currentTurn.value = data.turn;

    // Detect new move and play sound before frontend engine is updated
    final isSingleNewMove = data.moveCount - moveHistory.value.length == 1;
    if (isSingleNewMove && data.lastMove != null) {
      final lm = data.lastMove!;
      final movingTeam = data.turn == 'white' ? 'black' : 'white';
      final oppKingId = movingTeam == 'white' ? 'BK' : 'WK';
      final oppKingPos = gameEngine.value.positions[oppKingId];
      final isCapture = (oppKingPos != null &&
              lm.toCol == oppKingPos.col &&
              lm.toRow == oppKingPos.row) ||
          (data.kingEatenBy.isNotEmpty &&
              gameEngine.value.kingEatenBy != data.kingEatenBy);

      if (isCapture) {
        SoundService.instance.playCapture();
      } else {
        SoundService.instance.playMove();
      }
    }

    // Sync frontend engine from backend positions
    _syncEngineFromBackend(data);

    // Update legal moves
    legalMoves.value = data.legalMoves
        .map(
          (m) => KitaMove(
            pieceId: m.pieceId,
            fromPos: KitaPos(m.fromCol, m.fromRow),
            toPos: KitaPos(m.toCol, m.toRow),
          ),
        )
        .toList();

    // Update last move
    if (data.lastMove != null) {
      lastMove.value = KitaMove(
        pieceId: data.lastMove!.pieceId,
        fromPos: KitaPos(data.lastMove!.fromCol, data.lastMove!.fromRow),
        toPos: KitaPos(data.lastMove!.toCol, data.lastMove!.toRow),
      );
    }

    // Track move history
    if (data.moveCount > moveHistory.value.length && data.lastMove != null) {
      final lm = data.lastMove!;
      final team = data.turn == 'white' ? 'black' : 'white'; // Just moved
      final newHistory = List<OnlineMoveRecord>.from(moveHistory.value)
        ..add(
          OnlineMoveRecord(
            plyIndex: data.moveCount,
            pieceId: lm.pieceId,
            fromCol: lm.fromCol,
            fromRow: lm.fromRow,
            toCol: lm.toCol,
            toRow: lm.toRow,
            playerTeam: team,
          ),
        );
      moveHistory.value = newHistory;

      // Store engine snapshot for history scrubbing
      _engineSnapshots.add(gameEngine.value.clone());
    }
  }

  void _syncEngineFromBackend(GameStatePayload data) {
    // Build positions map from backend data
    final positions = <String, KitaPos?>{};
    for (final entry in data.positions.entries) {
      if (entry.value == null) {
        positions[entry.key] = null;
      } else if (entry.value is Map<String, dynamic>) {
        final posMap = entry.value as Map<String, dynamic>;
        final col =
            (posMap['Col'] as num?)?.toInt() ??
            (posMap['col'] as num?)?.toInt() ??
            0;
        final row =
            (posMap['Row'] as num?)?.toInt() ??
            (posMap['row'] as num?)?.toInt() ??
            0;
        positions[entry.key] = KitaPos(col, row);
      }
    }

    final turn = data.turn == 'white' ? PieceTeam.white : PieceTeam.black;

    // Rebuild engine from backend state (backend is authoritative)
    gameEngine.value = KitaGameEngine.custom(
      positions: positions,
      turn: turn,
      kingEatenBy: data.kingEatenBy,
      moveCount: data.moveCount,
    );
  }

  void _handleGameOver(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final data = GameOverPayload.fromJson(payload);

    if (_matchStartedAt != null) {
      elapsedSeconds.value =
          DateTime.now().difference(_matchStartedAt!).inSeconds;
    }

    gameOverData.value = data;
    matchState.value = OnlineMatchState.gameOver;
    _stopClockTimer();
    SoundService.instance.playGameOver();
    notifyListeners();
  }

  void _handleChatBroadcast(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final data = ChatBroadcastPayload.fromJson(payload);

    final newMessages = List<ChatMessage>.from(chatMessages.value)
      ..add(
        ChatMessage(
          senderId: data.senderId,
          username: data.username,
          content: data.content,
          createdAt: data.createdAt,
        ),
      );
    chatMessages.value = newMessages;

    if (!isChatOpen) {
      unreadChatCount.value++;
    }
  }

  void _handleError(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final error = WsErrorPayload.fromJson(payload);
    debugPrint('[OnlineGame] WS Error: ${error.code} - ${error.message}');
    lastError.value = error;
    notifyListeners();
  }

  // ─── Clock Timer ──────────────────────────────────────────────────

  void _startClockTimer() {
    _stopClockTimer();

    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (matchState.value != OnlineMatchState.inMatch) return;

      // Client-side interpolation: deduct 100ms from the active player's clock if timed match
      if (timeControl > 0) {
        if (currentTurn.value == 'white') {
          final remaining = whiteRemainingMs.value - 100;
          whiteRemainingMs.value = remaining > 0 ? remaining : 0;
        } else {
          final remaining = blackRemainingMs.value - 100;
          blackRemainingMs.value = remaining > 0 ? remaining : 0;
        }
      }

      // Update elapsed seconds for both timed and unlimited (no time limit) modes
      if (_matchStartedAt != null) {
        elapsedSeconds.value = DateTime.now()
            .difference(_matchStartedAt!)
            .inSeconds;
      }
    });
  }

  void _stopClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = null;
  }

  // ─── Queue Timer ──────────────────────────────────────────────────

  void _startQueueTimer() {
    _stopQueueTimer();
    queueElapsedSeconds.value = 0;
    _queueTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      queueElapsedSeconds.value++;
    });
  }

  void _stopQueueTimer() {
    _queueTimer?.cancel();
    _queueTimer = null;
    queueElapsedSeconds.value = 0;
  }

  // ─── Reset ────────────────────────────────────────────────────────

  /// Reset all state back to idle (e.g., going back to dashboard).
  void resetToIdle() {
    clearError();
    matchState.value = OnlineMatchState.idle;
    matchId = null;
    myTeam = null;
    opponentInfo = null;
    roomCode.value = null;
    timeControl = 0;
    gameEngine.value = KitaGameEngine();
    legalMoves.value = [];
    lastMove.value = null;
    moveHistory.value = [];
    viewingMoveIndex.value = -1;
    chatMessages.value = [];
    unreadChatCount.value = 0;
    isChatOpen = true;
    gameOverData.value = null;
    rematchOffer.value = null;
    matchInvitation.value = null;
    incomingMatchRequest.value = null;
    isRematchRequested.value = false;
    isGameOverDialogActive.value = false;
    elapsedSeconds.value = 0;
    whiteRemainingMs.value = 0;
    blackRemainingMs.value = 0;
    _engineSnapshots.clear();
    _matchStartedAt = null;
    _stopClockTimer();
    _stopQueueTimer();
    notifyListeners();
  }

  // ─── Dispose ──────────────────────────────────────────────────────

  @override
  void dispose() {
    _wsSubscription?.cancel();
    matchState.removeListener(notifyListeners);
    _stopClockTimer();
    _stopQueueTimer();
    matchState.dispose();
    roomCode.dispose();
    lastError.dispose();
    gameEngine.dispose();
    legalMoves.dispose();
    lastMove.dispose();
    moveHistory.dispose();
    viewingMoveIndex.dispose();
    whiteRemainingMs.dispose();
    blackRemainingMs.dispose();
    currentTurn.dispose();
    chatMessages.dispose();
    unreadChatCount.dispose();
    gameOverData.dispose();
    onlineCount.dispose();
    roomsList.dispose();
    rematchOffer.dispose();
    isRematchRequested.dispose();
    matchInvitation.dispose();
    incomingMatchRequest.dispose();
    isGameOverDialogActive.dispose();
    elapsedSeconds.dispose();
    queueElapsedSeconds.dispose();
    super.dispose();
  }
}
