import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/feedback/sound_service.dart';
import '../../../core/feedback/toast_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/kita_ai.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/user_model.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_button.dart';
import '../../widgets/common/kita_card.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/game/kita_board_theme.dart';
import '../../widgets/game/kita_board_widget.dart';
import 'match_replay_screen.dart';

enum PlayMode { localCoop, vsAi }

class OfflineAiScreen extends StatefulWidget {
  const OfflineAiScreen({super.key});

  @override
  State<OfflineAiScreen> createState() => _OfflineAiScreenState();
}

class _OfflineAiScreenState extends State<OfflineAiScreen> {
  // Game Engine
  late KitaGameEngine _engine;

  // Settings
  PlayMode _playMode = PlayMode.localCoop;
  PieceTeam _playerTeam = PieceTeam.white; // Human player's side in VS AI mode
  int _selectedDifficulty = 1; // 0: Easy, 1: Medium, 2: Hard
  bool _isHorizontal = true;
  bool _flipBoard = false;
  int _themeIndex = 0; // 0: Emerald, 1: Amber, 2: Ocean, 3: Purple, 4: Slate
  int _gameSessionId = 0;

  // UI Selection State
  KitaPos? _selectedPos;
  String? _selectedPieceId;
  Set<KitaPos> _validMoves = {};
  bool _isAiThinking = false;
  bool _isAutoRetaliating = false;

  // AI Player (lazy-loaded)
  KitaAI? _ai;
  bool _aiLoading = false;

  // Move recording for post-match replay
  List<MoveRecordModel> _recordedMoves = [];
  DateTime _lastMoveTime = DateTime.now();
  DateTime _matchStartedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ai = KitaAI.instance;
    _ai!.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _resetGame();
  }

  void _resetGame() {
    _gameSessionId++;
    final session = _gameSessionId;
    setState(() {
      _engine = KitaGameEngine();
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
      _isAiThinking = false;
      _isAutoRetaliating = false;
      _recordedMoves = [];
      _lastMoveTime = DateTime.now();
      _matchStartedAt = DateTime.now();
    });

    // In VS AI mode, if human plays Black, Bot is White and moves first!
    if (_playMode == PlayMode.vsAi && _playerTeam == PieceTeam.black) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _gameSessionId == session &&
            _playMode == PlayMode.vsAi &&
            _playerTeam == PieceTeam.black &&
            _engine.turn == PieceTeam.white) {
          _triggerAiMove();
        }
      });
    }
  }

  void _selectPlayerTeam(PieceTeam team) {
    if (_playerTeam == team) return;
    setState(() {
      _playerTeam = team;
      // Auto-flip board when playing Black so player's pieces are at the bottom
      _flipBoard = (team == PieceTeam.black);
    });
    _resetGame();
    KitaToast.info(team == PieceTeam.white
        ? 'game.sideSelectedWhite'.tr()
        : 'game.sideSelectedBlack'.tr());
  }

  void _loadScenario(Map<String, KitaPos?> positions, String label) {
    _gameSessionId++;
    setState(() {
      _engine = KitaGameEngine.custom(
        positions: positions,
        turn: PieceTeam.white,
      );
      _playerTeam = PieceTeam.white;
      _flipBoard = false;
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
      _isAiThinking = false;
      _isAutoRetaliating = false;
      _recordedMoves = [];
      _lastMoveTime = DateTime.now();
    });
    KitaToast.info('game.scenarioLoaded'.tr(args: [label]));
  }

  void _showTestScenariosDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.science_rounded, color: Colors.orangeAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              'game.testScenariosTitle'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'game.testScenariosDesc'.tr(),
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: AppColors.primaryGreen.withValues(alpha: 0.4)),
              ),
              tileColor: AppColors.primaryGreen.withValues(alpha: 0.1),
              leading: const Icon(Icons.auto_mode_rounded, color: AppColors.primaryGreen),
              title: Text(
                'game.scenarioRetaliationTitle'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              subtitle: Text(
                'game.scenarioRetaliationDesc'.tr(),
                style: const TextStyle(fontSize: 11.5),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _loadScenario({
                  'BK': const KitaPos(3, 0),  // tile value 2
                  'WK': const KitaPos(3, 3),  // tile value 2
                  'WP1': const KitaPos(1, 0), // 2 steps to reach BK at (3,0)
                  'BP1': const KitaPos(5, 3), // 2 steps to reach WK at (3,3)
                  'BP2': const KitaPos(0, 1),
                  'WP2': const KitaPos(6, 2),
                }, 'game.scenarioRetaliationTitle'.tr());
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              tileColor: Colors.amber.withValues(alpha: 0.1),
              leading: const Icon(Icons.emoji_events_outlined, color: Colors.amber),
              title: Text(
                'game.scenarioImmediateWinTitle'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              subtitle: Text(
                'game.scenarioImmediateWinDesc'.tr(),
                style: const TextStyle(fontSize: 11.5),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _loadScenario({
                  'BK': const KitaPos(3, 0),  // tile value 2
                  'WK': const KitaPos(3, 3),  // tile value 2
                  'WP1': const KitaPos(1, 0), // Can capture BK at (3,0)
                  'BP1': const KitaPos(0, 1), // Far from WK
                  'BP2': const KitaPos(0, 2), // Far from WK
                  'WP2': const KitaPos(6, 2),
                }, 'game.scenarioImmediateWinTitle'.tr());
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              leading: const Icon(Icons.refresh_rounded, color: Colors.grey),
              title: Text(
                'game.scenarioDefaultBoard'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _resetGame();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  KitaBoardTheme _getTheme(bool isDark) {
    switch (_themeIndex) {
      case 1:
        return KitaBoardTheme.amberSunset();
      case 2:
        return KitaBoardTheme.oceanAzure();
      case 3:
        return KitaBoardTheme.cyberPurple();
      case 4:
        return KitaBoardTheme.slateMonochrome();
      default:
        return KitaBoardTheme.emerald(isDark);
    }
  }

  String _getThemeName() {
    switch (_themeIndex) {
      case 0:
        return 'Emerald';
      case 1:
        return 'Amber Sunset';
      case 2:
        return 'Ocean Azure';
      case 3:
        return 'Cyber Purple';
      case 4:
        return 'Slate Mono';
      default:
        return 'Emerald';
    }
  }

  /// Returns true when [move] will capture the opponent king in the current
  /// engine state (i.e. the piece lands on the opponent king's tile).
  bool _isCapture(KitaMove move) {
    final oppKingId = _engine.turn == PieceTeam.white ? 'BK' : 'WK';
    final oppKingPos = _engine.positions[oppKingId];
    return oppKingPos != null && move.toPos == oppKingPos;
  }

  void _onTileTap(KitaPos pos) {
    if (_engine.isGameOver || _isAiThinking || _isAutoRetaliating) {
      if (_engine.isGameOver) _showGameOverDialog();
      return;
    }

    // In VS AI mode, only allow moves on human player's turn
    if (_playMode == PlayMode.vsAi && _engine.turn != _playerTeam) {
      return;
    }

    setState(() {
      // 1. If clicking a valid move target -> Apply move
      if (_selectedPieceId != null && _validMoves.contains(pos)) {
        final startPos = _selectedPos!;
        final move = KitaMove(pieceId: _selectedPieceId!, fromPos: startPos, toPos: pos);

        _recordMove(move);
        // Play sound before state update so capture detection works
        if (_isCapture(move)) {
          SoundService.instance.playCapture();
        } else {
          SoundService.instance.playMove();
        }
        _engine = _engine.applyMove(move);
        _selectedPos = null;
        _selectedPieceId = null;
        _validMoves = {};

        // Check if game ended immediately (king captured without retaliation, or no moves left)
        if (_engine.isGameOver) {
          _showGameOverDialog();
          return;
        }

        // If opposing king is in reach, trigger automatic retaliation sequence
        if (_engine.hasKingRetaliation) {
          _handleAutoRetaliation();
          return;
        }

        // Trigger AI move if in VS AI mode and turn passed to the bot
        final aiTeam = _playerTeam == PieceTeam.white ? PieceTeam.black : PieceTeam.white;
        if (_playMode == PlayMode.vsAi && _engine.turn == aiTeam) {
          _triggerAiMove();
        }
        return;
      }

      // 2. If clicking on the already selected piece's tile -> Deselect it
      if (_selectedPos != null && _selectedPos == pos) {
        _selectedPos = null;
        _selectedPieceId = null;
        _validMoves = {};
        return;
      }

      // 3. If clicking on own piece -> Select it & calculate legal moves
      String? clickedPieceId;
      _engine.activePositions.forEach((id, p) {
        if (p == pos) clickedPieceId = id;
      });

      if (clickedPieceId != null) {
        final piece = KitaPiece.allPieces[clickedPieceId];
        if (piece?.team == _engine.turn) {
          _selectedPos = pos;
          _selectedPieceId = clickedPieceId;
          _validMoves = _engine.getLegalMovesForPiece(clickedPieceId!);

          if (_validMoves.isEmpty) {
            KitaToast.warning('game.noLegalMoves'.tr(args: ['${_engine.currentStepCount}']));
          }
          return;
        }
      }

      // 4. Deselect (clicking on an empty tile or non-valid opponent piece)
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
    });
  }

  Future<void> _handleAutoRetaliation() async {
    final retaliationMove = _engine.getKingRetaliationMove();
    if (retaliationMove == null) return;

    setState(() {
      _isAutoRetaliating = true;
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
    });

    // Short visual pause (400ms) so players see the first move
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    setState(() {
      _recordMove(retaliationMove);
      SoundService.instance.playCapture();
      _engine = _engine.applyMove(retaliationMove);
      _isAutoRetaliating = false;
    });

    // Brief pause (200ms) before displaying Draw dialog
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    if (_engine.isGameOver) {
      _showGameOverDialog();
    }
  }

  Future<void> _triggerAiMove() async {
    final session = _gameSessionId;
    setState(() => _isAiThinking = true);

    // Ensure AI model is initialized
    if (_ai != null && !_ai!.isInitialized && !_aiLoading) {
      _aiLoading = true;
      await _ai!.initialize();
      _aiLoading = false;
    }

    if (!mounted || _gameSessionId != session || _engine.isGameOver || _ai == null) {
      if (mounted && _gameSessionId == session) {
        setState(() => _isAiThinking = false);
      }
      return;
    }

    // Map difficulty index 0/1/2 → Easy/Medium/Hard
    final difficulty = AIDifficulty.all[_selectedDifficulty.clamp(0, AIDifficulty.all.length - 1)];

    // Small delay to let the UI update with "thinking" indicator
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted || _gameSessionId != session) return;

    final aiMove = _ai!.chooseMoveWithDifficulty(_engine, difficulty);
    if (!mounted || _gameSessionId != session) return;

    if (aiMove != null) {
      setState(() {
        _recordMove(aiMove);
        if (_isCapture(aiMove)) {
          SoundService.instance.playCapture();
        } else {
          SoundService.instance.playMove();
        }
        _engine = _engine.applyMove(aiMove);
        _isAiThinking = false;
      });

      if (_engine.isGameOver) {
        _showGameOverDialog();
        return;
      }

      // If opposing king is in reach, trigger automatic retaliation sequence
      if (_engine.hasKingRetaliation) {
        _handleAutoRetaliation();
        return;
      }
    } else {
      setState(() => _isAiThinking = false);
    }
  }

  void _recordMove(KitaMove move) {
    final now = DateTime.now();
    final durationMs = now.difference(_lastMoveTime).inMilliseconds;
    _lastMoveTime = now;

    _recordedMoves.add(MoveRecordModel(
      ply: _recordedMoves.length + 1,
      playerId: move.pieceId.startsWith('W') ? 'white-player' : 'black-player',
      piece: move.pieceId,
      fromCol: move.fromPos.col,
      fromRow: move.fromPos.row,
      toCol: move.toPos.col,
      toRow: move.toPos.row,
      timeMs: durationMs,
      createdAt: now,
    ));
  }

  String _getTurnText() {
    final isWhite = _engine.turn == PieceTeam.white;
    if (_playMode == PlayMode.vsAi) {
      final isPlayerTurn = _engine.turn == _playerTeam;
      if (isPlayerTurn) {
        return isWhite
            ? "${'game.whiteTurn'.tr()} (${'game.yourTurn'.tr()})"
            : "${'game.blackTurn'.tr()} (${'game.yourTurn'.tr()})";
      } else {
        return isWhite
            ? "${'game.whiteTurn'.tr()} (${'game.botThinking'.tr()})"
            : "${'game.blackTurn'.tr()} (${'game.botThinking'.tr()})";
      }
    }
    return isWhite ? 'game.whiteTurn'.tr() : 'game.blackTurn'.tr();
  }

  void _showGameOverDialog() {
    SoundService.instance.playGameOver();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String title;
    String subtitle;
    IconData icon;
    Color iconColor;

    final endReason = _engine.getEndReason();
    final status = _engine.getStatus();
    final isVsAi = _playMode == PlayMode.vsAi;
    final isPlayerWinner = isVsAi && (
      (status == GameStatus.whiteWins && _playerTeam == PieceTeam.white) ||
      (status == GameStatus.blackWins && _playerTeam == PieceTeam.black)
    );

    switch (status) {
      case GameStatus.whiteWins:
        if (isVsAi) {
          title = isPlayerWinner ? 'game.youWon'.tr() : 'game.aiWon'.tr();
          icon = isPlayerWinner ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded;
          iconColor = isPlayerWinner ? AppColors.ratingGold : Colors.redAccent;
        } else {
          title = 'game.whiteWins'.tr();
          icon = Icons.emoji_events_rounded;
          iconColor = AppColors.ratingGold;
        }
        subtitle = endReason == EndReason.kingCaptured
            ? 'game.whiteKingCapturedDesc'.tr()
            : 'game.blackNoLegalMoves'.tr();
        break;
      case GameStatus.blackWins:
        if (isVsAi) {
          title = isPlayerWinner ? 'game.youWon'.tr() : 'game.aiWon'.tr();
          icon = isPlayerWinner ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded;
          iconColor = isPlayerWinner ? AppColors.ratingGold : Colors.redAccent;
        } else {
          title = 'game.blackWins'.tr();
          icon = Icons.emoji_events_rounded;
          iconColor = AppColors.ratingGold;
        }
        subtitle = endReason == EndReason.kingCaptured
            ? 'game.blackKingCapturedDesc'.tr()
            : 'game.whiteNoLegalMoves'.tr();
        break;
      case GameStatus.draw:
        title = 'game.draw'.tr();
        icon = Icons.handshake_rounded;
        iconColor = AppColors.drawGray;
        subtitle = endReason == EndReason.doubleKingCaptured
            ? 'game.doubleKingCapturedDesc'.tr()
            : endReason == EndReason.threefoldRepetition
            ? 'game.threefoldRepetitionDesc'.tr()
            : 'game.genericDrawDesc'.tr();
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 26.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor, width: 2),
                ),
                child: Icon(icon, color: iconColor, size: 44),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_recordedMoves.isNotEmpty) ...[
                KitaButton(
                  text: 'replay.reviewMatch'.tr(),
                  icon: Icons.history_edu_rounded,
                  variant: KitaButtonVariant.secondary,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    final matchRecord = MatchRecordModel(
                      id: 'offline-${DateTime.now().millisecondsSinceEpoch}',
                      whitePlayerId: 'white-player',
                      blackPlayerId: 'black-player',
                      whitePlayer: UserProfile(
                        id: 'white-player',
                        username: _playMode == PlayMode.vsAi
                            ? (_playerTeam == PieceTeam.white ? 'Player' : 'Bot AI')
                            : 'White',
                        rating: 1200,
                        wins: 0,
                        losses: 0,
                        draws: 0,
                        totalGames: 0,
                        winRate: 0,
                      ),
                      blackPlayer: UserProfile(
                        id: 'black-player',
                        username: _playMode == PlayMode.vsAi
                            ? (_playerTeam == PieceTeam.black ? 'Player' : 'Bot AI')
                            : 'Black',
                        rating: 1200,
                        wins: 0,
                        losses: 0,
                        draws: 0,
                        totalGames: 0,
                        winRate: 0,
                      ),
                      winnerId: status == GameStatus.whiteWins
                          ? 'white-player'
                          : (status == GameStatus.blackWins ? 'black-player' : null),
                      result: status == GameStatus.whiteWins
                          ? 'white_wins'
                          : (status == GameStatus.blackWins ? 'black_wins' : 'draw'),
                      totalMoves: _recordedMoves.length,
                      startedAt: _matchStartedAt,
                      endedAt: DateTime.now(),
                      moves: List.from(_recordedMoves),
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MatchReplayScreen(match: matchRecord),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
              KitaButton(
                text: 'game.playAgain'.tr(),
                icon: Icons.replay_rounded,
                variant: KitaButtonVariant.primary,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _resetGame();
                },
              ),
              const SizedBox(height: 10),
              KitaButton(
                text: 'common.close'.tr(),
                variant: KitaButtonVariant.outline,
                height: 42,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boardTheme = _getTheme(isDark);
    final isWhiteTurn = _engine.turn == PieceTeam.white;
    final effectiveFlip = _flipBoard;

    return Scaffold(
      appBar: KitaAppBar(
        showAuthActions: false,
        showBack: true,
        title: _playMode == PlayMode.localCoop ? 'game.localCoopTitle'.tr() : 'game.vsAiTitle'.tr(),
      ),
      body: ResponsiveLayout(
        maxWidth: _isHorizontal ? 640 : 460,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Column(
              children: [
                // 1. Mode Switcher (Coop Pass & Play vs VS AI)
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildModeTab(
                          title: 'game.modeLocal2P'.tr(),
                          icon: Icons.people_alt_rounded,
                          isSelected: _playMode == PlayMode.localCoop,
                          onTap: () {
                            setState(() {
                              _playMode = PlayMode.localCoop;
                              _resetGame();
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildModeTab(
                          title: 'game.modeVsAI'.tr(),
                          icon: Icons.smart_toy_rounded,
                          isSelected: _playMode == PlayMode.vsAi,
                          onTap: () {
                            setState(() {
                              _playMode = PlayMode.vsAi;
                              _resetGame();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 1.1 Side Selection (Only in VS AI mode)
                if (_playMode == PlayMode.vsAi) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, right: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 14,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${'game.side'.tr()}:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _buildSideOption(
                            team: PieceTeam.white,
                            label: 'game.playWhite'.tr(),
                            tooltip: 'game.whiteFirstDesc'.tr(),
                            isWhite: true,
                            isSelected: _playerTeam == PieceTeam.white,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSideOption(
                            team: PieceTeam.black,
                            label: 'game.playBlack'.tr(),
                            tooltip: 'game.blackSecondDesc'.tr(),
                            isWhite: false,
                            isSelected: _playerTeam == PieceTeam.black,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // 2. Info & Controls Card
                KitaCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Player info & AI difficulty if in VS AI
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _playMode == PlayMode.localCoop
                                        ? Icons.sports_esports_rounded
                                        : Icons.smart_toy_rounded,
                                    color: AppColors.primaryGreen,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _playMode == PlayMode.localCoop ? 'game.localCoopDesc'.tr() : 'game.aiBotDesc'.tr(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                        ),
                                      ),
                                      if (_playMode == PlayMode.vsAi)
                                        DropdownButton<int>(
                                          value: _selectedDifficulty,
                                          isDense: true,
                                          underline: const SizedBox(),
                                          dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                                          items: [
                                            DropdownMenuItem(
                                              value: 0,
                                              child: Text(
                                                'game.easy'.tr(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.primaryGreen,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 1,
                                              child: Text(
                                                'game.medium'.tr(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.ratingGold,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 2,
                                              child: Text(
                                                'game.hard'.tr(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.deepOrangeAccent,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) setState(() => _selectedDifficulty = val);
                                          },
                                        )
                                      else
                                        Text(
                                          'game.moveCount'.tr(args: ['${_engine.moveCount}']),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 6),

                          // Right: Board options
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Orientation toggle (Horizontal / Vertical)
                              IconButton(
                                tooltip: _isHorizontal ? 'game.orientationHorizontal'.tr() : 'game.orientationVertical'.tr(),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(5),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: Icon(
                                  _isHorizontal ? Icons.stay_current_landscape_rounded : Icons.stay_current_portrait_rounded,
                                  size: 18,
                                  color: AppColors.primaryGreen,
                                ),
                                onPressed: () => setState(() => _isHorizontal = !_isHorizontal),
                              ),
                              // Manual Flip Board
                              IconButton(
                                tooltip: 'game.flipBoard'.tr(),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(5),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                                onPressed: () => setState(() => _flipBoard = !_flipBoard),
                              ),
                              // Heatmap Palette Cycle
                              IconButton(
                                tooltip: 'game.heatmapTheme'.tr(args: [_getThemeName()]),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(5),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.palette_outlined, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _themeIndex = (_themeIndex + 1) % 5;
                                  });
                                  KitaToast.info('game.heatmapChanged'.tr(args: [_getThemeName()]));
                                },
                              ),
                              // Test Scenarios Button
                              IconButton(
                                tooltip: 'game.testScenarios'.tr(),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(5),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: const Icon(Icons.science_outlined, size: 18, color: Colors.orangeAccent),
                                onPressed: _showTestScenariosDialog,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),

                      // Turn & Step Count Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: isWhiteTurn ? Colors.white : Colors.black,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey, width: 1.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getTurnText(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              if (_isAiThinking) ...[
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ],
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primaryGreen, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_walk_rounded, size: 14, color: AppColors.primaryGreen),
                                const SizedBox(width: 4),
                                Text(
                                  'game.distanceSteps'.tr(args: ['${_engine.currentStepCount}']),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Kita Modular Board
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: _isHorizontal ? (7 / 4) : (4 / 7),
                    child: KitaBoardWidget(
                      // Pass only non-null positions (captured pieces filtered out)
                      pieces: _engine.activePositions,
                      selectedPos: _selectedPos,
                      validMoves: _validMoves,
                      onTileTap: _onTileTap,
                      isHorizontal: _isHorizontal,
                      flipBoard: effectiveFlip,
                      theme: boardTheme,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Action Controls
                Row(
                  children: [
                    Expanded(
                      child: KitaButton(
                        text: 'game.newGame'.tr(),
                        icon: Icons.replay_rounded,
                        variant: KitaButtonVariant.primary,
                        height: 44,
                        onPressed: () {
                          _resetGame();
                          KitaToast.success('game.newGame'.tr());
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KitaButton(
                        text: 'game.returnToMenu'.tr(),
                        variant: KitaButtonVariant.secondary,
                        height: 44,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 5. How to Play — Game Rules Section
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: KitaCard(
                    padding: EdgeInsets.zero,
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      leading: const Icon(Icons.help_outline_rounded, size: 20, color: AppColors.primaryGreen),
                      title: Text(
                        'game.howToPlay'.tr(),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      children: [
                        _buildRuleItem('🎯', 'game.rulesGoalTitle'.tr(), 'game.rulesGoalDesc'.tr(), isDark),
                        _buildRuleItem('📋', 'game.rulesBoardTitle'.tr(), 'game.rulesBoardDesc'.tr(), isDark),
                        _buildRuleItem('♟️', 'game.rulesPiecesTitle'.tr(), 'game.rulesPiecesDesc'.tr(), isDark),
                        _buildRuleItem('🚶', 'game.rulesMovementTitle'.tr(), 'game.rulesMovementDesc'.tr(), isDark),
                        _buildRuleItem('⚔️', 'game.rulesCaptureTitle'.tr(), 'game.rulesCaptureDesc'.tr(), isDark),
                        _buildRuleItem('🏆', 'game.rulesWinTitle'.tr(), 'game.rulesWinDesc'.tr(), isDark),
                        _buildRuleItem('⚖️', 'game.rulesLastStandTitle'.tr(), 'game.rulesLastStandDesc'.tr(), isDark),
                        _buildRuleItem('🤝', 'game.rulesDrawTitle'.tr(), 'game.rulesDrawDesc'.tr(), isDark),
                        _buildRuleItem('🔄', 'game.rulesReversalTitle'.tr(), 'game.rulesReversalDesc'.tr(), isDark),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideOption({
    required PieceTeam team,
    required String label,
    required String tooltip,
    required bool isWhite,
    required bool isSelected,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _selectPlayerTeam(team),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryGreen.withValues(alpha: isDark ? 0.22 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryGreen
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isWhite ? Colors.white : Colors.black,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isWhite ? Colors.grey.shade400 : Colors.grey.shade700,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? AppColors.primaryGreen : const Color(0xFF1B5E20))
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: AppColors.primaryGreen,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem(String emoji, String title, String desc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
