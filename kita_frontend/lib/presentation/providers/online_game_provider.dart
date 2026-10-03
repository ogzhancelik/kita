import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/feedback/haptic_service.dart';
import '../../core/feedback/sound_service.dart';
import '../../core/feedback/toast_service.dart';
import '../../data/models/dm_models.dart';
import '../../data/models/game_models.dart';
import '../../data/models/ws_message_models.dart';
export '../../data/models/ws_message_models.dart' show OnlineMoveRecord, ChatMessage;
import '../../data/services/local_match_history_service.dart';
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

/// Opponent information.
class OpponentInfo {
  final String id;
  final String name;
  final int rating;
  final int avatarIndex;

  const OpponentInfo({
    required this.id,
    required this.name,
    required this.rating,
    this.avatarIndex = 0,
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
  bool _lowTimeAlertPlayed = false;
  DateTime? _turnStartedAt;
  int _turnBaseRemainingMs = 0;
  DateTime? _queueStartedAt;

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
  int roomTimeControl = TimeControlPreset.threeMin;
  bool isRoomPrivate = false;

  /// Public rooms available for the user to join (strictly excluding user's own room).
  List<RoomInfoPayload> get joinableRooms {
    final list = roomsList.value?.rooms ?? [];
    return list.where((r) {
      if (r.isPrivate) return false;
      if (myUserId != null && myUserId!.isNotEmpty && r.hostId == myUserId) return false;
      if (myUsername != null && myUsername!.isNotEmpty && r.hostName == myUsername) return false;
      if (currentRoomCode != null && currentRoomCode!.isNotEmpty && r.roomCode == currentRoomCode) return false;
      return true;
    }).toList();
  }

  // ─── Pending Outgoing Friend Challenges ───────────────────────────
  final ValueNotifier<List<PendingOutgoingChallenge>> pendingOutgoingChallenges =
      ValueNotifier([]);
  final ValueNotifier<PendingOutgoingChallenge?> pendingOutgoingChallenge =
      ValueNotifier(null);

  // ─── Reconnection State ───────────────────────────────────────────
  final ValueNotifier<bool> isReconnectedMatch = ValueNotifier(false);

  // ─── Offline Compatibility ────────────────────────────────────────
  bool get isOffline => false;
  PlayMode? get offlinePlayMode => null;

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
  final ValueNotifier<PendingOutgoingRematch?> pendingOutgoingRematch = ValueNotifier(null);

  // ─── Draw Offer ───────────────────────────────────────────────────

  final ValueNotifier<DrawOfferPayload?> drawOffer = ValueNotifier(null);
  final ValueNotifier<bool> isDrawOfferPending = ValueNotifier(false);

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
  final ValueNotifier<Map<String, dynamic>?> onWsFriendPresence = ValueNotifier(null);

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
    _loadPendingChallengesFromPrefs();
  }

  static const String _pendingChallengesPrefKey = 'kita_pending_outgoing_challenges';

  Future<void> _loadPendingChallengesFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingChallengesPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        final now = DateTime.now();
        final loaded = decoded
            .map((item) => PendingOutgoingChallenge.fromJson(item as Map<String, dynamic>))
            .where((c) {
              if (c.expiresAt != null) {
                return now.isBefore(c.expiresAt!);
              }
              return now.difference(c.sentAt).inHours < 24;
            })
            .toList();
        pendingOutgoingChallenges.value = loaded;
        pendingOutgoingChallenge.value = loaded.firstOrNull;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[OnlineGameProvider] Failed to load pending challenges from prefs: $e');
    }
  }

  Future<void> _savePendingChallengesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = pendingOutgoingChallenges.value;
      if (list.isEmpty) {
        await prefs.remove(_pendingChallengesPrefKey);
      } else {
        final encoded = jsonEncode(list.map((c) => c.toJson()).toList());
        await prefs.setString(_pendingChallengesPrefKey, encoded);
      }
    } catch (e) {
      debugPrint('[OnlineGameProvider] Failed to save pending challenges to prefs: $e');
    }
  }

  bool hasPendingChallengeTo(String friendId) {
    return pendingOutgoingChallenges.value.any((c) => c.friendId == friendId);
  }

  void clearError() {
    lastError.value = null;
  }

  /// Connect to WebSocket and start listening.
  void connectAndListen({String? token, String? nickname, int? avatarIndex}) {
    myUserId = null;
    myUsername = null;
    myRating = 1200;
    _ws.connect(token: token, nickname: nickname, avatarIndex: avatarIndex);
  }

  /// Update the player's avatar on the server via WebSocket.
  void updateAvatar(int avatarIndex) {
    _ws.send(WsClientType.updateAvatar, {'avatar_index': avatarIndex});
  }

  // ─── Matchmaking ──────────────────────────────────────────────────

  void joinQueue() {
    if (matchState.value != OnlineMatchState.idle) return;
    if (pendingOutgoingChallenges.value.isNotEmpty) {
      cancelAllOutgoingChallenges();
    }
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
    if (pendingOutgoingChallenges.value.isNotEmpty) {
      cancelAllOutgoingChallenges();
    }
    // Clean any prior or stale state before creating a room
    if (matchState.value != OnlineMatchState.idle) {
      resetToIdle();
    }
    clearError();
    roomTimeControl = timeControl;
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
    if (pendingOutgoingChallenges.value.isNotEmpty) {
      cancelAllOutgoingChallenges();
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

  /// Resigns/forfeits the match and immediately resets client state to idle.
  /// Used when dismissing an active game card from the dashboard or abandoning a defunct match.
  void resignAndClear() {
    if (matchState.value != OnlineMatchState.inMatch) {
      resetToIdle();
      return;
    }
    try {
      _ws.send(WsClientType.resign);
    } catch (e) {
      debugPrint('[OnlineGame] Failed to send resign: $e');
    }
    resetToIdle();
  }

  void sendChat(String content) {
    if (content.trim().isEmpty) return;
    if (content.length > 200) content = content.substring(0, 200);

    _ws.send(WsClientType.chatMessage, {
      'content': content.trim(),
      if (opponentInfo != null && opponentInfo!.id.isNotEmpty)
        'recipient_id': opponentInfo!.id,
    });
  }

  // ─── Rematch ──────────────────────────────────────────────────────

  void requestRematch() {
    if (matchId == null) return;
    pendingOutgoingRematch.value = PendingOutgoingRematch(
      matchId: matchId!,
      opponentId: opponentInfo?.id ?? '',
      opponentName: opponentInfo?.name ?? 'online.opponent'.tr(),
      opponentRating: opponentInfo?.rating,
      opponentAvatarIndex: opponentInfo?.avatarIndex,
      timeControl: timeControl > 0 ? timeControl : 180000,
      sentAt: DateTime.now(),
    );
    isRematchRequested.value = true;
    _ws.send(WsClientType.rematchRequest, {'match_id': matchId});
    notifyListeners();
  }

  void cancelRematchRequest() {
    isRematchRequested.value = false;
    final mId = pendingOutgoingRematch.value?.matchId ?? matchId;
    pendingOutgoingRematch.value = null;
    if (mId != null && mId.isNotEmpty) {
      _ws.send(WsClientType.rematchCancel, {'match_id': mId});
    }
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
    pendingOutgoingRematch.value = null;
    isRematchRequested.value = false;
    onWsNotificationEvent.value = {
      'type': 'rematch_resolved',
      'match_id': mId,
      'accepted': true,
    };
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
    onWsNotificationEvent.value = {
      'type': 'rematch_resolved',
      'match_id': mId,
      'accepted': false,
    };
    notifyListeners();
  }

  // ─── Friend Invite ────────────────────────────────────────────────

  void inviteToMatch(
    String friendId, {
    String? friendName,
    int? friendRating,
    int timeControl = 180000,
    String colorPreference = 'random',
  }) {
    final newChallenge = PendingOutgoingChallenge(
      friendId: friendId,
      friendName: friendName ?? 'Friend',
      friendRating: friendRating,
      timeControl: timeControl,
      colorPreference: colorPreference,
      sentAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );
    final currentList = List<PendingOutgoingChallenge>.from(pendingOutgoingChallenges.value);
    currentList.removeWhere((c) => c.friendId == friendId);
    currentList.insert(0, newChallenge);
    pendingOutgoingChallenges.value = currentList;
    pendingOutgoingChallenge.value = currentList.firstOrNull;
    _savePendingChallengesToPrefs();

    _ws.send(WsClientType.inviteToMatch, {
      'friend_id': friendId,
      'time_control': timeControl,
      'color_preference': colorPreference,
    });
    notifyListeners();
  }

  void cancelAllOutgoingChallenges() {
    final list = List<PendingOutgoingChallenge>.from(pendingOutgoingChallenges.value);
    for (final c in list) {
      _ws.send(WsClientType.cancelInvitation, {
        'friend_id': c.friendId,
        if (c.inviteId != null && c.inviteId!.isNotEmpty) 'invite_id': c.inviteId,
      });
    }
    // Send generic cancel to ensure backend clears all outgoing challenges
    _ws.send(WsClientType.cancelInvitation, {});

    pendingOutgoingChallenges.value = [];
    pendingOutgoingChallenge.value = null;
    _savePendingChallengesToPrefs();
    notifyListeners();
  }

  void cancelOutgoingChallenge({String? friendId, String? inviteId}) {
    if (friendId == null && inviteId == null) {
      cancelAllOutgoingChallenges();
      return;
    }
    final currentList = List<PendingOutgoingChallenge>.from(pendingOutgoingChallenges.value);
    PendingOutgoingChallenge? target;
    if (inviteId != null && inviteId.isNotEmpty) {
      target = currentList.where((c) => c.inviteId == inviteId).firstOrNull;
    }
    if (target == null && friendId != null && friendId.isNotEmpty) {
      target = currentList.where((c) => c.friendId == friendId).firstOrNull;
    }
    target ??= currentList.firstOrNull;

    if (target != null) {
      _ws.send(WsClientType.cancelInvitation, {
        'friend_id': target.friendId,
        if (target.inviteId != null && target.inviteId!.isNotEmpty)
          'invite_id': target.inviteId,
      });
      currentList.removeWhere((c) =>
          (target!.inviteId != null && target.inviteId!.isNotEmpty && c.inviteId == target.inviteId) ||
          c.friendId == target.friendId);
      pendingOutgoingChallenges.value = currentList;
      pendingOutgoingChallenge.value = currentList.firstOrNull;
      _savePendingChallengesToPrefs();
      notifyListeners();
    }
  }

  void acceptInvitation(String inviteId, {String? inviterId, int? timeControl, String? colorPref}) {
    final payload = <String, dynamic>{'invite_id': inviteId};
    if (inviterId != null && inviterId.isNotEmpty) payload['inviter_id'] = inviterId;
    if (timeControl != null) payload['time_control'] = timeControl;
    if (colorPref != null && colorPref.isNotEmpty) payload['color_preference'] = colorPref;
    _ws.send(WsClientType.acceptInvitation, payload);
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

  /// Dismisses the incoming challenge banner/request without sending a decline to server,
  /// keeping the challenge notification alive in the notification center.
  void dismissIncomingChallenge([String? inviteId]) {
    if (inviteId == null || incomingMatchRequest.value?.id == inviteId) {
      incomingMatchRequest.value = null;
      notifyListeners();
    }
  }

  // ─── Move History Scrubbing ───────────────────────────────────────

  /// View the board state at a specific move index.
  /// Index 0 = initial position, 1 = after first move, etc.
  void viewMoveAt(int index) {
    if (index < 0 || index >= _engineSnapshots.length) {
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
    if (current < _engineSnapshots.length - 1) {
      viewMoveAt(current + 1);
    } else {
      goLive();
    }
  }

  /// Send a draw offer to opponent.
  void sendDrawOffer() {
    if (isOffline) return;
    isDrawOfferPending.value = true;
    _ws.send(WsClientType.drawOffer);
    notifyListeners();
  }

  /// Accept an incoming draw offer from opponent.
  void acceptDrawOffer() {
    if (isOffline) return;
    drawOffer.value = null;
    isDrawOfferPending.value = false;
    _ws.send(WsClientType.drawAccept);
    notifyListeners();
  }

  /// Decline an incoming draw offer from opponent.
  void declineDrawOffer() {
    if (isOffline) return;
    drawOffer.value = null;
    _ws.send(WsClientType.drawDecline);
    notifyListeners();
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

          // If provider had an active match state, but server reports no active match exists:
          if (!isOffline && matchState.value == OnlineMatchState.inMatch) {
            if (data.activeMatchId == null ||
                data.activeMatchId!.isEmpty ||
                data.activeMatchId != matchId) {
              debugPrint(
                '[OnlineGame] Connected: match $matchId is not active on server. Resetting to idle.',
              );
              resetToIdle();
            }
          }
          // If provider had an active room, but server reports no active waiting room:
          if (matchState.value == OnlineMatchState.inRoom &&
              (data.activeRoomCode == null || data.activeRoomCode!.isEmpty)) {
            debugPrint(
              '[OnlineGame] Connected: room is not active on server. Resetting to idle.',
            );
            resetToIdle();
          }
        }
        requestRoomsList(page: 1, limit: 10);
        notifyListeners();

      case WsServerType.queueJoined:
        matchState.value = OnlineMatchState.inQueue;
        _startQueueTimer();
        pendingOutgoingChallenges.value = [];
        pendingOutgoingChallenge.value = null;
        _savePendingChallengesToPrefs();
        notifyListeners();

      case WsServerType.queueLeft:
        matchState.value = OnlineMatchState.idle;
        _stopQueueTimer();

      case WsServerType.roomCreated:
        if (msg.payload != null) {
          final data = RoomCreatedPayload.fromJson(msg.payload!);
          roomCode.value = data.roomCode;
          timeControl = data.timeControl;
          roomTimeControl = data.timeControl;
          isRoomPrivate = data.isPrivate;
          matchState.value = OnlineMatchState.inRoom;
          pendingOutgoingChallenges.value = [];
          pendingOutgoingChallenge.value = null;
          _savePendingChallengesToPrefs();
        }
        notifyListeners();

      case WsServerType.roomJoined:
        if (matchState.value != OnlineMatchState.inMatch) {
          matchState.value = OnlineMatchState.inRoom;
          pendingOutgoingChallenges.value = [];
          pendingOutgoingChallenge.value = null;
          _savePendingChallengesToPrefs();
        }
        notifyListeners();

      case WsServerType.roomLeft:
        roomCode.value = null;
        isRoomPrivate = false;
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

      case WsServerType.dmBroadcast:
        _handleDmBroadcast(msg.payload);

      case WsServerType.matchClosed:
        debugPrint('[OnlineGame] Server notified that match is closed.');
        if (matchState.value != OnlineMatchState.gameOver) {
          resetToIdle();
          KitaToast.info('dashboard.pendingSection.matchClosedDesc'.tr());
        }

      case WsServerType.onlineCount:
        if (msg.payload != null) {
          onlineCount.value = OnlineCountPayload.fromJson(msg.payload!);
        }

      case WsServerType.roomsList:
        if (msg.payload != null) {
          final payload = RoomsListPayload.fromJson(msg.payload!);
          roomsList.value = payload;
          _syncRoomStateWithRoomsList(payload);
          notifyListeners();
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
            colorPreference: payload.colorPreference ?? 'random',
          );
          notifyListeners();
        }

      case WsServerType.rematchAccepted:
        isRematchRequested.value = false;
        pendingOutgoingRematch.value = null;
        rematchOffer.value = null;
        incomingMatchRequest.value = null;
        notifyListeners();

      case WsServerType.rematchDeclined:
        rematchOffer.value = null;
        final rematchDecliner = (msg.payload != null && msg.payload!['decliner_name'] != null)
            ? msg.payload!['decliner_name'] as String
            : (opponentInfo?.name ?? '');
        if (isRematchRequested.value || pendingOutgoingRematch.value != null) {
          isRematchRequested.value = false;
          pendingOutgoingRematch.value = null;
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

      case WsServerType.drawOffered:
        if (msg.payload != null) {
          final payload = DrawOfferPayload.fromJson(msg.payload!);
          drawOffer.value = payload;
          KitaToast.info('online.drawOfferReceived'.tr(args: [payload.username]));
          notifyListeners();
        }

      case WsServerType.drawDeclined:
        isDrawOfferPending.value = false;
        drawOffer.value = null;
        KitaToast.info('online.drawOfferDeclined'.tr());
        notifyListeners();

      case WsServerType.sentChallenges:
        if (msg.payload?['challenges'] is List || msg.payload is List) {
          final rawList = (msg.payload?['challenges'] is List)
              ? msg.payload!['challenges'] as List
              : (msg.payload is List ? msg.payload as List : []);
          final list = rawList
              .map((item) => PendingOutgoingChallenge.fromJson(item as Map<String, dynamic>))
              .toList();
          pendingOutgoingChallenges.value = list;
          pendingOutgoingChallenge.value = list.firstOrNull;
          _savePendingChallengesToPrefs();
          notifyListeners();
        }

      case WsServerType.matchInvitationSent:
        final sentInviteId = msg.payload?['invite_id'] as String?;
        final sentFriendId = msg.payload?['friend_id'] as String?;
        final expNum = msg.payload?['expires_at'] as num?;
        DateTime? expiresAt;
        if (expNum != null && expNum > 0) {
          expiresAt = DateTime.fromMillisecondsSinceEpoch(expNum.toInt() * 1000);
        }
        if (sentFriendId != null) {
          final currentList = List<PendingOutgoingChallenge>.from(pendingOutgoingChallenges.value);
          final idx = currentList.indexWhere((c) => c.friendId == sentFriendId);
          if (idx != -1) {
            currentList[idx] = currentList[idx].copyWith(
              inviteId: (sentInviteId != null && sentInviteId.isNotEmpty) ? sentInviteId : currentList[idx].inviteId,
              expiresAt: expiresAt ?? currentList[idx].expiresAt,
            );
            pendingOutgoingChallenges.value = currentList;
            pendingOutgoingChallenge.value = currentList.firstOrNull;
            _savePendingChallengesToPrefs();
            notifyListeners();
          }
        }
        KitaToast.success('online.inviteSent'.tr());

      case WsServerType.matchInvitation:
        if (msg.payload != null) {
          final payload = MatchInvitationPayload.fromJson(msg.payload!);
          matchInvitation.value = payload;
          final expiresAt = payload.expiresAt ?? DateTime.now().add(const Duration(hours: 24));
          incomingMatchRequest.value = IncomingMatchRequest(
            type: IncomingMatchRequestType.friendInvite,
            id: payload.inviteId,
            senderId: payload.inviterId,
            senderName: payload.inviterName,
            senderRating: payload.inviterRating,
            timeControl: payload.timeControl,
            colorPreference: payload.colorPreference,
            expiresAt: expiresAt,
          );
          notifyListeners();
        }

      case WsServerType.invitationDeclined:
        final inviteDecliner = (msg.payload != null && msg.payload!['decliner_name'] != null)
            ? msg.payload!['decliner_name'] as String
            : '';
        final declinedInviteId = msg.payload?['invite_id'] as String?;
        final declinedFriendId = msg.payload?['friend_id'] as String?;
        final currentList = List<PendingOutgoingChallenge>.from(pendingOutgoingChallenges.value);
        currentList.removeWhere((c) =>
            (declinedInviteId != null && c.inviteId == declinedInviteId) ||
            (declinedFriendId != null && c.friendId == declinedFriendId) ||
            (inviteDecliner.isNotEmpty && c.friendName == inviteDecliner));
        pendingOutgoingChallenges.value = currentList;
        pendingOutgoingChallenge.value = currentList.firstOrNull;
        _savePendingChallengesToPrefs();

        if (incomingMatchRequest.value?.type == IncomingMatchRequestType.friendInvite) {
          incomingMatchRequest.value = null;
        }
        onWsNotificationEvent.value = {
          'type': 'invitation_declined',
          'decliner': inviteDecliner,
        };
        notifyListeners();

      case WsServerType.invitationCancelled:
        final cancelledInviteId = msg.payload?['invite_id'] as String?;
        final cancelledInviterId = msg.payload?['inviter_id'] as String?;
        final cancelReason = msg.payload?['reason'] as String?;
        if (incomingMatchRequest.value?.id == cancelledInviteId ||
            (cancelledInviterId != null &&
                incomingMatchRequest.value?.senderId == cancelledInviterId)) {
          incomingMatchRequest.value = null;
        }
        if (matchInvitation.value?.inviteId == cancelledInviteId ||
            (cancelledInviterId != null &&
                matchInvitation.value?.inviterId == cancelledInviterId)) {
          matchInvitation.value = null;
        }
        if (cancelledInviteId != null) {
          final currentList = List<PendingOutgoingChallenge>.from(pendingOutgoingChallenges.value);
          final removed = currentList.where((c) => c.inviteId == cancelledInviteId).isNotEmpty;
          if (removed) {
            currentList.removeWhere((c) => c.inviteId == cancelledInviteId);
            pendingOutgoingChallenges.value = currentList;
            pendingOutgoingChallenge.value = currentList.firstOrNull;
            _savePendingChallengesToPrefs();
            if (cancelReason == 'timeout') {
              KitaToast.info('online.inviteTimeout'.tr());
            }
          }
        }
        if (matchState.value == OnlineMatchState.connecting) {
          resetToIdle();
        }
        onWsNotificationEvent.value = {
          'type': 'invitation_cancelled',
          'invite_id': cancelledInviteId,
          'inviter_id': cancelledInviterId,
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

      case WsServerType.friendPresence:
        if (msg.payload != null) {
          onWsFriendPresence.value = msg.payload;
          notifyListeners();
        }

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
    isReconnectedMatch.value = data.isReconnect;
    pendingOutgoingChallenges.value = [];
    pendingOutgoingChallenge.value = null;
    _savePendingChallengesToPrefs();
    roomCode.value = null;
    isRoomPrivate = false;
    opponentInfo = OpponentInfo(
      id: data.opponentId,
      name: data.opponentName,
      rating: data.opponentRating,
      avatarIndex: data.opponentAvatarIndex,
    );

    // Clear rematch & invite requests
    isRematchRequested.value = false;
    pendingOutgoingRematch.value = null;
    incomingMatchRequest.value = null;
    rematchOffer.value = null;
    matchInvitation.value = null;
    drawOffer.value = null;
    isDrawOfferPending.value = false;
    onWsNotificationEvent.value = {
      'type': 'rematch_resolved',
      'match_id': data.matchId,
      'accepted': true,
    };

    if (data.isReconnect) {
      // Reconnected match: restore move history, snapshots, chat, and elapsed time!
      final moves = data.moveHistory;
      var engine = KitaGameEngine();
      _engineSnapshots.clear();
      _engineSnapshots.add(engine.clone());
      KitaMove? lastM;

      for (final rec in moves) {
        final km = KitaMove(
          pieceId: rec.pieceId,
          fromPos: KitaPos(rec.fromCol, rec.fromRow),
          toPos: KitaPos(rec.toCol, rec.toRow),
        );
        engine = engine.applyMove(km);
        _engineSnapshots.add(engine.clone());
        lastM = km;
      }

      gameEngine.value = engine;
      lastMove.value = lastM;
      moveHistory.value = moves;
      viewingMoveIndex.value = -1;

      chatMessages.value = data.chatHistory;
      unreadChatCount.value = 0;
      gameOverData.value = null;
      isChatOpen = true;

      if (data.startedAt != null) {
        _matchStartedAt = data.startedAt;
        elapsedSeconds.value =
            DateTime.now().difference(data.startedAt!).inSeconds;
      } else if (data.elapsedSeconds > 0) {
        _matchStartedAt = DateTime.now()
            .subtract(Duration(seconds: data.elapsedSeconds));
        elapsedSeconds.value = data.elapsedSeconds;
      } else {
        _matchStartedAt = DateTime.now();
        elapsedSeconds.value = 0;
      }
    } else {
      // Fresh new match: Reset game state
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
      _matchStartedAt = data.startedAt ?? DateTime.now();
    }

    // Initialize clock
    whiteRemainingMs.value = timeControl;
    blackRemainingMs.value = timeControl;
    currentTurn.value = 'white';

    matchState.value = OnlineMatchState.inMatch;
    _matchStartedAt ??= DateTime.now();
    _turnStartedAt = _matchStartedAt;
    _turnBaseRemainingMs = timeControl;
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

    _turnStartedAt = DateTime.now();
    _turnBaseRemainingMs =
        data.turn == 'white' ? data.whiteRemainingMs : data.blackRemainingMs;

    if (data.startedAt != null) {
      _matchStartedAt = data.startedAt;
      elapsedSeconds.value =
          DateTime.now().difference(data.startedAt!).inSeconds;
    } else if (data.elapsedSeconds > 0 && elapsedSeconds.value == 0) {
      _matchStartedAt = DateTime.now()
          .subtract(Duration(seconds: data.elapsedSeconds));
      elapsedSeconds.value = data.elapsedSeconds;
    }

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
        HapticService.instance.medium();
      } else {
        SoundService.instance.playMove();
        HapticService.instance.light();
      }
    }

    _lowTimeAlertPlayed = false;

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

    // Track move history & return to live automatically on new move
    if (data.moveCount > moveHistory.value.length && data.lastMove != null) {
      drawOffer.value = null;
      isDrawOfferPending.value = false;

      // If user was viewing move history, return to live automatically
      if (viewingMoveIndex.value != -1) {
        viewingMoveIndex.value = -1;
      }

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

    final prevEngine = gameEngine.value;
    KitaMove? lmWhite = prevEngine.executedMoveWhite ?? prevEngine.lastMoveWhite;
    KitaMove? lmBlack = prevEngine.executedMoveBlack ?? prevEngine.lastMoveBlack;
    if (data.lastMove != null) {
      final km = KitaMove(
        pieceId: data.lastMove!.pieceId,
        fromPos: KitaPos(data.lastMove!.fromCol, data.lastMove!.fromRow),
        toPos: KitaPos(data.lastMove!.toCol, data.lastMove!.toRow),
      );
      final movingTeam = data.turn == 'white' ? 'black' : 'white';
      if (movingTeam == 'white') {
        lmWhite = km;
      } else {
        lmBlack = km;
      }
    }

    // Rebuild engine from backend state (backend is authoritative)
    gameEngine.value = KitaGameEngine.custom(
      positions: positions,
      turn: turn,
      lastMoveWhite: lmWhite,
      lastMoveBlack: lmBlack,
      executedMoveWhite: lmWhite,
      executedMoveBlack: lmBlack,
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

    if (data.reason == 'timeout') {
      if (data.winner == 'white') {
        blackRemainingMs.value = 0;
      } else if (data.winner == 'black') {
        whiteRemainingMs.value = 0;
      }
    }

    gameOverData.value = data;
    matchState.value = OnlineMatchState.gameOver;
    drawOffer.value = null;
    isDrawOfferPending.value = false;
    _stopClockTimer();
    SoundService.instance.playGameOver();
    HapticService.instance.heavy();
    LocalMatchHistoryService.instance.notifyMatchesChanged();
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

  void _handleDmBroadcast(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final dm = DmMessage.fromJson(payload);

    // Only process in-game chat if currently in a match or game over screen with this opponent
    if (opponentInfo == null || opponentInfo!.id.isEmpty) return;
    final oppId = opponentInfo!.id;
    if (dm.senderId != oppId && dm.recipientId != oppId) return;

    // Deduplicate against messages already in the list
    final isDuplicate = chatMessages.value.any((m) =>
        m.senderId == dm.senderId &&
        m.content == dm.content &&
        m.createdAt.millisecondsSinceEpoch == dm.createdAt.millisecondsSinceEpoch);
    if (isDuplicate) return;

    final newMessages = List<ChatMessage>.from(chatMessages.value)
      ..add(
        ChatMessage(
          senderId: dm.senderId,
          username: dm.senderUsername,
          content: dm.content,
          createdAt: dm.createdAt,
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
    pendingOutgoingChallenges.value = [];
    pendingOutgoingChallenge.value = null;
    _savePendingChallengesToPrefs();
    notifyListeners();

    final isMatchNotFound = error.code == 'ERR_MATCH_NOT_FOUND' ||
        error.message.toLowerCase().contains('match not found') ||
        error.message.toLowerCase().contains('no active match');

    if (isMatchNotFound) {
      if (matchState.value == OnlineMatchState.inMatch ||
          matchState.value == OnlineMatchState.inRoom ||
          matchState.value == OnlineMatchState.connecting) {
        debugPrint(
          '[OnlineGame] Server indicated match/room not found. Resetting state to idle.',
        );
        resetToIdle();
      }
      if (matchState.value != OnlineMatchState.gameOver) {
        KitaToast.info('online.matchNotFoundOrClosed'.tr());
      }
      return;
    }

    if (matchState.value == OnlineMatchState.connecting) {
      resetToIdle();
    }

    String message;
    if (error.code == 'ERR_PLAYER_OFFLINE' ||
        error.message.toLowerCase().contains('not online') ||
        error.message.toLowerCase().contains('no longer online')) {
      // Clear any pending rematch state – the opponent is gone.
      if (isRematchRequested.value || pendingOutgoingRematch.value != null) {
        isRematchRequested.value = false;
        pendingOutgoingRematch.value = null;
        onWsNotificationEvent.value = {
          'type': 'rematch_declined',
          'decliner': opponentInfo?.name ?? '',
          'reason': 'offline',
        };
        notifyListeners();
      }
      message = 'online.friendOffline'.tr();
    } else if (error.code == 'ERR_ALREADY_IN_MATCH' ||
        error.message.toLowerCase().contains('already in a match') ||
        error.message.toLowerCase().contains('already in match')) {
      message = 'online.friendInMatch'.tr();
    } else {
      message = error.message;
    }
    KitaToast.error(message);
  }

  // ─── Clock Timer ──────────────────────────────────────────────────

  void _startClockTimer() {
    _stopClockTimer();

    _turnStartedAt = DateTime.now();
    _turnBaseRemainingMs = currentTurn.value == 'white'
        ? whiteRemainingMs.value
        : blackRemainingMs.value;

    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _tickClock();
    });
  }

  void _tickClock() {
    if (matchState.value != OnlineMatchState.inMatch) return;

    // Client-side interpolation: deduct real elapsed milliseconds from active player's clock
    if (timeControl > 0 && _turnStartedAt != null) {
      final elapsedMs =
          DateTime.now().difference(_turnStartedAt!).inMilliseconds;
      final remaining = _turnBaseRemainingMs - elapsedMs;
      final clampedRemaining = remaining > 0 ? remaining : 0;

      if (currentTurn.value == 'white') {
        whiteRemainingMs.value = clampedRemaining;
      } else {
        blackRemainingMs.value = clampedRemaining;
      }

      // Low-time alert sound & haptic played once when local player has <= 10 seconds on their turn
      final activeTeam = myTeam;
      if (activeTeam != null && currentTurn.value == activeTeam) {
        final myRemainingMs = clampedRemaining;
        if (myRemainingMs > 0 && myRemainingMs <= 10000) {
          if (!_lowTimeAlertPlayed) {
            _lowTimeAlertPlayed = true;
            SoundService.instance.playLowTime();
            HapticService.instance.medium();
          }
        } else if (myRemainingMs > 10000) {
          _lowTimeAlertPlayed = false;
        }
      } else {
        _lowTimeAlertPlayed = false;
      }
    }

    // Update elapsed seconds for both timed and unlimited (no time limit) modes
    if (_matchStartedAt != null) {
      elapsedSeconds.value =
          DateTime.now().difference(_matchStartedAt!).inSeconds;
    }
  }

  void _stopClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = null;
    _turnStartedAt = null;
    _turnBaseRemainingMs = 0;
    _lowTimeAlertPlayed = false;
  }

  /// Call when app resumes from background (lifecycle change, web tab focus).
  void syncClocks() {
    if (matchState.value == OnlineMatchState.inMatch) {
      _tickClock();
    } else if (matchState.value == OnlineMatchState.inQueue &&
        _queueStartedAt != null) {
      queueElapsedSeconds.value =
          DateTime.now().difference(_queueStartedAt!).inSeconds;
    }
  }

  // ─── Queue Timer ──────────────────────────────────────────────────

  void _startQueueTimer() {
    _stopQueueTimer();
    _queueStartedAt = DateTime.now();
    queueElapsedSeconds.value = 0;
    _queueTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_queueStartedAt != null) {
        queueElapsedSeconds.value =
            DateTime.now().difference(_queueStartedAt!).inSeconds;
      }
    });
  }

  void _stopQueueTimer() {
    _queueTimer?.cancel();
    _queueTimer = null;
    _queueStartedAt = null;
    queueElapsedSeconds.value = 0;
  }

  // ─── Reset ────────────────────────────────────────────────────────

  /// Leaves a finished match to return to dashboard.
  /// Preserves pending rematch request so it appears in dashboard priority card.
  void leaveFinishedMatch() {
    clearError();
    matchState.value = OnlineMatchState.idle;
    roomCode.value = null;
    isRoomPrivate = false;
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
    drawOffer.value = null;
    isDrawOfferPending.value = false;
    isGameOverDialogActive.value = false;
    isReconnectedMatch.value = false;
    elapsedSeconds.value = 0;
    whiteRemainingMs.value = 0;
    blackRemainingMs.value = 0;
    _engineSnapshots.clear();
    _matchStartedAt = null;
    _stopClockTimer();
    _stopQueueTimer();
    LocalMatchHistoryService.instance.notifyMatchesChanged();
    notifyListeners();
  }

  /// Reset all state back to idle (e.g., going back to dashboard).
  void resetToIdle() {
    clearError();
    matchState.value = OnlineMatchState.idle;
    matchId = null;
    myTeam = null;
    opponentInfo = null;
    roomCode.value = null;
    isRoomPrivate = false;
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
    drawOffer.value = null;
    isDrawOfferPending.value = false;
    rematchOffer.value = null;
    matchInvitation.value = null;
    incomingMatchRequest.value = null;
    isRematchRequested.value = false;
    pendingOutgoingRematch.value = null;
    isGameOverDialogActive.value = false;
    // Note: Do not clear pendingOutgoingChallenges on disconnection so sent challenges persist
    isReconnectedMatch.value = false;
    elapsedSeconds.value = 0;
    whiteRemainingMs.value = 0;
    blackRemainingMs.value = 0;
    _engineSnapshots.clear();
    _matchStartedAt = null;
    _stopClockTimer();
    _stopQueueTimer();
    LocalMatchHistoryService.instance.notifyMatchesChanged();
    notifyListeners();
  }

  /// Synchronize the local room state with the server's public rooms list.
  void _syncRoomStateWithRoomsList(RoomsListPayload payload) {
    // If the player is currently playing in an active match, do not alter room state
    if (matchState.value == OnlineMatchState.inMatch) return;

    RoomInfoPayload? myPublicRoom;
    for (final r in payload.rooms) {
      final isMyId = myUserId != null && myUserId!.isNotEmpty && r.hostId == myUserId;
      final isMyName = myUsername != null && myUsername!.isNotEmpty && r.hostName == myUsername;
      if (isMyId || isMyName) {
        myPublicRoom = r;
        break;
      }
    }

    if (myPublicRoom != null) {
      // Server confirms player has an active public room
      if (roomCode.value != myPublicRoom.roomCode) {
        roomCode.value = myPublicRoom.roomCode;
      }
      if (roomTimeControl != myPublicRoom.timeControl) {
        roomTimeControl = myPublicRoom.timeControl;
        timeControl = myPublicRoom.timeControl;
      }
      isRoomPrivate = false;
      if (matchState.value != OnlineMatchState.inRoom) {
        matchState.value = OnlineMatchState.inRoom;
      }
    } else {
      // No room hosted by this player exists in the active rooms list.
      // If we thought we had an open public room, it was cancelled, expired, or cleaned up.
      if (matchState.value == OnlineMatchState.inRoom && !isRoomPrivate) {
        roomCode.value = null;
        matchState.value = OnlineMatchState.idle;
      }
    }
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
