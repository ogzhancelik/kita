import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import '../../core/feedback/haptic_service.dart';
import '../../core/feedback/sound_service.dart';
import '../../data/models/game_models.dart';
import '../../data/models/kita_ai.dart';
import '../../data/models/match_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/ws_message_models.dart';
import '../../data/services/local_match_history_service.dart';
import 'online_game_provider.dart';

/// Provider dedicated exclusively to offline matches (VS AI Bot & Local Co-op Pass & Play).
///
/// Completely decoupled from online multiplayer state:
/// - Survives independently of WebSocket connections, matchmaking queues, or online matches.
/// - Persisted locally via [LocalMatchHistoryService].
/// - Allows the user to have an active offline match and an active online match simultaneously.
class OfflineGameProvider extends ChangeNotifier {
  PlayMode offlinePlayMode = PlayMode.vsAi;
  int offlineBotDifficulty = 1; // 0: Novice, 1: Easy (Beginner), 2: Medium (Intermediate), 3: Master, 4: Grandmaster
  PieceTeam offlinePlayerTeam = PieceTeam.white;
  String? offlinePlayerId;
  String? offlinePlayerName;
  int? offlinePlayerRating;
  int? offlinePlayerAvatarIndex;
  bool offlineIsGuest = false;
  String? offlineOpponentName;
  int? offlineOpponentAvatarIndex;
  bool _offlineMatchSaved = false;
  bool? _localCoopIsHorizontal;
  bool _hasActiveMatch = false;
  bool _isDisposed = false;

  OpponentInfo? opponentInfo;
  String? matchId;
  DateTime? _matchStartedAt;
  Timer? _clockTimer;
  bool _isClockRunning = false;
  bool _isInGameScreen = false;
  int _accumulatedElapsedMs = 0;
  DateTime? _activeSessionStartedAt;

  bool get isClockRunning => _isClockRunning;
  bool get isInGameScreen => _isInGameScreen;

  // ─── Game Engine & Move History ──────────────────────────────────
  final ValueNotifier<KitaGameEngine> gameEngine = ValueNotifier(KitaGameEngine());
  final ValueNotifier<List<KitaMove>> legalMoves = ValueNotifier([]);
  final ValueNotifier<KitaMove?> lastMove = ValueNotifier(null);
  final ValueNotifier<List<OnlineMoveRecord>> moveHistory = ValueNotifier([]);
  final ValueNotifier<int> viewingMoveIndex = ValueNotifier(-1);
  final List<KitaGameEngine> _engineSnapshots = [];

  // ─── Time Control & Clocks ───────────────────────────────────────
  int timeControl = 0; // 0 = unlimited, otherwise duration in ms
  final ValueNotifier<int> whiteRemainingMs = ValueNotifier(0);
  final ValueNotifier<int> blackRemainingMs = ValueNotifier(0);
  DateTime? _turnStartedAt;
  int _turnBaseRemainingMs = 0;
  bool _lowTimeAlertPlayed = false;

  final ValueNotifier<String> currentTurn = ValueNotifier('white');
  final ValueNotifier<int> elapsedSeconds = ValueNotifier(0);
  final ValueNotifier<bool> isAiThinking = ValueNotifier(false);
  final ValueNotifier<GameOverPayload?> gameOverData = ValueNotifier(null);
  final ValueNotifier<bool> isGameOverDialogActive = ValueNotifier(false);
  final ValueNotifier<OnlineMatchState> matchState = ValueNotifier(OnlineMatchState.idle);

  MatchRecordModel? _lastOfflineMatchRecord;
  MatchRecordModel? get lastOfflineMatchRecord => _lastOfflineMatchRecord;

  bool get hasActiveMatch => _hasActiveMatch && gameOverData.value == null;
  bool get isGameOver => gameOverData.value != null;
  bool get isViewingHistory => viewingMoveIndex.value != -1;
  bool get localCoopIsHorizontal => _localCoopIsHorizontal ?? false;
  String get myTeam => offlinePlayerTeam.name;
  bool get isOffline => true;

  /// Returns the current board engine snapshot to display (live or historical).
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

  String get offlineBotDifficultyLabel {
    switch (offlineBotDifficulty) {
      case 0:
        return 'game.novice'.tr();
      case 2:
        return 'game.medium'.tr();
      case 3:
        return 'game.hard'.tr();
      case 4:
        return 'game.grandmaster'.tr();
      case 1:
      default:
        return 'game.easy'.tr();
    }
  }

  OfflineGameProvider() {
    _restoreActiveOfflineMatch();
  }

  void toggleLocalCoopOrientation() {
    _localCoopIsHorizontal = !localCoopIsHorizontal;
    notifyListeners();
  }

  void setOfflineBotDifficulty(int difficulty) {
    offlineBotDifficulty = difficulty;
    if (opponentInfo != null && offlinePlayMode == PlayMode.vsAi) {
      opponentInfo = OpponentInfo(
        id: 'bot',
        name: 'game.aiBot'.tr(),
        rating: AIDifficulty.getRatingForDifficulty(difficulty),
        avatarIndex: 7,
      );
      notifyListeners();
    }
  }

  // ─── Match Lifecycle ──────────────────────────────────────────────

  /// Starts an offline match (either VS AI Bot or Local 2P Pass & Play).
  void startOfflineMatch({
    required PlayMode mode,
    PieceTeam playerTeam = PieceTeam.white,
    int botDifficulty = 1,
    String? playerId,
    String? playerName,
    int? playerRating,
    int? playerAvatarIndex,
    bool isGuest = false,
    String? opponentName,
    int? opponentAvatarIndex,
    int timeControl = 0,
    bool? initialIsHorizontal,
    KitaGameEngine? initialEngine,
  }) {
    _stopClockTimer();
    _isClockRunning = false;
    _hasActiveMatch = true;
    offlinePlayMode = mode;
    offlineBotDifficulty = botDifficulty;
    offlinePlayerTeam = playerTeam;
    offlinePlayerId = isGuest ? null : (playerId ?? offlinePlayerId);
    offlinePlayerName = playerName ?? (isGuest ? 'Guest' : offlinePlayerName);
    offlinePlayerRating = playerRating ?? offlinePlayerRating;
    offlinePlayerAvatarIndex = playerAvatarIndex ?? offlinePlayerAvatarIndex;
    offlineIsGuest = isGuest;
    offlineOpponentName = opponentName ?? offlineOpponentName;
    offlineOpponentAvatarIndex = opponentAvatarIndex ?? offlineOpponentAvatarIndex;
    this.timeControl = timeControl;
    _offlineMatchSaved = false;
    _lastOfflineMatchRecord = null;
    _accumulatedElapsedMs = 0;
    _activeSessionStartedAt = null;

    if (mode == PlayMode.vsAi) {
      final botRating = AIDifficulty.getRatingForDifficulty(botDifficulty);
      opponentInfo = OpponentInfo(
        id: 'bot',
        name: 'game.aiBot'.tr(),
        rating: botRating,
        avatarIndex: 7,
      );
      matchId = 'offline-${DateTime.now().millisecondsSinceEpoch}';
    } else {
      _localCoopIsHorizontal = initialIsHorizontal ?? false;
      final defaultP2 = 'game.player2'.tr();
      final p2DisplayName = (opponentName != null && opponentName.trim().isNotEmpty)
          ? opponentName.trim()
          : (offlineOpponentName != null && offlineOpponentName!.trim().isNotEmpty
              ? offlineOpponentName!.trim()
              : defaultP2);
      offlineOpponentName = p2DisplayName;
      offlineOpponentAvatarIndex = opponentAvatarIndex ?? (offlineOpponentAvatarIndex ?? 1);

      opponentInfo = OpponentInfo(
        id: 'local_p2',
        name: p2DisplayName,
        rating: 1200,
        avatarIndex: offlineOpponentAvatarIndex ?? 1,
      );
      matchId = 'offline-coop-${DateTime.now().millisecondsSinceEpoch}';
    }

    final startingEngine = initialEngine ?? KitaGameEngine();
    gameEngine.value = startingEngine;
    _engineSnapshots.clear();
    _engineSnapshots.add(startingEngine.clone());
    legalMoves.value = startingEngine.getLegalMoves();
    lastMove.value = startingEngine.mostRecentMove;
    moveHistory.value = [];
    viewingMoveIndex.value = -1;
    gameOverData.value = null;
    isGameOverDialogActive.value = false;
    isAiThinking.value = false;
    currentTurn.value = startingEngine.turn.name;
    elapsedSeconds.value = 0;
    _matchStartedAt = DateTime.now();

    if (timeControl > 0) {
      whiteRemainingMs.value = timeControl;
      blackRemainingMs.value = timeControl;
      _turnStartedAt = null;
      _turnBaseRemainingMs = timeControl;
      _lowTimeAlertPlayed = false;
    } else {
      whiteRemainingMs.value = 0;
      blackRemainingMs.value = 0;
      _turnStartedAt = null;
      _turnBaseRemainingMs = 0;
      _lowTimeAlertPlayed = false;
    }

    matchState.value = OnlineMatchState.inMatch;
    _persistActiveOfflineMatch();

    if (_isInGameScreen) {
      resumeGameClock();
    } else {
      notifyListeners();
    }
  }

  // ─── Game Moves ───────────────────────────────────────────────────

  void makeMove(KitaMove move) {
    if (!hasActiveMatch) return;
    if (isViewingHistory) return;
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

    final isCapture = engine.activePositions.values.contains(move.toPos);
    if (isCapture) {
      SoundService.instance.playCapture();
      HapticService.instance.medium();
    } else {
      SoundService.instance.playMove();
      HapticService.instance.light();
    }

    final nextEngine = engine.applyMove(move);
    lastMove.value = move;

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

    if (timeControl > 0) {
      _turnStartedAt = _isClockRunning ? DateTime.now() : null;
      _turnBaseRemainingMs = nextEngine.turn.name == 'white'
          ? whiteRemainingMs.value
          : blackRemainingMs.value;
      _lowTimeAlertPlayed = false;
    }

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
    if (!hasActiveMatch) return;

    SoundService.instance.playCapture();
    HapticService.instance.medium();
    final retaliatedEngine = currentEngine.applyMove(retaliationMove);
    lastMove.value = retaliationMove;

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

    if (timeControl > 0) {
      _turnStartedAt = _isClockRunning ? DateTime.now() : null;
      _turnBaseRemainingMs = retaliatedEngine.turn.name == 'white'
          ? whiteRemainingMs.value
          : blackRemainingMs.value;
      _lowTimeAlertPlayed = false;
    }

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

      final endReason = engine.getEndReason();
      final String reason;
      switch (endReason) {
        case EndReason.kingCaptured:
          reason = 'king_captured';
          break;
        case EndReason.noMovesLeft:
          reason = 'no_moves_left';
          break;
        case EndReason.doubleKingCaptured:
          reason = 'double_king_captured';
          break;
        case EndReason.threefoldRepetition:
          reason = 'threefold_repetition';
          break;
        default:
          reason = 'normal';
      }

      if (_activeSessionStartedAt != null) {
        _accumulatedElapsedMs +=
            DateTime.now().difference(_activeSessionStartedAt!).inMilliseconds;
        _activeSessionStartedAt = null;
      }
      elapsedSeconds.value = _accumulatedElapsedMs ~/ 1000;

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
      _isClockRunning = false;
      SoundService.instance.playGameOver();
      HapticService.instance.heavy();
      _saveOfflineGameRecord(payload);
      _clearPersistedActiveOfflineMatch();
      notifyListeners();
      return;
    }

    legalMoves.value = engine.getLegalMoves();
    _persistActiveOfflineMatch();

    if (offlinePlayMode == PlayMode.vsAi && engine.turn != offlinePlayerTeam) {
      if (_isInGameScreen && _isClockRunning) {
        _triggerBotMove();
      }
    }
  }

  Future<void> _triggerBotMove({Duration delay = const Duration(milliseconds: 400)}) async {
    final currentMatchId = matchId;
    isAiThinking.value = true;
    notifyListeners();

    await Future.delayed(delay);
    if (_isDisposed || !hasActiveMatch || matchId != currentMatchId) {
      if (!_isDisposed) {
        isAiThinking.value = false;
        notifyListeners();
      }
      return;
    }

    if (!_isClockRunning || !_isInGameScreen) {
      isAiThinking.value = false;
      notifyListeners();
      return;
    }

    final ai = KitaAI.instance;
    if (!ai.isInitialized) {
      await ai.initialize();
    }
    if (_isDisposed || !_isClockRunning || !_isInGameScreen) {
      isAiThinking.value = false;
      notifyListeners();
      return;
    }

    final diffIndex = offlineBotDifficulty.clamp(0, AIDifficulty.all.length - 1);
    final diff = AIDifficulty.all[diffIndex];
    final botMove = ai.chooseMoveWithDifficulty(
      gameEngine.value,
      diff,
    );

    if (_isDisposed) return;
    isAiThinking.value = false;
    notifyListeners();

    if (botMove != null && hasActiveMatch && matchId == currentMatchId && _isClockRunning && _isInGameScreen) {
      makeMove(botMove);
    }
  }

  // ─── Resignation & Reset ──────────────────────────────────────────

  void resign() {
    if (!hasActiveMatch) return;
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
    if (_activeSessionStartedAt != null) {
      _accumulatedElapsedMs +=
          DateTime.now().difference(_activeSessionStartedAt!).inMilliseconds;
      _activeSessionStartedAt = null;
    }
    elapsedSeconds.value = _accumulatedElapsedMs ~/ 1000;
    gameOverData.value = payload;
    matchState.value = OnlineMatchState.gameOver;
    _stopClockTimer();
    _isClockRunning = false;
    SoundService.instance.playGameOver();
    HapticService.instance.heavy();
    _saveOfflineGameRecord(payload);
    _clearPersistedActiveOfflineMatch();
    notifyListeners();
  }

  /// Immediately abandons and clears the active offline match.
  void resignAndClear() {
    _stopClockTimer();
    _isClockRunning = false;
    _clearPersistedActiveOfflineMatch();
    _hasActiveMatch = false;
    matchState.value = OnlineMatchState.idle;
    isAiThinking.value = false;
    _engineSnapshots.clear();
    _matchStartedAt = null;
    _activeSessionStartedAt = null;
    _accumulatedElapsedMs = 0;
    elapsedSeconds.value = 0;
    gameOverData.value = null;
    lastMove.value = null;
    moveHistory.value = [];
    viewingMoveIndex.value = -1;
    notifyListeners();
  }

  void requestRematch() {
    final newPlayerTeam = offlinePlayerTeam == PieceTeam.white
        ? PieceTeam.black
        : PieceTeam.white;
    startOfflineMatch(
      mode: offlinePlayMode,
      playerTeam: newPlayerTeam,
      botDifficulty: offlineBotDifficulty,
      playerId: offlinePlayerId,
      playerName: offlinePlayerName,
      playerRating: offlinePlayerRating,
      playerAvatarIndex: offlinePlayerAvatarIndex,
      isGuest: offlineIsGuest,
      opponentName: offlineOpponentName,
      opponentAvatarIndex: offlineOpponentAvatarIndex,
      timeControl: timeControl,
      initialIsHorizontal: _localCoopIsHorizontal,
    );
  }

  // ─── Move History Scrubbing ───────────────────────────────────────

  void viewMoveAt(int index) {
    if (index < 0 || index >= _engineSnapshots.length - 1) {
      goLive();
      return;
    }
    viewingMoveIndex.value = index;
    if (index > 0 && index - 1 < moveHistory.value.length) {
      final rec = moveHistory.value[index - 1];
      lastMove.value = KitaMove(
        pieceId: rec.pieceId,
        fromPos: KitaPos(rec.fromCol, rec.fromRow),
        toPos: KitaPos(rec.toCol, rec.toRow),
      );
    } else {
      lastMove.value = null;
    }
    notifyListeners();
  }

  void goLive() {
    viewingMoveIndex.value = -1;
    if (moveHistory.value.isNotEmpty) {
      final rec = moveHistory.value.last;
      lastMove.value = KitaMove(
        pieceId: rec.pieceId,
        fromPos: KitaPos(rec.fromCol, rec.fromRow),
        toPos: KitaPos(rec.toCol, rec.toRow),
      );
    } else {
      lastMove.value = null;
    }
    notifyListeners();
  }

  // Aliases for compatibility
  void viewMove(int index) {
    viewMoveAt(index >= 0 && index < moveHistory.value.length ? index + 1 : index);
  }

  void viewLive() => goLive();

  bool get canStepBackward {
    if (_engineSnapshots.length <= 1) return false;
    if (viewingMoveIndex.value == -1) return true;
    return viewingMoveIndex.value > 0;
  }

  bool get canStepForward {
    if (_engineSnapshots.length <= 1) return false;
    return viewingMoveIndex.value >= 0;
  }

  void stepBackward() {
    if (!canStepBackward) return;
    final current = viewingMoveIndex.value;
    if (current == -1) {
      if (_engineSnapshots.length > 1) {
        viewMoveAt(_engineSnapshots.length - 2);
      }
    } else if (current > 0) {
      viewMoveAt(current - 1);
    }
  }

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

  // ─── Match Record & Persistence ───────────────────────────────────

  MatchRecordModel? _createOfflineMatchRecord(GameOverPayload? payload) {
    final isCoop = offlinePlayMode == PlayMode.localCoop;
    final isPlayerWhite = (offlinePlayerTeam == PieceTeam.white);

    final UserProfile whiteUser;
    final UserProfile blackUser;
    final String whitePlayerId;
    final String blackPlayerId;

    if (isCoop) {
      final p1Name = offlinePlayerName ?? (offlineIsGuest ? 'Guest' : 'game.player1'.tr());
      final p2Name = opponentInfo?.name ?? (offlineOpponentName ?? 'game.player2'.tr());

      final p1User = UserProfile(
        id: offlinePlayerId ?? (offlineIsGuest ? 'guest' : 'local_p1'),
        username: p1Name,
        rating: offlinePlayerRating ?? 1200,
        avatarIndex: offlinePlayerAvatarIndex ?? 0,
      );
      final p2User = UserProfile(
        id: 'local_p2',
        username: p2Name,
        rating: 1200,
        avatarIndex: opponentInfo?.avatarIndex ?? (offlineOpponentAvatarIndex ?? 1),
      );

      whitePlayerId = isPlayerWhite ? p1User.id : p2User.id;
      blackPlayerId = isPlayerWhite ? p2User.id : p1User.id;
      whiteUser = isPlayerWhite ? p1User : p2User;
      blackUser = isPlayerWhite ? p2User : p1User;
    } else {
      final botRating = AIDifficulty.getRatingForDifficulty(offlineBotDifficulty);
      final botUsername = 'game.aiBot'.tr();

      final playerUser = UserProfile(
        id: offlinePlayerId ?? (offlineIsGuest ? 'guest' : 'local_player'),
        username: offlinePlayerName ?? (offlineIsGuest ? 'Guest' : 'Player'),
        rating: offlinePlayerRating ?? 1200,
        avatarIndex: offlinePlayerAvatarIndex ?? 0,
      );

      final botUser = UserProfile(
        id: 'bot',
        username: botUsername,
        rating: botRating,
        avatarIndex: 7,
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
    if (moveHistory.value.length <= 1) return;
    _offlineMatchSaved = true;

    try {
      final record = _createOfflineMatchRecord(payload);
      if (record != null) {
        await LocalMatchHistoryService.instance.saveMatch(
          record,
          userId: offlinePlayerId,
          isGuest: offlineIsGuest,
        );
      }
    } catch (e) {
      debugPrint('[OfflineGameProvider] Failed to save offline match: $e');
    }
  }

  MatchRecordModel? buildCurrentOfflineMatchRecord(GameOverPayload? payload) {
    return _createOfflineMatchRecord(payload);
  }

  Future<void> _persistActiveOfflineMatch() async {
    if (!hasActiveMatch || matchId == null) return;
    try {
      final currentElapsed = _isClockRunning && _activeSessionStartedAt != null
          ? (_accumulatedElapsedMs +
                  DateTime.now().difference(_activeSessionStartedAt!).inMilliseconds) ~/
              1000
          : elapsedSeconds.value;

      final data = ActiveOfflineGameData(
        matchId: matchId!,
        playMode: offlinePlayMode == PlayMode.localCoop ? 'localCoop' : 'vsAi',
        botDifficulty: offlineBotDifficulty,
        playerTeam: offlinePlayerTeam.name,
        playerId: offlinePlayerId,
        playerName: offlinePlayerName,
        playerRating: offlinePlayerRating,
        playerAvatarIndex: offlinePlayerAvatarIndex,
        isGuest: offlineIsGuest,
        opponentName: offlineOpponentName,
        opponentAvatarIndex: offlineOpponentAvatarIndex,
        elapsedSeconds: currentElapsed,
        moveHistory: moveHistory.value.map((m) => m.toJson()).toList(),
        startedAt: _matchStartedAt ?? DateTime.now(),
        timeControl: timeControl,
        whiteRemainingMs: whiteRemainingMs.value,
        blackRemainingMs: blackRemainingMs.value,
      );
      await LocalMatchHistoryService.instance.saveActiveOfflineGame(
        data,
        userId: offlinePlayerId,
        isGuest: offlineIsGuest,
      );
    } catch (e) {
      debugPrint('[OfflineGameProvider] Error persisting active offline match: $e');
    }
  }

  Future<void> _clearPersistedActiveOfflineMatch() async {
    try {
      await LocalMatchHistoryService.instance.clearActiveOfflineGame(
        userId: offlinePlayerId,
        isGuest: offlineIsGuest,
      );
    } catch (e) {
      debugPrint('[OfflineGameProvider] Error clearing active offline match: $e');
    }
  }

  Future<void> _restoreActiveOfflineMatch({String? userId, bool? isGuest}) async {
    try {
      final saved = await LocalMatchHistoryService.instance.getActiveOfflineGame(
        userId: userId ?? offlinePlayerId,
        isGuest: isGuest ?? offlineIsGuest,
      );
      if (_isDisposed || saved == null) return;

      _hasActiveMatch = true;
      offlinePlayMode = saved.playMode == 'localCoop' ? PlayMode.localCoop : PlayMode.vsAi;
      offlineBotDifficulty = saved.botDifficulty;
      offlinePlayerTeam = saved.playerTeam == 'black' ? PieceTeam.black : PieceTeam.white;
      offlinePlayerId = saved.playerId;
      offlinePlayerName = saved.playerName;
      offlinePlayerRating = saved.playerRating;
      offlinePlayerAvatarIndex = saved.playerAvatarIndex;
      offlineIsGuest = saved.isGuest;
      offlineOpponentName = saved.opponentName;
      offlineOpponentAvatarIndex = saved.opponentAvatarIndex;
      _offlineMatchSaved = false;
      _lastOfflineMatchRecord = null;

      if (offlinePlayMode == PlayMode.vsAi) {
        final botRating = AIDifficulty.getRatingForDifficulty(offlineBotDifficulty);
        opponentInfo = OpponentInfo(
          id: 'bot',
          name: 'game.aiBot'.tr(),
          rating: botRating,
          avatarIndex: 7,
        );
      } else {
        final p2Name = (saved.opponentName != null && saved.opponentName!.trim().isNotEmpty)
            ? saved.opponentName!.trim()
            : 'game.player2'.tr();
        opponentInfo = OpponentInfo(
          id: 'local_p2',
          name: p2Name,
          rating: 1200,
          avatarIndex: saved.opponentAvatarIndex ?? 1,
        );
      }

      matchId = saved.matchId;

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
      gameOverData.value = null;
      isGameOverDialogActive.value = false;
      isAiThinking.value = false;
      currentTurn.value = engine.turn.name;
      _accumulatedElapsedMs = saved.elapsedSeconds * 1000;
      elapsedSeconds.value = saved.elapsedSeconds;
      _activeSessionStartedAt = null;
      _matchStartedAt = saved.startedAt;
      timeControl = saved.timeControl;
      whiteRemainingMs.value = saved.whiteRemainingMs;
      blackRemainingMs.value = saved.blackRemainingMs;
      _turnStartedAt = null;
      _turnBaseRemainingMs = engine.turn.name == 'white'
          ? saved.whiteRemainingMs
          : saved.blackRemainingMs;

      if (engine.isGameOver) {
        await LocalMatchHistoryService.instance.clearActiveOfflineGame();
        _hasActiveMatch = false;
        notifyListeners();
        return;
      }

      legalMoves.value = engine.getLegalMoves();
      matchState.value = OnlineMatchState.inMatch;

      // Do NOT start timer on restore if the player is not currently in the game screen
      if (_isInGameScreen) {
        resumeGameClock();
      } else {
        _isClockRunning = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[OfflineGameProvider] Error restoring active offline match: $e');
    }
  }

  void setInGameScreen(bool inGame) {
    _isInGameScreen = inGame;
    if (inGame) {
      resumeGameClock();
    } else {
      pauseGameClock();
    }
  }

  void resumeGameClock() {
    if (!hasActiveMatch || isGameOver || _isDisposed) return;
    if (_isClockRunning) return;

    _isClockRunning = true;
    _activeSessionStartedAt = DateTime.now();

    if (timeControl > 0) {
      _turnStartedAt = DateTime.now();
      _turnBaseRemainingMs = currentTurn.value == 'white'
          ? whiteRemainingMs.value
          : blackRemainingMs.value;
    }

    _startClockTimer();

    // If human plays vs Bot and it is bot's turn:
    if (offlinePlayMode == PlayMode.vsAi &&
        gameEngine.value.turn != offlinePlayerTeam &&
        !isAiThinking.value) {
      _triggerBotMove(
        delay: gameEngine.value.moveCount == 0
            ? const Duration(milliseconds: 1000)
            : const Duration(milliseconds: 400),
      );
    }

    notifyListeners();
  }

  void pauseGameClock() {
    if (!_isClockRunning && _clockTimer == null) return;
    _isClockRunning = false;
    _stopClockTimer();

    if (_activeSessionStartedAt != null) {
      _accumulatedElapsedMs +=
          DateTime.now().difference(_activeSessionStartedAt!).inMilliseconds;
      _activeSessionStartedAt = null;
      elapsedSeconds.value = _accumulatedElapsedMs ~/ 1000;
    }

    if (timeControl > 0 && _turnStartedAt != null) {
      final elapsedTurnMs =
          DateTime.now().difference(_turnStartedAt!).inMilliseconds;
      final remaining = _turnBaseRemainingMs - elapsedTurnMs;
      final clampedRemaining = remaining > 0 ? remaining : 0;
      if (currentTurn.value == 'white') {
        whiteRemainingMs.value = clampedRemaining;
      } else {
        blackRemainingMs.value = clampedRemaining;
      }
      _turnStartedAt = null;
      _turnBaseRemainingMs = clampedRemaining;
    }

    _persistActiveOfflineMatch();
    notifyListeners();
  }

  void _startClockTimer() {
    _stopClockTimer();
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!hasActiveMatch || !_isClockRunning) return;
      _tickClock();
    });
  }

  void _tickClock() {
    if (!hasActiveMatch || !_isClockRunning) return;

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

      // Low-time alert sound & haptic played once when active player has <= 10 seconds
      if (clampedRemaining > 0 && clampedRemaining <= 10000) {
        if (!_lowTimeAlertPlayed) {
          _lowTimeAlertPlayed = true;
          SoundService.instance.playLowTime();
          HapticService.instance.medium();
        }
      } else if (clampedRemaining > 10000) {
        _lowTimeAlertPlayed = false;
      }

      // Timeout detection
      if (clampedRemaining <= 0) {
        _handleOfflineTimeout(currentTurn.value);
        return;
      }
    }

    if (_activeSessionStartedAt != null) {
      final currentTotalMs = _accumulatedElapsedMs +
          DateTime.now().difference(_activeSessionStartedAt!).inMilliseconds;
      elapsedSeconds.value = currentTotalMs ~/ 1000;
    } else {
      elapsedSeconds.value = _accumulatedElapsedMs ~/ 1000;
    }
  }

  void _handleOfflineTimeout(String losingTeam) {
    if (!hasActiveMatch) return;
    _stopClockTimer();
    _isClockRunning = false;

    if (_activeSessionStartedAt != null) {
      _accumulatedElapsedMs +=
          DateTime.now().difference(_activeSessionStartedAt!).inMilliseconds;
      _activeSessionStartedAt = null;
    }
    elapsedSeconds.value = _accumulatedElapsedMs ~/ 1000;

    final winnerTeam = losingTeam == 'white' ? 'black' : 'white';
    final payload = GameOverPayload(
      matchId: matchId ?? 'offline',
      winnerTeam: winnerTeam,
      result: winnerTeam == 'white' ? 'white_wins' : 'black_wins',
      reason: 'timeout',
      ratingChanges: {},
    );

    gameOverData.value = payload;
    matchState.value = OnlineMatchState.gameOver;
    SoundService.instance.playGameOver();
    HapticService.instance.heavy();
    _saveOfflineGameRecord(payload);
    _clearPersistedActiveOfflineMatch();
    notifyListeners();
  }

  /// Call when app resumes from background.
  void syncClocks() {
    if (hasActiveMatch && _isClockRunning) {
      _tickClock();
    }
  }

  void _stopClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = null;
    _turnStartedAt = null;
    _turnBaseRemainingMs = 0;
    _lowTimeAlertPlayed = false;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isClockRunning = false;
    _stopClockTimer();
    whiteRemainingMs.dispose();
    blackRemainingMs.dispose();
    gameEngine.dispose();
    legalMoves.dispose();
    lastMove.dispose();
    moveHistory.dispose();
    viewingMoveIndex.dispose();
    currentTurn.dispose();
    elapsedSeconds.dispose();
    isAiThinking.dispose();
    gameOverData.dispose();
    isGameOverDialogActive.dispose();
    matchState.dispose();
    super.dispose();
  }
}
