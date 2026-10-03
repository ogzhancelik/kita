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
  int offlineBotDifficulty = 2; // 0: Novice, 1: Easy, 2: Medium, 3: Hard
  PieceTeam offlinePlayerTeam = PieceTeam.white;
  String? offlinePlayerId;
  String? offlinePlayerName;
  int? offlinePlayerRating;
  bool offlineIsGuest = false;
  bool _offlineMatchSaved = false;
  bool? _localCoopIsHorizontal;
  bool _hasActiveMatch = false;

  OpponentInfo? opponentInfo;
  String? matchId;
  DateTime? _matchStartedAt;
  Timer? _clockTimer;

  // ─── Game Engine & Move History ──────────────────────────────────
  final ValueNotifier<KitaGameEngine> gameEngine = ValueNotifier(KitaGameEngine());
  final ValueNotifier<List<KitaMove>> legalMoves = ValueNotifier([]);
  final ValueNotifier<KitaMove?> lastMove = ValueNotifier(null);
  final ValueNotifier<List<OnlineMoveRecord>> moveHistory = ValueNotifier([]);
  final ValueNotifier<int> viewingMoveIndex = ValueNotifier(-1);
  final List<KitaGameEngine> _engineSnapshots = [];

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
      case 1:
        return 'game.easy'.tr();
      case 3:
        return 'game.hard'.tr();
      case 2:
      default:
        return 'game.medium'.tr();
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
        rating: 800 + difficulty * 200,
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
    int botDifficulty = 2,
    String? playerId,
    String? playerName,
    int? playerRating,
    bool isGuest = false,
  }) {
    _stopClockTimer();
    _hasActiveMatch = true;
    offlinePlayMode = mode;
    offlineBotDifficulty = botDifficulty;
    offlinePlayerTeam = playerTeam;
    offlinePlayerId = playerId ?? offlinePlayerId;
    offlinePlayerName = playerName ?? offlinePlayerName;
    offlinePlayerRating = playerRating ?? offlinePlayerRating;
    offlineIsGuest = isGuest;
    _offlineMatchSaved = false;
    _lastOfflineMatchRecord = null;

    if (mode == PlayMode.vsAi) {
      final botRating = 800 + botDifficulty * 200;
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

    gameEngine.value = KitaGameEngine();
    _engineSnapshots.clear();
    _engineSnapshots.add(KitaGameEngine());
    legalMoves.value = gameEngine.value.getLegalMoves();
    lastMove.value = null;
    moveHistory.value = [];
    viewingMoveIndex.value = -1;
    gameOverData.value = null;
    isGameOverDialogActive.value = false;
    isAiThinking.value = false;
    currentTurn.value = 'white';
    elapsedSeconds.value = 0;
    _matchStartedAt = DateTime.now();

    _startClockTimer();
    matchState.value = OnlineMatchState.inMatch;
    _persistActiveOfflineMatch();
    notifyListeners();

    // If human plays Black vs Bot, Bot is White and moves first!
    if (mode == PlayMode.vsAi && playerTeam == PieceTeam.black) {
      _triggerBotMove(delay: const Duration(milliseconds: 1000));
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
      HapticService.instance.heavy();
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

  Future<void> _triggerBotMove({Duration delay = const Duration(milliseconds: 400)}) async {
    final currentMatchId = matchId;
    isAiThinking.value = true;
    notifyListeners();

    await Future.delayed(delay);
    if (!hasActiveMatch || matchId != currentMatchId) {
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
    final botMove = ai.chooseMoveWithDifficulty(
      gameEngine.value,
      diff,
    );

    isAiThinking.value = false;
    notifyListeners();

    if (botMove != null && hasActiveMatch && matchId == currentMatchId) {
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
    if (_matchStartedAt != null) {
      elapsedSeconds.value =
          DateTime.now().difference(_matchStartedAt!).inSeconds;
    }
    gameOverData.value = payload;
    matchState.value = OnlineMatchState.gameOver;
    _stopClockTimer();
    SoundService.instance.playGameOver();
    HapticService.instance.heavy();
    _saveOfflineGameRecord(payload);
    _clearPersistedActiveOfflineMatch();
    notifyListeners();
  }

  /// Immediately abandons and clears the active offline match.
  void resignAndClear() {
    _stopClockTimer();
    _clearPersistedActiveOfflineMatch();
    _hasActiveMatch = false;
    matchState.value = OnlineMatchState.idle;
    isAiThinking.value = false;
    _engineSnapshots.clear();
    _matchStartedAt = null;
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
      isGuest: offlineIsGuest,
    );
  }

  // ─── Move History Scrubbing ───────────────────────────────────────

  void viewMoveAt(int index) {
    if (index < 0 || index >= _engineSnapshots.length) {
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

  void stepBackward() {
    if (_engineSnapshots.length <= 1) return;
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
    if (_engineSnapshots.length <= 1) return;
    final current = viewingMoveIndex.value;
    if (current == -1) return;
    if (current < _engineSnapshots.length - 1) {
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
      final botRating = 800 + offlineBotDifficulty * 200;
      final botDifficultyNames = ['Novice', 'Easy', 'Medium', 'Hard'];
      final diffName = (offlineBotDifficulty >= 0 && offlineBotDifficulty <= 3)
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
    if (moveHistory.value.length <= 1) return;
    _offlineMatchSaved = true;

    try {
      final record = _createOfflineMatchRecord(payload);
      if (record != null) {
        await LocalMatchHistoryService.instance.saveMatch(record);
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
      debugPrint('[OfflineGameProvider] Error persisting active offline match: $e');
    }
  }

  Future<void> _clearPersistedActiveOfflineMatch() async {
    try {
      await LocalMatchHistoryService.instance.clearActiveOfflineGame();
    } catch (e) {
      debugPrint('[OfflineGameProvider] Error clearing active offline match: $e');
    }
  }

  Future<void> _restoreActiveOfflineMatch() async {
    try {
      final saved = await LocalMatchHistoryService.instance.getActiveOfflineGame();
      if (saved == null) return;

      _hasActiveMatch = true;
      offlinePlayMode = saved.playMode == 'localCoop' ? PlayMode.localCoop : PlayMode.vsAi;
      offlineBotDifficulty = saved.botDifficulty;
      offlinePlayerTeam = saved.playerTeam == 'black' ? PieceTeam.black : PieceTeam.white;
      offlinePlayerId = saved.playerId;
      offlinePlayerName = saved.playerName;
      offlinePlayerRating = saved.playerRating;
      offlineIsGuest = saved.isGuest;
      _offlineMatchSaved = false;
      _lastOfflineMatchRecord = null;

      if (offlinePlayMode == PlayMode.vsAi) {
        final botRating = 800 + offlineBotDifficulty * 200;
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
      elapsedSeconds.value = saved.elapsedSeconds;
      _matchStartedAt = saved.startedAt;

      if (engine.isGameOver) {
        await LocalMatchHistoryService.instance.clearActiveOfflineGame();
        _hasActiveMatch = false;
        notifyListeners();
        return;
      }

      legalMoves.value = engine.getLegalMoves();
      matchState.value = OnlineMatchState.inMatch;
      _startClockTimer();
      notifyListeners();

      if (offlinePlayMode == PlayMode.vsAi && engine.turn != offlinePlayerTeam) {
        final isOpeningMove = engine.moveCount == 0;
        _triggerBotMove(
          delay: isOpeningMove
              ? const Duration(milliseconds: 1000)
              : const Duration(milliseconds: 400),
        );
      }
    } catch (e) {
      debugPrint('[OfflineGameProvider] Error restoring active offline match: $e');
    }
  }

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!hasActiveMatch) return;
      if (_matchStartedAt != null) {
        elapsedSeconds.value =
            DateTime.now().difference(_matchStartedAt!).inSeconds;
      } else {
        elapsedSeconds.value++;
      }
    });
  }

  /// Call when app resumes from background.
  void syncClocks() {
    if (hasActiveMatch && _matchStartedAt != null) {
      elapsedSeconds.value =
          DateTime.now().difference(_matchStartedAt!).inSeconds;
    }
  }

  void _stopClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = null;
  }

  @override
  void dispose() {
    _stopClockTimer();
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
