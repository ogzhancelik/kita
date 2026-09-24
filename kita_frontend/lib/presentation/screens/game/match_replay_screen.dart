import 'dart:async';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/feedback/sound_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/kita_ai.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/move_evaluation.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/match_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/avatar_picker.dart';
import '../../widgets/game/ai_advantage_bar.dart';
import '../../widgets/game/kita_board_theme.dart';
import '../../widgets/game/kita_board_widget.dart';
import '../../widgets/home/settings_dialog.dart';

/// Redesigned Match Review / Replay screen adhering strictly to the
/// online/offline in-game screen template.
///
/// Layout Order (Top to Bottom):
///   1. Top Panel (Exit button, Replay/Move title, Flip Perspective, Theme, Orientation, Details)
///   2. Opponent Player Info Bar (Avatar, name & rating on left; color badge on right)
///   3. Centered Board Container (Responsive sizing for horizontal & vertical modes)
///   4. Player Info Bar (Status/turn on left; avatar, name, & player's color on bottom-right)
///   5. AI Advantage Evaluation Bar (directly below player's info panel)
///   6. Interactive Move List (Expanded area where chat normally sits)
///   7. Bottom Navigation Bar (Jump start, Prev, Play/Pause, Next, Jump end, Speed / Sandbox controls)
class MatchReplayScreen extends StatefulWidget {
  final MatchRecordModel? match;
  final String? matchId;

  const MatchReplayScreen({
    super.key,
    this.match,
    this.matchId,
  }) : assert(match != null || matchId != null, 'Either match or matchId must be provided');

  @override
  State<MatchReplayScreen> createState() => _MatchReplayScreenState();
}

class _MatchReplayScreenState extends State<MatchReplayScreen> {
  final MatchApiService _matchApiService = MatchApiService();
  final ScrollController _movesScrollController = ScrollController();

  MatchRecordModel? _match;
  bool _isLoading = true;
  String? _errorMessage;

  // Board engine states for each ply: index 0 is initial state, 1..N after each move
  List<KitaGameEngine> _states = [];
  int _currentStep = 0;

  // Playback
  bool _isPlaying = false;
  double _playbackSpeed = 1.0; // 0.5x, 1x, 1.5x, 2x
  Timer? _playbackTimer;

  // Board presentation
  bool _isHorizontal = true;
  bool _flipBoard = false;
  int _themeIndex = 0;

  // AI Evaluation
  final KitaAI _ai = KitaAI.instance;
  bool _aiReady = false;
  List<MoveEvaluation?> _evaluations = [];
  List<MoveEvaluation?> _sandboxEvaluations = [];

  // Interactive Sandbox Fork State
  bool _isSandboxMode = false;
  int _forkStep = 0;
  List<KitaGameEngine> _sandboxStates = [];
  List<KitaMove> _sandboxMoves = [];
  int _sandboxStep = 0;
  KitaPos? _selectedPos;
  String? _selectedPieceId;
  Set<KitaPos> _validMoves = {};
  bool _isAiThinking = false;
  bool _isAutoRetaliating = false;

  KitaGameEngine get _activeEngine {
    if (_isSandboxMode && _sandboxStates.isNotEmpty) {
      return _sandboxStates[_sandboxStep.clamp(0, _sandboxStates.length - 1)];
    }
    if (_states.isNotEmpty) {
      return _states[_currentStep.clamp(0, _states.length - 1)];
    }
    return KitaGameEngine();
  }

  @override
  void initState() {
    super.initState();
    _initAI();
    _loadMatchData();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _movesScrollController.dispose();
    super.dispose();
  }

  Future<void> _initAI() async {
    try {
      await _ai.initialize();
      if (mounted) {
        setState(() {
          _aiReady = true;
          _computeMoveEvaluations();
          if (_isSandboxMode) _computeSandboxEvaluations();
        });
      }
    } catch (_) {
      // AI fallback heuristic in advantage bar will be used
    }
  }

  Future<void> _loadMatchData() async {
    if (widget.match != null) {
      _match = widget.match;
      _computeEngineStates();
      _initPlayerPerspective();
      setState(() => _isLoading = false);
      return;
    }

    try {
      final loaded = await _matchApiService.getMatchDetails(widget.matchId!);
      if (!mounted) return;
      setState(() {
        _match = loaded;
        _isLoading = false;
      });
      _computeEngineStates();
      _initPlayerPerspective();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Sets default board perspective to player's eye (Black if player was black, White if white).
  void _initPlayerPerspective() {
    if (_match == null) return;
    final authProv = context.read<AuthProvider>();
    final currentUserId = authProv.currentUser?.id;
    final currentUsername = authProv.currentUser?.username ?? authProv.displayName;

    bool userIsBlack = false;
    if (_match!.isOffline) {
      if (_match!.blackPlayer?.id == 'guest' ||
          _match!.blackPlayer?.id == 'local_player' ||
          _match!.whitePlayer?.id == 'bot') {
        userIsBlack = true;
      }
    } else if (currentUserId != null && currentUserId.isNotEmpty) {
      if (_match!.blackPlayerId == currentUserId ||
          _match!.blackPlayer?.username == currentUsername) {
        userIsBlack = true;
      }
    }

    setState(() {
      _flipBoard = userIsBlack;
    });
  }

  void _computeEngineStates() {
    if (_match == null) return;
    final List<KitaGameEngine> computed = [];
    KitaGameEngine current = KitaGameEngine();
    computed.add(current);

    for (final moveRecord in _match!.moves) {
      try {
        final kitaMove = moveRecord.toKitaMove();
        current = current.applyMove(kitaMove);
        computed.add(current);
      } catch (_) {
        break;
      }
    }

    _states = computed;
    _currentStep = 0;
    _computeMoveEvaluations();
  }

  void _computeMoveEvaluations() {
    if (_states.length < 2 || _match == null) {
      _evaluations = [];
      return;
    }

    final List<double> stateScores = [];
    for (final state in _states) {
      stateScores.add(AiAdvantageBar.computeWhiteAdvantageScore(state, _aiReady ? _ai : null));
    }

    final List<MoveEvaluation?> evals = [];
    for (int i = 1; i < _states.length; i++) {
      final isWhite = i % 2 == 1; // 1-based ply: 1 is White, 2 is Black, etc.
      evals.add(MoveEvaluation.compute(
        whiteScoreBefore: stateScores[i - 1],
        whiteScoreAfter: stateScores[i],
        isWhiteMove: isWhite,
      ));
    }

    _evaluations = evals;
  }

  void _computeSandboxEvaluations() {
    if (_sandboxStates.length < 2) {
      _sandboxEvaluations = [];
      return;
    }

    final List<double> stateScores = [];
    for (final state in _sandboxStates) {
      stateScores.add(AiAdvantageBar.computeWhiteAdvantageScore(state, _aiReady ? _ai : null));
    }

    final List<MoveEvaluation?> evals = [];
    for (int i = 1; i < _sandboxStates.length; i++) {
      final globalPly = _forkStep + i;
      final isWhite = globalPly % 2 == 1;
      evals.add(MoveEvaluation.compute(
        whiteScoreBefore: stateScores[i - 1],
        whiteScoreAfter: stateScores[i],
        isWhiteMove: isWhite,
      ));
    }

    _sandboxEvaluations = evals;
  }

  void _jumpToStep(int step) {
    if (_states.isEmpty) return;
    if (_isSandboxMode) {
      _exitSandbox(jumpToStep: step);
      return;
    }
    final target = step.clamp(0, _states.length - 1);
    setState(() {
      _currentStep = target;
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
    });
    _scrollToActiveMove();
  }

  void _nextStep() {
    if (_currentStep < _states.length - 1) {
      _jumpToStep(_currentStep + 1);
    } else if (_isPlaying) {
      _togglePlayPause();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _jumpToStep(_currentStep - 1);
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _playbackTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      if (_currentStep >= _states.length - 1) {
        _jumpToStep(0);
      }
      final intervalMs = (1000 / _playbackSpeed).round();
      _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
        if (!mounted) return;
        if (_currentStep < _states.length - 1) {
          _nextStep();
        } else {
          _togglePlayPause();
        }
      });
      setState(() => _isPlaying = true);
    }
  }

  void _onTileTap(KitaPos pos) {
    if (_isLoading || _isAiThinking || _isAutoRetaliating) return;

    final engine = _activeEngine;

    // 1. If clicking a valid move target -> Apply move and fork/continue sandbox
    if (_selectedPieceId != null && _validMoves.contains(pos)) {
      final move = KitaMove(
        pieceId: _selectedPieceId!,
        fromPos: _selectedPos!,
        toPos: pos,
      );

      if (!_isSandboxMode) {
        // Auto-enter sandbox mode forked at current replay step
        if (_isPlaying) _togglePlayPause();
        _isSandboxMode = true;
        _forkStep = _currentStep;
        _sandboxStates = [_states[_forkStep]];
        _sandboxMoves = [];
        _sandboxStep = 0;
      }

      _applySandboxMove(move);
      return;
    }

    // 2. If clicking on already selected piece -> Deselect it
    if (_selectedPos != null && _selectedPos == pos) {
      setState(() {
        _selectedPos = null;
        _selectedPieceId = null;
        _validMoves = {};
      });
      return;
    }

    // If game is over in current state, don't allow selecting pieces
    if (engine.isGameOver) {
      setState(() {
        _selectedPos = null;
        _selectedPieceId = null;
        _validMoves = {};
      });
      return;
    }

    // 3. If clicking on piece of current turn's team -> Select it & show valid moves
    String? clickedPieceId;
    engine.activePositions.forEach((id, p) {
      if (p == pos) clickedPieceId = id;
    });

    if (clickedPieceId != null) {
      final piece = KitaPiece.allPieces[clickedPieceId];
      if (piece?.team == engine.turn) {
        setState(() {
          _selectedPos = pos;
          _selectedPieceId = clickedPieceId;
          _validMoves = engine.getLegalMovesForPiece(clickedPieceId!);
        });
        return;
      }
    }

    // 4. Deselect
    setState(() {
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
    });
  }

  bool _isCapture(KitaGameEngine engine, KitaMove move) {
    final oppKingId = engine.turn == PieceTeam.white ? 'BK' : 'WK';
    final oppKingPos = engine.positions[oppKingId];
    return oppKingPos != null && move.toPos == oppKingPos;
  }

  void _applySandboxMove(KitaMove move) {
    final baseList = _sandboxStates.sublist(0, _sandboxStep + 1);
    final baseMoves = _sandboxMoves.sublist(0, _sandboxStep);

    if (_isCapture(baseList.last, move)) {
      SoundService.instance.playCapture();
    } else {
      SoundService.instance.playMove();
    }
    final nextEngine = baseList.last.applyMove(move);

    setState(() {
      _sandboxStates = [...baseList, nextEngine];
      _sandboxMoves = [...baseMoves, move];
      _sandboxStep = _sandboxStates.length - 1;
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
    });
    _computeSandboxEvaluations();

    if (nextEngine.hasKingRetaliation) {
      _handleAutoRetaliation();
    }
  }

  Future<void> _handleAutoRetaliation() async {
    final retaliationMove = _activeEngine.getKingRetaliationMove();
    if (retaliationMove == null) return;

    setState(() {
      _isAutoRetaliating = true;
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
    });

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted || !_isSandboxMode) return;

    final baseList = _sandboxStates.sublist(0, _sandboxStep + 1);
    final baseMoves = _sandboxMoves.sublist(0, _sandboxStep);
    SoundService.instance.playCapture();
    final nextEngine = baseList.last.applyMove(retaliationMove);

    setState(() {
      _sandboxStates = [...baseList, nextEngine];
      _sandboxMoves = [...baseMoves, retaliationMove];
      _sandboxStep = _sandboxStates.length - 1;
      _isAutoRetaliating = false;
    });
    _computeSandboxEvaluations();
  }

  Future<void> _playAiSandboxMove() async {
    final engine = _activeEngine;
    if (engine.isGameOver || _isAiThinking || _isAutoRetaliating) return;

    if (!_isSandboxMode) {
      if (_isPlaying) _togglePlayPause();
      _isSandboxMode = true;
      _forkStep = _currentStep;
      _sandboxStates = [_states[_forkStep]];
      _sandboxMoves = [];
      _sandboxStep = 0;
    }

    setState(() => _isAiThinking = true);
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    final aiMove = _aiReady
        ? _ai.chooseMoveWithDifficulty(_activeEngine, AIDifficulty.hard)
        : null;

    if (!mounted) return;
    setState(() => _isAiThinking = false);

    if (aiMove != null) {
      _applySandboxMove(aiMove);
    }
  }

  void _exitSandbox({int? jumpToStep}) {
    setState(() {
      _isSandboxMode = false;
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
      _currentStep = (jumpToStep ?? _forkStep).clamp(0, _states.length - 1);
    });
    _scrollToActiveMove();
  }

  void _resetToFork() {
    if (_sandboxStates.isEmpty) return;
    setState(() {
      _sandboxStates = [_sandboxStates.first];
      _sandboxMoves = [];
      _sandboxStep = 0;
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
    });
  }

  void _undoSandboxMove() {
    if (_sandboxStep > 0) {
      setState(() {
        _sandboxStep--;
        _selectedPos = null;
        _selectedPieceId = null;
        _validMoves = {};
      });
    }
  }

  void _jumpToSandboxStep(int step) {
    if (_sandboxStates.isEmpty) return;
    final target = step.clamp(0, _sandboxStates.length - 1);
    setState(() {
      _sandboxStep = target;
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
    });
  }

  void _changeSpeed(double newSpeed) {
    setState(() => _playbackSpeed = newSpeed);
    if (_isPlaying) {
      _playbackTimer?.cancel();
      final intervalMs = (1000 / _playbackSpeed).round();
      _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
        if (!mounted) return;
        if (_currentStep < _states.length - 1) {
          _nextStep();
        } else {
          _togglePlayPause();
        }
      });
    }
  }

  void _scrollToActiveMove() {
    if (!_movesScrollController.hasClients || _currentStep <= 0) return;
    const rowHeight = 44.0;
    final targetOffset = ((_currentStep - 1) / 2) * rowHeight;
    _movesScrollController.animateTo(
      targetOffset.clamp(0.0, _movesScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  KitaBoardTheme _getBoardTheme(bool isDark) {
    switch (_themeIndex) {
      case 1:
        return KitaBoardTheme.emerald(isDark);
      case 2:
        return KitaBoardTheme.oceanAzure();
      case 3:
        return KitaBoardTheme.cyberPurple();
      case 4:
        return KitaBoardTheme.slateMonochrome();
      case 0:
      default:
        return KitaBoardTheme.amberSunset();
    }
  }

  String _formatCoord(int col, int row) {
    const rowLabels = ['D', 'C', 'B', 'A'];
    final r = (row >= 0 && row < 4) ? rowLabels[row] : '$row';
    return '$r${col + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.lossRed),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('common.back'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    // Determine perspective:
    // When _flipBoard is false: White is at bottom, Black is at top
    // When _flipBoard is true: Black is at bottom, White is at top
    final isBottomWhite = !_flipBoard;
    final bottomPlayer = isBottomWhite ? _match?.whitePlayer : _match?.blackPlayer;
    final bottomTeam = isBottomWhite ? 'white' : 'black';
    final topPlayer = isBottomWhite ? _match?.blackPlayer : _match?.whitePlayer;
    final topTeam = isBottomWhite ? 'black' : 'white';

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Panel: Settings, Exit, Replay state
            _buildTopPanel(isDark),

            // 2. Middle Game Area: Opponent Card, Board, Player Card, Advantage Bar, Move List
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalHeight = constraints.maxHeight;
                  final totalWidth = constraints.maxWidth;

                  final opponentCard = _buildPlayerInfoBar(
                    isBottom: false,
                    player: topPlayer,
                    team: topTeam,
                    isDark: isDark,
                  );

                  final userCard = _buildPlayerInfoBar(
                    isBottom: true,
                    player: bottomPlayer,
                    team: bottomTeam,
                    isDark: isDark,
                  );

                  final boardWidget = _buildBoardWidget(isDark);

                  // Fixed vertical elements:
                  // Opponent Card (~44px) + Gap (8px) + User Card (~44px) + Gap (8px) + Advantage Bar (~26px + 8px padding) = 138px
                  const double fixedHeaderHeight = 138.0;
                  const double minMoveListHeight = 110.0;
                  final double availableForBoardAndList =
                      max(minMoveListHeight + 60.0, totalHeight - fixedHeaderHeight);
                  final double maxBoardHeight =
                      max(60.0, availableForBoardAndList - minMoveListHeight);

                  final double boardHeight;
                  if (_isHorizontal) {
                    final double naturalHorizontalHeight = totalWidth * (4.0 / 7.0);
                    boardHeight = min(naturalHorizontalHeight, maxBoardHeight);
                  } else {
                    final double targetVerticalHeight = availableForBoardAndList * 0.52;
                    final double naturalVerticalHeight = totalWidth * (7.0 / 4.0);
                    boardHeight =
                        min(min(targetVerticalHeight, maxBoardHeight), naturalVerticalHeight);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top player (Opponent)
                      opponentCard,

                      const SizedBox(height: 8),

                      // Centered Board Section
                      SizedBox(
                        height: boardHeight,
                        width: totalWidth,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: _isHorizontal ? (7 / 4) : (4 / 7),
                            child: boardWidget,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Bottom player (Player's eye perspective with color on bottom-right)
                      userCard,

                      // Black/White Advantage Bar placed directly below the player's info panel
                      if (_states.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: AiAdvantageBar(
                            engine: _activeEngine,
                            ai: _aiReady ? _ai : null,
                            thickness: 26,
                          ),
                        ),

                      // Move List positioned where chat is placed in live matches
                      Expanded(
                        child: _buildMoveHistoryPanel(isDark),
                      ),
                    ],
                  );
                },
              ),
            ),

            // 3. Bottom Navigation & Playback Controls Panel
            _buildBottomPlaybackBar(isDark),
          ],
        ),
      ),
    );
  }

  /// Top panel matching the game style: Exit button on left, Replay / Sandbox status in center,
  /// and Hamburger Settings menu on right.
  Widget _buildTopPanel(bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        border: Border(
          bottom: BorderSide(
            color: AppColors.getBorder(isDark),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // Exit button
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            color: AppColors.getTextPrimary(isDark),
            tooltip: 'replay.exit'.tr(),
            onPressed: () => Navigator.of(context).pop(),
          ),

          const SizedBox(width: 4),

          // Center: Sandbox Banner (stays) or Clean Replay Title (ply indicator removed)
          Expanded(
            child: _isSandboxMode
                ? InkWell(
                    onTap: _exitSandbox,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.ratingGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.ratingGold.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.alt_route_rounded, size: 14, color: AppColors.ratingGold),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _forkStep == 0
                                  ? 'replay.sandboxInitialActive'.tr()
                                  : 'replay.sandboxActive'.tr(args: ['$_forkStep']),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ratingGold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.close_rounded, size: 13, color: AppColors.ratingGold),
                        ],
                      ),
                    ),
                  )
                : Text(
                    'replay.title'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
          ),

          // 1. Flip board perspective
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.swap_vert_rounded, size: 21),
            color: _flipBoard ? AppColors.accent : AppColors.getTextPrimary(isDark),
            tooltip: 'replay.flipPerspective'.tr(),
            onPressed: () => setState(() => _flipBoard = !_flipBoard),
          ),

          // 2. Horizontal / Vertical orientation toggle
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.screen_rotation_rounded, size: 21),
            color: AppColors.getTextPrimary(isDark),
            tooltip: 'replay.orientation'.tr(),
            onPressed: () => setState(() => _isHorizontal = !_isHorizontal),
          ),

          // 3. Match replay info
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.info_outline_rounded, size: 21),
            color: AppColors.getTextPrimary(isDark),
            tooltip: 'replay.matchInfo'.tr(),
            onPressed: () => _showMatchDetailsDialog(isDark),
          ),

          // 4. Settings
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.settings_rounded, size: 21),
            color: AppColors.getTextPrimary(isDark),
            tooltip: 'settings.title'.tr(),
            onPressed: () => SettingsDialog.show(context),
          ),
        ],
      ),
    );
  }



  /// Player info bar styled symmetrically with online/offline PlayerInfoBar.
  /// For bottom player (user's eye): puts the player's color on bottom-right (Black if black, white if white).
  Widget _buildPlayerInfoBar({
    required bool isBottom,
    required UserProfile? player,
    required String team, // 'white' or 'black'
    required bool isDark,
  }) {
    final isWhite = team == 'white';
    final teamColor = isWhite ? Colors.white : const Color(0xFF222222);

    final playerName = player?.username ??
        (isWhite ? 'replay.whiteTeam'.tr() : 'replay.blackTeam'.tr());
    final playerRating = player?.rating ?? 1200;

    final avatarIdx = (player?.avatarIndex != null)
        ? player!.avatarIndex!
        : (playerName.hashCode.abs() % AvatarPicker.avatars.length);
    final avatarItem = AvatarPicker.avatars[avatarIdx % AvatarPicker.avatars.length];

    final isTurnToMove = _activeEngine.turn == (isWhite ? PieceTeam.white : PieceTeam.black);

    // Player color badge (Black if black, white if white)
    final colorBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isWhite ? Colors.white : const Color(0xFF202020),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWhite ? Colors.grey.shade400 : AppColors.ratingGold.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWhite ? const Color(0xFFEEEEEE) : Colors.black,
              border: Border.all(
                color: isWhite ? Colors.grey.shade600 : Colors.white60,
                width: 0.9,
              ),
            ),
          ),
          const SizedBox(width: 4.5),
          Text(
            isWhite ? 'replay.whiteTeam'.tr() : 'replay.blackTeam'.tr(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isWhite ? Colors.black87 : Colors.white,
            ),
          ),
        ],
      ),
    );

    final avatarWidget = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: avatarItem.accentColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(
          color: teamColor,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          avatarItem.icon,
          size: 16,
          color: avatarItem.accentColor,
        ),
      ),
    );

    final nameAndRating = Column(
      crossAxisAlignment: isBottom ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          playerName,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.getTextPrimary(isDark),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
          decoration: BoxDecoration(
            color: AppColors.ratingGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$playerRating',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ratingGold,
            ),
          ),
        ),
      ],
    );

    final turnBadge = isTurnToMove
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: AppColors.accentSecondary.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentSecondary,
                  ),
                ),
                const SizedBox(width: 4.5),
                Text(
                  'replay.toMove'.tr(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.accent : AppColors.accentSecondary,
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        border: Border(
          bottom: !isBottom
              ? BorderSide(color: AppColors.getBorder(isDark), width: 0.8)
              : BorderSide.none,
          top: isBottom
              ? BorderSide(color: AppColors.getBorder(isDark), width: 0.8)
              : BorderSide.none,
        ),
      ),
      child: isBottom
          ? Row(
              children: [
                // Left: turn indicator
                turnBadge,
                const Spacer(),
                // Right: Name/rating, avatar, and player's color on bottom-right!
                nameAndRating,
                const SizedBox(width: 8),
                avatarWidget,
                const SizedBox(width: 8),
                colorBadge,
              ],
            )
          : Row(
              children: [
                // Left: Avatar, Name/rating
                avatarWidget,
                const SizedBox(width: 8),
                nameAndRating,
                const Spacer(),
                // Right: Opponent's color badge and turn indicator
                turnBadge,
                const SizedBox(width: 8),
                colorBadge,
              ],
            ),
    );
  }

  /// Board Widget configured with active state, theme, perspective flip, and interactive taps
  Widget _buildBoardWidget(bool isDark) {
    if (_states.isEmpty) return const SizedBox();

    final currentEngine = _activeEngine;
    final boardTheme = _getBoardTheme(isDark);

    // Highlight the move executed to reach current state
    final Set<KitaPos> lastMoveHighlights = {};
    if (_isSandboxMode) {
      if (_sandboxStep > 0 && _sandboxStep - 1 < _sandboxMoves.length) {
        final lastMove = _sandboxMoves[_sandboxStep - 1];
        lastMoveHighlights.add(lastMove.fromPos);
        lastMoveHighlights.add(lastMove.toPos);
      }
    } else {
      if (_currentStep > 0 && _currentStep <= _match!.moves.length) {
        final lastMove = _match!.moves[_currentStep - 1];
        lastMoveHighlights.add(KitaPos(lastMove.fromCol, lastMove.fromRow));
        lastMoveHighlights.add(KitaPos(lastMove.toCol, lastMove.toRow));
      }
    }

    return KitaBoardWidget(
      pieces: currentEngine.activePositions,
      selectedPos: _selectedPos,
      validMoves: _selectedPieceId != null ? _validMoves : lastMoveHighlights,
      onTileTap: _onTileTap,
      isHorizontal: _isHorizontal,
      flipBoard: _flipBoard,
      theme: boardTheme,
    );
  }

  /// Move list placed where the chat panel sits in online match screen.
  Widget _buildMoveHistoryPanel(bool isDark) {
    if (_isSandboxMode) {
      return _buildSandboxBranchPanel(isDark);
    }

    if (_match == null || _match!.moves.isEmpty) {
      return Container(
        color: AppColors.getCard(isDark),
        alignment: Alignment.center,
        child: Text(
          'online.noMoves'.tr(),
          style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(isDark)),
        ),
      );
    }

    final moves = _match!.moves;
    final int turnPairsCount = ((moves.length + 1) / 2).floor();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        border: Border(
          top: BorderSide(color: AppColors.getBorder(isDark), width: 0.8),
        ),
      ),
      child: ListView.builder(
        controller: _movesScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        itemCount: turnPairsCount,
        itemBuilder: (context, turnIndex) {
          final whitePlyIndex = turnIndex * 2 + 1; // 1-based ply
          final blackPlyIndex = turnIndex * 2 + 2;

          final whiteMove =
              whitePlyIndex <= moves.length ? moves[whitePlyIndex - 1] : null;
          final blackMove =
              blackPlyIndex <= moves.length ? moves[blackPlyIndex - 1] : null;

          final isWhiteActive = _currentStep == whitePlyIndex;
          final isBlackActive = _currentStep == blackPlyIndex;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2.5),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: (isWhiteActive || isBlackActive)
                  ? AppColors.primaryGreen.withValues(alpha: 0.12)
                  : (turnIndex % 2 == 0
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.black.withValues(alpha: 0.02))
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                // Turn number
                SizedBox(
                  width: 24,
                  child: Text(
                    '${turnIndex + 1}.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextMuted(isDark),
                    ),
                  ),
                ),

                // White ply
                Expanded(
                  child: whiteMove != null
                      ? _buildMoveButton(
                          move: whiteMove,
                          plyIndex: whitePlyIndex,
                          isActive: isWhiteActive,
                          isWhite: true,
                          isDark: isDark,
                        )
                      : const SizedBox(),
                ),
                const SizedBox(width: 6),

                // Black ply
                Expanded(
                  child: blackMove != null
                      ? _buildMoveButton(
                          move: blackMove,
                          plyIndex: blackPlyIndex,
                          isActive: isBlackActive,
                          isWhite: false,
                          isDark: isDark,
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoveButton({
    required MoveRecordModel move,
    required int plyIndex,
    required bool isActive,
    required bool isWhite,
    required bool isDark,
  }) {
    final eval = (_evaluations.length >= plyIndex) ? _evaluations[plyIndex - 1] : null;

    return InkWell(
      onTap: () => _jumpToStep(plyIndex),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryGreen
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? AppColors.primaryGreen
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Row(
          children: [
            // Team disc
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: isWhite ? Colors.white : Colors.black,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? Colors.white : Colors.grey,
                  width: 0.9,
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Piece and Move notation
            Expanded(
              child: Text(
                move.notation,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Evaluation delta badge
            if (eval != null) ...[
              const SizedBox(width: 4),
              _buildEvalBadge(eval, isActive, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEvalBadge(MoveEvaluation eval, bool isActive, bool isDark) {
    final textColor = eval.getTextColor(isDark, isActive);
    final badgeColor = eval.getBadgeColor(isActive);
    final borderColor = eval.getBorderColor(isDark, isActive);

    final tooltipMsg = 'replay.evalDeltaTooltip'.tr(args: [
      eval.qualityName,
      eval.positionScoreLabel,
    ]);

    return Tooltip(
      message: tooltipMsg,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Text(
          eval.deltaLabel,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            color: textColor,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  /// Alternate branch panel in sandbox mode
  Widget _buildSandboxBranchPanel(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        border: Border(
          top: BorderSide(color: AppColors.getBorder(isDark), width: 0.8),
        ),
      ),
      child: _sandboxMoves.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 26,
                      color: AppColors.getTextMuted(isDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'replay.sandboxHint'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.getTextMuted(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: _sandboxMoves.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isForkActive = _sandboxStep == 0;
                  return InkWell(
                    onTap: () => _jumpToSandboxStep(0),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 2.5),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: isForkActive
                            ? AppColors.ratingGold.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isForkActive
                              ? AppColors.ratingGold
                              : AppColors.getBorder(isDark),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fork_left_rounded,
                              size: 14, color: AppColors.ratingGold),
                          const SizedBox(width: 8),
                          Text(
                            _forkStep == 0
                                ? 'replay.initialPosition'.tr()
                                : 'replay.sandboxActive'.tr(args: ['$_forkStep']),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isForkActive ? FontWeight.w800 : FontWeight.w600,
                              color: isForkActive
                                  ? AppColors.ratingGold
                                  : AppColors.getTextPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final moveIndex = index - 1;
                final move = _sandboxMoves[moveIndex];
                final isActive = _sandboxStep == index;
                final isWhite = _sandboxStates[index - 1].turn == PieceTeam.white;
                final fromStr = _formatCoord(move.fromPos.col, move.fromPos.row);
                final toStr = _formatCoord(move.toPos.col, move.toPos.row);
                final turnNumber = ((_forkStep + moveIndex) ~/ 2) + 1;
                final sandboxEval = (_sandboxEvaluations.length > moveIndex)
                    ? _sandboxEvaluations[moveIndex]
                    : null;

                return InkWell(
                  onTap: () => _jumpToSandboxStep(index),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2.5),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primaryGreen
                          : AppColors.getSurface(isDark),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isActive
                            ? AppColors.primaryGreen
                            : AppColors.getBorder(isDark),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '$turnNumber.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? Colors.white70
                                  : AppColors.getTextMuted(isDark),
                            ),
                          ),
                        ),
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: isWhite ? Colors.white : Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive ? Colors.white : Colors.grey,
                              width: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${move.pieceId} $fromStr→$toStr',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                              color: isActive
                                  ? Colors.white
                                  : AppColors.getTextPrimary(isDark),
                            ),
                          ),
                        ),
                        if (sandboxEval != null) ...[
                          const SizedBox(width: 4),
                          _buildEvalBadge(sandboxEval, isActive, isDark),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// Bottom panel with play/previous/next controls adhering to MatchBottomBar layout.
  Widget _buildBottomPlaybackBar(bool isDark) {
    if (_isSandboxMode) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          border: Border(
            top: BorderSide(
              color: AppColors.getBorder(isDark),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Reset to Fork
            TextButton.icon(
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: Text('replay.resetFork'.tr(), style: const TextStyle(fontSize: 11.5)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.getTextPrimary(isDark),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: _sandboxMoves.isNotEmpty ? _resetToFork : null,
            ),

            // AI Move
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                elevation: 0,
              ),
              icon: _isAiThinking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.smart_toy_outlined, size: 16),
              label: Text(
                'replay.aiMove'.tr(),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              onPressed: (!_activeEngine.isGameOver && !_isAiThinking && !_isAutoRetaliating)
                  ? _playAiSandboxMove
                  : null,
            ),

            // Return to Replay
            TextButton.icon(
              icon: const Icon(Icons.replay_rounded, size: 16),
              label: Text('replay.returnToReplay'.tr(), style: const TextStyle(fontSize: 11.5)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ratingGold,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: _exitSandbox,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        border: Border(
          top: BorderSide(
            color: AppColors.getBorder(isDark),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Previous move (◀)
          IconButton(
            tooltip: 'replay.prevMove'.tr(),
            icon: const Icon(Icons.fast_rewind_rounded, size: 24),
            color: _currentStep > 0
                ? AppColors.getTextPrimary(isDark)
                : AppColors.getTextMuted(isDark),
            onPressed: _currentStep > 0 ? _prevStep : null,
          ),

          // Center Play / Pause button
          FloatingActionButton.small(
            elevation: 1,
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            onPressed: _togglePlayPause,
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 24,
            ),
          ),

          // Next move (▶)
          IconButton(
            tooltip: 'replay.nextMove'.tr(),
            icon: const Icon(Icons.fast_forward_rounded, size: 24),
            color: _currentStep < _states.length - 1
                ? AppColors.getTextPrimary(isDark)
                : AppColors.getTextMuted(isDark),
            onPressed: _currentStep < _states.length - 1 ? _nextStep : null,
          ),

          // AI Move (in replay mode: automatically chooses the best AI move and opens sandbox branch)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              elevation: 0,
            ),
            icon: _isAiThinking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.smart_toy_outlined, size: 16),
            label: Text(
              'replay.aiMove'.tr(),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
            onPressed: (!_activeEngine.isGameOver && !_isAiThinking && !_isAutoRetaliating)
                ? _playAiSandboxMove
                : null,
          ),

          // Playback speed selector button
          PopupMenuButton<double>(
            tooltip: 'replay.speed'.tr(),
            initialValue: _playbackSpeed,
            onSelected: _changeSpeed,
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 0.5, child: Text('0.5x')),
              const PopupMenuItem(value: 1.0, child: Text('1.0x')),
              const PopupMenuItem(value: 1.5, child: Text('1.5x')),
              const PopupMenuItem(value: 2.0, child: Text('2.0x')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.getBorder(isDark), width: 0.8),
              ),
              child: Text(
                '${_playbackSpeed}x',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMatchDetailsDialog(bool isDark) {
    if (_match == null) return;
    final match = _match!;

    final whiteName = match.whitePlayer?.username ?? 'White';
    final blackName = match.blackPlayer?.username ?? 'Black';

    String outcomeText;
    Color outcomeColor;
    if (match.result == 'white_wins') {
      outcomeText = 'replay.whiteWon'.tr(args: [whiteName]);
      outcomeColor = AppColors.ratingGold;
    } else if (match.result == 'black_wins') {
      outcomeText = 'replay.blackWon'.tr(args: [blackName]);
      outcomeColor = AppColors.ratingGold;
    } else if (match.result == 'draw') {
      outcomeText = 'replay.draw'.tr();
      outcomeColor = AppColors.drawGray;
    } else {
      outcomeText = match.result.toUpperCase();
      outcomeColor = AppColors.primaryGreen;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Text(
              'replay.title'.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$whiteName (${match.whitePlayer?.rating ?? 1200})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                Text(
                  'vs',
                  style: TextStyle(color: AppColors.getTextMuted(isDark)),
                ),
                Text(
                  '$blackName (${match.blackPlayer?.rating ?? 1200})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: outcomeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                outcomeText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: outcomeColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'replay.movesCount'.tr(args: ['${match.totalMoves}']),
              style: TextStyle(color: AppColors.getTextSecondary(isDark)),
            ),
            if (match.startedAt.year > 2000) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat.yMMMd().add_jm().format(match.startedAt),
                style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(isDark)),
              ),
            ],
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
}
