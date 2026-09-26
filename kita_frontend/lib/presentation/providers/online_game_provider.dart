import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import '../../core/feedback/sound_service.dart';
import '../../core/feedback/toast_service.dart';
import '../../data/models/game_models.dart';
import '../../data/models/kita_ai.dart';
import '../../data/models/match_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/ws_message_models.dart';
export '../../data/models/ws_message_models.dart' show OnlineMoveRecord, ChatMessage;
import '../../data/services/local_match_history_service.dart';
import '../../data/services/websocket_service.dart';

/// Represents whether the game is played offline vs AI, local pass & play, or online.
enum PlayMode { vsAi, localCoop }

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

  // ─── Pending Outgoing Friend Challenge ────────────────────────────
  final ValueNotifier<PendingOutgoingChallenge?> pendingOutgoingChallenge =
      ValueNotifier(null);

  // ─── Reconnection State ───────────────────────────────────────────
  final ValueNotifier<bool> isReconnectedMatch = ValueNotifier(false);

  // ─── Offline Match State ──────────────────────────────────────────

  bool isOffline = false;
  PlayMode offlinePlayMode = PlayMode.vsAi;
  int offlineBotDifficulty = 1; // 0: Easy, 1: Medium, 2: Hard
  PieceTeam offlinePlayerTeam = PieceTeam.white;
  String? offlinePlayerId;
  String? offlinePlayerName;
  int? offlinePlayerRating;
  bool offlineIsGuest = false;
  bool _offlineMatchSaved = false;
  bool? _localCoopIsHorizontal;
  final ValueNotifier<bool> isAiThinking = ValueNotifier(false);

  /// True: 7x4 horizontal layout, False: 4x7 vertical layout (default for Local Coop).
  bool get localCoopIsHorizontal => _localCoopIsHorizontal ?? false;

  void toggleLocalCoopOrientation() {
    _localCoopIsHorizontal = !localCoopIsHorizontal;
    notifyListeners();
  }

  /// Localized difficulty label for offline AI match (Easy, Medium, Hard).
  String get offlineBotDifficultyLabel {
    switch (offlineBotDifficulty) {
      case 0:
        return 'game.easy'.tr();
      case 2:
        return 'game.hard'.tr();
      case 1:
      default:
        return 'game.medium'.tr();
    }
  }

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
    _restoreActiveOfflineMatch();
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

  // ─── Offline Match Actions ────────────────────────────────────────

  /// Starts an offline match (either VS AI Bot or Local 2P Pass & Play).
  void startOfflineMatch({
    required PlayMode mode,
    PieceTeam playerTeam = PieceTeam.white,
    int botDifficulty = 1,
    String? playerId,
    String? playerName,
    int? playerRating,
    bool isGuest = false,
  }) {
    clearError();
    _stopClockTimer();
    isOffline = true;
    offlinePlayMode = mode;
    offlineBotDifficulty = botDifficulty;
    offlinePlayerTeam = playerTeam;
    offlinePlayerId = playerId ?? offlinePlayerId;
    offlinePlayerName = playerName ?? offlinePlayerName;
    offlinePlayerRating = playerRating ?? offlinePlayerRating;
    offlineIsGuest = isGuest;
    _offlineMatchSaved = false;
    _lastOfflineMatchRecord = null;
    myTeam = playerTeam.name;

    if (mode == PlayMode.vsAi) {
      final botRating = 1000 + botDifficulty * 200;
      opponentInfo = OpponentInfo(
        id: 'bot',
        name: 'game.aiBot'.tr(),
        rating: botRating,
        avatarIndex: 7,
      );
      matchId = 'offline-${DateTime.now().millisecondsSinceEpoch}';
    } else {
      _localCoopIsHorizontal = false; // Start in vertical board mode by default for Local Coop
      opponentInfo = OpponentInfo(
        id: 'local_player',
        name: playerTeam == PieceTeam.white ? 'game.playBlack'.tr() : 'game.playWhite'.tr(),
        rating: 1200,
        avatarIndex: 1,
      );
      matchId = 'offline-coop-${DateTime.now().millisecondsSinceEpoch}';
    }
    timeControl = 0;
    roomCode.value = null;
    isRoomPrivate = false;
    gameEngine.value = KitaGameEngine();
    _engineSnapshots.clear();
    _engineSnapshots.add(KitaGameEngine());
    legalMoves.value = gameEngine.value.getLegalMoves();
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
    pendingOutgoingChallenge.value = null;
    isReconnectedMatch.value = false;
    isAiThinking.value = false;
    currentTurn.value = 'white';
    whiteRemainingMs.value = 0;
    blackRemainingMs.value = 0;
    elapsedSeconds.value = 0;
    _matchStartedAt = DateTime.now();
    matchState.value = OnlineMatchState.inMatch;
    _startClockTimer();
    _persistActiveOfflineMatch();
    notifyListeners();

    // If human plays Black vs Bot, Bot is White and moves first!
    if (mode == PlayMode.vsAi && playerTeam == PieceTeam.black) {
      _triggerBotMove();
    }
  }

  /// Change offline bot difficulty during match
  void setOfflineBotDifficulty(int difficulty) {
    offlineBotDifficulty = difficulty;
    if (opponentInfo != null && offlinePlayMode == PlayMode.vsAi) {
      opponentInfo = OpponentInfo(
        id: 'bot',
        name: 'game.aiBot'.tr(),
        rating: 1000 + difficulty * 200,
        avatarIndex: 7,
      );
      notifyListeners();
    }
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

    if (isOffline) {
      _makeOfflineMove(move);
      return;
    }

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

  void _makeOfflineMove(KitaMove move) {
    if (isAiThinking.value) return;

    final engine = gameEngine.value;
    final legal = engine.getLegalMoves();
    final isValid = legal.any(
      (m) =>
          m.pieceId == move.pieceId &&
          m.fromPos == move.fromPos &&
          m.toPos == move.toPos,
    );
    if (!isValid) return;

    // Check if move is capturing opponent's king
    final oppKingId = engine.turn == PieceTeam.white ? 'BK' : 'WK';
    final oppKingPos = engine.positions[oppKingId];
    final isCapture = (oppKingPos != null && move.toPos == oppKingPos);

    if (isCapture) {
      SoundService.instance.playCapture();
    } else {
      SoundService.instance.playMove();
    }

    final nextEngine = engine.applyMove(move);
    lastMove.value = move;

    // Return to live if user was viewing previous moves
    if (viewingMoveIndex.value != -1) {
      viewingMoveIndex.value = -1;
    }

    final newHistory = List<OnlineMoveRecord>.from(moveHistory.value)
      ..add(
        OnlineMoveRecord(
          plyIndex: nextEngine.moveCount,
          pieceId: move.pieceId,
          fromCol: move.fromPos.col,
          fromRow: move.fromPos.row,
          toCol: move.toPos.col,
          toRow: move.toPos.row,
          playerTeam: move.pieceId.startsWith('W') ? 'white' : 'black',
        ),
      );
    moveHistory.value = newHistory;
    _engineSnapshots.add(nextEngine.clone());
    gameEngine.value = nextEngine;
    currentTurn.value = nextEngine.turn.name;

    if (nextEngine.hasKingRetaliation) {
      _handleOfflineKingRetaliation(nextEngine);
      return;
    }

    _checkOfflineGameOver(nextEngine);
  }

  Future<void> _handleOfflineKingRetaliation(KitaGameEngine currentEngine) async {
    final retaliationMove = currentEngine.getKingRetaliationMove();
    if (retaliationMove == null) {
      _checkOfflineGameOver(currentEngine);
      return;
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (matchState.value != OnlineMatchState.inMatch || !isOffline) return;

    SoundService.instance.playCapture();
    final retaliatedEngine = currentEngine.applyMove(retaliationMove);
    lastMove.value = retaliationMove;

    // Return to live if user was viewing previous moves
    if (viewingMoveIndex.value != -1) {
      viewingMoveIndex.value = -1;
    }

    final newHistory = List<OnlineMoveRecord>.from(moveHistory.value)
      ..add(
        OnlineMoveRecord(
          plyIndex: retaliatedEngine.moveCount,
          pieceId: retaliationMove.pieceId,
          fromCol: retaliationMove.fromPos.col,
          fromRow: retaliationMove.fromPos.row,
          toCol: retaliationMove.toPos.col,
          toRow: retaliationMove.toPos.row,
          playerTeam: retaliationMove.pieceId.startsWith('W') ? 'white' : 'black',
        ),
      );
    moveHistory.value = newHistory;
    _engineSnapshots.add(retaliatedEngine.clone());
    gameEngine.value = retaliatedEngine;
    currentTurn.value = retaliatedEngine.turn.name;

    _checkOfflineGameOver(retaliatedEngine);
  }

  void _checkOfflineGameOver(KitaGameEngine engine) {
    if (engine.isGameOver) {
      final status = engine.getStatus();
      String winnerTeam = 'draw';
      String result = 'draw';
      if (status == GameStatus.whiteWins) {
        winnerTeam = 'white';
        result = 'white_wins';
      } else if (status == GameStatus.blackWins) {
        winnerTeam = 'black';
        result = 'black_wins';
      }

      final reason = engine.getEndReason() == EndReason.kingCaptured
          ? 'checkmate'
          : (result == 'draw' ? 'draw_agreement' : 'normal');

      if (_matchStartedAt != null) {
        elapsedSeconds.value =
            DateTime.now().difference(_matchStartedAt!).inSeconds;
      }

      final payload = GameOverPayload(
        matchId: matchId ?? 'offline',
        winnerTeam: winnerTeam,
        result: result,
        reason: reason,
        ratingChanges: {},
      );

      gameOverData.value = payload;
      matchState.value = OnlineMatchState.gameOver;
      _stopClockTimer();
      SoundService.instance.playGameOver();
      _saveOfflineGameRecord(payload);
      _clearPersistedActiveOfflineMatch();
      notifyListeners();
      return;
    }

    legalMoves.value = engine.getLegalMoves();
    _persistActiveOfflineMatch();

    if (offlinePlayMode == PlayMode.vsAi && engine.turn != offlinePlayerTeam) {
      _triggerBotMove();
    }
  }

  Future<void> _triggerBotMove() async {
    final currentMatchId = matchId;
    isAiThinking.value = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));
    if (matchState.value != OnlineMatchState.inMatch || !isOffline || matchId != currentMatchId) {
      isAiThinking.value = false;
      notifyListeners();
      return;
    }

    final ai = KitaAI.instance;
    if (!ai.isInitialized) {
      await ai.initialize();
    }

    final diffIndex = offlineBotDifficulty.clamp(0, AIDifficulty.all.length - 1);
    final diff = AIDifficulty.all[diffIndex];
    final botMove = ai.chooseMove(
      gameEngine.value,
      depth: diff.depth,
      temperature: diff.temperature,
    );

    isAiThinking.value = false;
    notifyListeners();

    if (botMove != null && matchState.value == OnlineMatchState.inMatch && isOffline && matchId == currentMatchId) {
      _makeOfflineMove(botMove);
    }
  }

  void resign() {
    if (matchState.value != OnlineMatchState.inMatch) return;
    if (isOffline) {
      final winnerTeam = offlinePlayMode == PlayMode.localCoop
          ? (currentTurn.value == 'white' ? 'black' : 'white')
          : (myTeam == 'white' ? 'black' : 'white');
      final payload = GameOverPayload(
        matchId: matchId ?? 'offline',
        winnerTeam: winnerTeam,
        result: winnerTeam == 'white' ? 'white_wins' : 'black_wins',
        reason: 'resignation',
        ratingChanges: {},
      );
      if (_matchStartedAt != null) {
        elapsedSeconds.value =
            DateTime.now().difference(_matchStartedAt!).inSeconds;
      }
      gameOverData.value = payload;
      matchState.value = OnlineMatchState.gameOver;
      _stopClockTimer();
      SoundService.instance.playGameOver();
      _saveOfflineGameRecord(payload);
      _clearPersistedActiveOfflineMatch();
      notifyListeners();
      return;
    }
    _ws.send(WsClientType.resign);
  }

  /// Resigns/forfeits the match and immediately resets client state to idle.
  /// Used when dismissing an active game card from the dashboard or abandoning a defunct match.
  void resignAndClear() {
    if (matchState.value != OnlineMatchState.inMatch) {
      resetToIdle();
      return;
    }
    if (isOffline) {
      _clearPersistedActiveOfflineMatch();
      resign();
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

  MatchRecordModel? _lastOfflineMatchRecord;
  MatchRecordModel? get lastOfflineMatchRecord => _lastOfflineMatchRecord;

  MatchRecordModel? _createOfflineMatchRecord(GameOverPayload? payload) {
    if (!isOffline) return null;
    final isCoop = offlinePlayMode == PlayMode.localCoop;
    final isPlayerWhite = (offlinePlayerTeam == PieceTeam.white);

    final UserProfile whiteUser;
    final UserProfile blackUser;
    final String whitePlayerId;
    final String blackPlayerId;

    if (isCoop) {
      whitePlayerId = 'local_white';
      blackPlayerId = 'local_black';
      whiteUser = UserProfile(
        id: 'local_white',
        username: 'game.playWhite'.tr(),
        rating: 1200,
      );
      blackUser = UserProfile(
        id: 'local_black',
        username: 'game.playBlack'.tr(),
        rating: 1200,
      );
    } else {
      final botRating = 1000 + offlineBotDifficulty * 200;
      final botDifficultyNames = ['Easy', 'Medium', 'Hard'];
      final diffName = (offlineBotDifficulty >= 0 && offlineBotDifficulty <= 2)
          ? botDifficultyNames[offlineBotDifficulty]
          : 'Medium';
      final botUsername = 'AI Bot ($diffName)';

      final playerUser = UserProfile(
        id: offlinePlayerId ?? (offlineIsGuest ? 'guest' : 'local_player'),
        username: offlinePlayerName ?? (offlineIsGuest ? 'Guest' : 'Player'),
        rating: offlinePlayerRating ?? 1200,
      );

      final botUser = UserProfile(
        id: 'bot',
        username: botUsername,
        rating: botRating,
      );

      whitePlayerId = isPlayerWhite ? playerUser.id : 'bot';
      blackPlayerId = isPlayerWhite ? 'bot' : playerUser.id;
      whiteUser = isPlayerWhite ? playerUser : botUser;
      blackUser = isPlayerWhite ? botUser : playerUser;
    }

    String? winnerId;
    if (payload?.winnerTeam == 'white') {
      winnerId = whitePlayerId;
    } else if (payload?.winnerTeam == 'black') {
      winnerId = blackPlayerId;
    } else {
      winnerId = null;
    }

    final moveRecords = moveHistory.value.map((m) {
      final String pId;
      if (isCoop) {
        pId = m.playerTeam == 'white' ? 'local_white' : 'local_black';
      } else {
        final isPlayer = (m.playerTeam == (offlinePlayerTeam == PieceTeam.white ? 'white' : 'black'));
        pId = isPlayer ? (isPlayerWhite ? whitePlayerId : blackPlayerId) : 'bot';
      }
      return MoveRecordModel(
        ply: m.plyIndex,
        playerId: pId,
        piece: m.pieceId,
        fromCol: m.fromCol,
        fromRow: m.fromRow,
        toCol: m.toCol,
        toRow: m.toRow,
        timeMs: 0,
        createdAt: DateTime.now(),
      );
    }).toList();

    final record = MatchRecordModel(
      id: matchId ?? (isCoop ? 'offline-coop-${DateTime.now().millisecondsSinceEpoch}' : 'offline_${DateTime.now().millisecondsSinceEpoch}'),
      whitePlayerId: whitePlayerId,
      blackPlayerId: blackPlayerId,
      whitePlayer: whiteUser,
      blackPlayer: blackUser,
      winnerId: winnerId,
      result: payload?.result ?? 'in_progress',
      reason: payload?.reason,
      totalMoves: moveRecords.length,
      startedAt: _matchStartedAt ?? DateTime.now(),
      endedAt: DateTime.now(),
      moves: moveRecords,
      isOffline: true,
    );

    _lastOfflineMatchRecord = record;
    return record;
  }

  Future<void> _saveOfflineGameRecord(GameOverPayload payload) async {
    if (_offlineMatchSaved) return;
    if (!isOffline) return;
    if (moveHistory.value.length <= 1) return;
    _offlineMatchSaved = true;

    try {
      final record = _createOfflineMatchRecord(payload);
      if (record != null) {
        await LocalMatchHistoryService.instance.saveMatch(record);
      }
    } catch (e) {
      debugPrint('[OnlineGameProvider] Failed to save offline match: $e');
    }
  }

  MatchRecordModel? buildCurrentOfflineMatchRecord(GameOverPayload? payload) {
    return _createOfflineMatchRecord(payload);
  }

  // ─── Active Offline Match Persistence ──────────────────────────────

  Future<void> _persistActiveOfflineMatch() async {
    if (!isOffline || matchState.value != OnlineMatchState.inMatch || matchId == null) {
      return;
    }
    try {
      final data = ActiveOfflineGameData(
        matchId: matchId!,
        playMode: offlinePlayMode == PlayMode.localCoop ? 'localCoop' : 'vsAi',
        botDifficulty: offlineBotDifficulty,
        playerTeam: offlinePlayerTeam.name,
        playerId: offlinePlayerId,
        playerName: offlinePlayerName,
        playerRating: offlinePlayerRating,
        isGuest: offlineIsGuest,
        elapsedSeconds: elapsedSeconds.value,
        moveHistory: moveHistory.value.map((m) => m.toJson()).toList(),
        startedAt: _matchStartedAt ?? DateTime.now(),
      );
      await LocalMatchHistoryService.instance.saveActiveOfflineGame(data);
    } catch (e) {
      debugPrint('[OnlineGame] Error persisting active offline match: $e');
    }
  }

  Future<void> _clearPersistedActiveOfflineMatch() async {
    try {
      await LocalMatchHistoryService.instance.clearActiveOfflineGame();
    } catch (e) {
      debugPrint('[OnlineGame] Error clearing active offline match: $e');
    }
  }

  Future<void> _restoreActiveOfflineMatch() async {
    try {
      final saved = await LocalMatchHistoryService.instance.getActiveOfflineGame();
      if (saved == null) return;

      // Don't overwrite if an online activity is already in progress
      if (matchState.value != OnlineMatchState.idle) return;

      isOffline = true;
      offlinePlayMode = saved.playMode == 'localCoop' ? PlayMode.localCoop : PlayMode.vsAi;
      offlineBotDifficulty = saved.botDifficulty;
      offlinePlayerTeam = saved.playerTeam == 'black' ? PieceTeam.black : PieceTeam.white;
      offlinePlayerId = saved.playerId;
      offlinePlayerName = saved.playerName;
      offlinePlayerRating = saved.playerRating;
      offlineIsGuest = saved.isGuest;
      _offlineMatchSaved = false;
      _lastOfflineMatchRecord = null;
      myTeam = offlinePlayerTeam.name;

      if (offlinePlayMode == PlayMode.vsAi) {
        final botRating = 1000 + offlineBotDifficulty * 200;
        opponentInfo = OpponentInfo(
          id: 'bot',
          name: 'game.aiBot'.tr(),
          rating: botRating,
          avatarIndex: 7,
        );
      } else {
        opponentInfo = OpponentInfo(
          id: 'local_player',
          name: offlinePlayerTeam == PieceTeam.white ? 'game.playBlack'.tr() : 'game.playWhite'.tr(),
          rating: 1200,
          avatarIndex: 1,
        );
      }

      matchId = saved.matchId;
      timeControl = 0;
      roomCode.value = null;
      isRoomPrivate = false;

      // Reconstruct game engine & snapshots by sequentially applying the moves
      var engine = KitaGameEngine();
      _engineSnapshots.clear();
      _engineSnapshots.add(engine.clone());

      final moves = saved.moveHistory.map((m) => OnlineMoveRecord.fromJson(m)).toList();
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
      chatMessages.value = [];
      unreadChatCount.value = 0;
      isChatOpen = true;
      gameOverData.value = null;
      rematchOffer.value = null;
      matchInvitation.value = null;
      incomingMatchRequest.value = null;
      isRematchRequested.value = false;
      isGameOverDialogActive.value = false;
      pendingOutgoingChallenge.value = null;
      isReconnectedMatch.value = false;
      isAiThinking.value = false;
      currentTurn.value = engine.turn.name;
      whiteRemainingMs.value = 0;
      blackRemainingMs.value = 0;
      elapsedSeconds.value = saved.elapsedSeconds;
      _matchStartedAt = saved.startedAt;

      // Safety check: if reconstructed engine is already over, clear and abort
      if (engine.isGameOver) {
        await LocalMatchHistoryService.instance.clearActiveOfflineGame();
        resetToIdle();
        return;
      }

      legalMoves.value = engine.getLegalMoves();
      matchState.value = OnlineMatchState.inMatch;
      _startClockTimer();
      notifyListeners();

      // If it was the AI's turn when the app was closed, resume AI thinking
      if (offlinePlayMode == PlayMode.vsAi && engine.turn != offlinePlayerTeam) {
        _triggerBotMove();
      }
    } catch (e) {
      debugPrint('[OnlineGame] Error restoring active offline match: $e');
    }
  }

  void sendChat(String content) {
    if (content.trim().isEmpty) return;
    if (content.length > 200) content = content.substring(0, 200);
    _ws.send(WsClientType.chatMessage, {'content': content.trim()});
  }

  // ─── Rematch ──────────────────────────────────────────────────────

  void requestRematch() {
    if (isOffline) {
      startOfflineMatch(
        mode: offlinePlayMode,
        playerTeam: offlinePlayerTeam,
        botDifficulty: offlineBotDifficulty,
        playerId: offlinePlayerId,
        playerName: offlinePlayerName,
        playerRating: offlinePlayerRating,
        isGuest: offlineIsGuest,
      );
      return;
    }
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

  void inviteToMatch(
    String friendId, {
    String? friendName,
    int? friendRating,
    int timeControl = 180000,
    String colorPreference = 'random',
  }) {
    pendingOutgoingChallenge.value = PendingOutgoingChallenge(
      friendId: friendId,
      friendName: friendName ?? 'Friend',
      friendRating: friendRating,
      timeControl: timeControl,
      colorPreference: colorPreference,
      sentAt: DateTime.now(),
    );
    _ws.send(WsClientType.inviteToMatch, {
      'friend_id': friendId,
      'time_control': timeControl,
      'color_preference': colorPreference,
    });
    notifyListeners();
  }

  void cancelOutgoingChallenge() {
    final pending = pendingOutgoingChallenge.value;
    if (pending != null) {
      _ws.send(WsClientType.cancelInvitation, {
        'friend_id': pending.friendId,
        if (pending.inviteId != null && pending.inviteId!.isNotEmpty)
          'invite_id': pending.inviteId,
      });
      pendingOutgoingChallenge.value = null;
      notifyListeners();
    }
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
        }
        notifyListeners();

      case WsServerType.roomJoined:
        if (matchState.value != OnlineMatchState.inMatch) {
          matchState.value = OnlineMatchState.inRoom;
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

      case WsServerType.matchInvitationSent:
        final sentInviteId = msg.payload?['invite_id'] as String?;
        if (sentInviteId != null && pendingOutgoingChallenge.value != null) {
          pendingOutgoingChallenge.value = pendingOutgoingChallenge.value!.copyWith(
            inviteId: sentInviteId,
          );
          notifyListeners();
        }
        KitaToast.success('online.inviteSent'.tr());


      case WsServerType.matchInvitation:
        if (msg.payload != null) {
          final payload = MatchInvitationPayload.fromJson(msg.payload!);
          matchInvitation.value = payload;
          incomingMatchRequest.value = IncomingMatchRequest(
            type: IncomingMatchRequestType.friendInvite,
            id: payload.inviteId,
            senderId: payload.inviterId,
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
        pendingOutgoingChallenge.value = null;
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
        if (pendingOutgoingChallenge.value != null &&
            (cancelledInviteId == null ||
                pendingOutgoingChallenge.value?.inviteId == cancelledInviteId)) {
          pendingOutgoingChallenge.value = null;
          if (cancelReason == 'timeout') {
            KitaToast.info('online.inviteTimeout'.tr());
          }
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
    pendingOutgoingChallenge.value = null;
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
    drawOffer.value = null;
    isDrawOfferPending.value = false;
    _stopClockTimer();
    SoundService.instance.playGameOver();
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

  void _handleError(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final error = WsErrorPayload.fromJson(payload);
    debugPrint('[OnlineGame] WS Error: ${error.code} - ${error.message}');
    lastError.value = error;
    pendingOutgoingChallenge.value = null;
    notifyListeners();

    final isMatchNotFound = error.code == 'ERR_MATCH_NOT_FOUND' ||
        error.message.toLowerCase().contains('match not found') ||
        error.message.toLowerCase().contains('no active match');

    if (isMatchNotFound) {
      if (matchState.value == OnlineMatchState.inMatch ||
          matchState.value == OnlineMatchState.inRoom) {
        debugPrint(
          '[OnlineGame] Server indicated match/room not found. Resetting state to idle.',
        );
        resetToIdle();
      }
      KitaToast.info('online.matchNotFoundOrClosed'.tr());
      return;
    }

    String message;
    if (error.code == 'ERR_PLAYER_OFFLINE' ||
        error.message.toLowerCase().contains('not online')) {
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
    if (isOffline) {
      _clearPersistedActiveOfflineMatch();
    }
    isOffline = false;
    offlinePlayerId = null;
    offlinePlayerName = null;
    offlinePlayerRating = null;
    offlineIsGuest = false;
    _offlineMatchSaved = false;
    isAiThinking.value = false;
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
    pendingOutgoingChallenge.value = null;
    isReconnectedMatch.value = false;
    elapsedSeconds.value = 0;
    whiteRemainingMs.value = 0;
    blackRemainingMs.value = 0;
    if (isOffline) {
      _clearPersistedActiveOfflineMatch();
    }
    isOffline = false;
    offlinePlayerId = null;
    offlinePlayerName = null;
    offlinePlayerRating = null;
    offlineIsGuest = false;
    _offlineMatchSaved = false;
    isAiThinking.value = false;
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
    isAiThinking.dispose();
    super.dispose();
  }
}
