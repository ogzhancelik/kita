import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/feedback/sound_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/kita_ai.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/move_evaluation.dart';
import '../../../data/services/match_api_service.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_card.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/game/ai_advantage_bar.dart';
import '../../widgets/game/kita_board_theme.dart';
import '../../widgets/game/kita_board_widget.dart';

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
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

    // 4. Deselect (clicking on an empty tile or non-turn piece)
    setState(() {
      _selectedPos = null;
      _selectedPieceId = null;
      _validMoves = {};
    });
  }

  /// Returns true when [move] will capture the opponent king.
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
    final rowHeight = 44.0;
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
    const rowLabels = ['A', 'B', 'C', 'D'];
    final r = (row >= 0 && row < 4) ? rowLabels[row] : '$row';
    return '$r${col + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: KitaAppBar(
        showAuthActions: false,
        showBack: true,
        title: 'replay.title'.tr(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : ResponsiveLayout(
                  maxWidth: _isHorizontal ? 680 : 480,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Players & Match Outcome Header
                          _buildMatchHeader(isDark),
                          const SizedBox(height: 8),

                          // 2. AI Advantage Evaluation Bar
                          if (_states.isNotEmpty) ...[
                            AiAdvantageBar(
                              engine: _activeEngine,
                              ai: _aiReady ? _ai : null,
                              thickness: 24,
                            ),
                            const SizedBox(height: 10),
                          ],

                          // 3. Kita Board Container
                          _buildBoardCard(isDark),
                          const SizedBox(height: 10),

                          // 4. Playback Navigation Controls (⏮ ◀ ▶/⏸ ▶ ⏭)
                          _buildPlaybackControls(isDark),
                          const SizedBox(height: 10),

                          // 5. Interactive Move List
                          _buildMoveHistoryPanel(isDark),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildMatchHeader(bool isDark) {
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
      outcomeColor = Colors.grey;
    } else {
      outcomeText = match.result.toUpperCase();
      outcomeColor = AppColors.primaryGreen;
    }

    return KitaCard(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // White player info
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$whiteName (${match.whitePlayer?.rating ?? 1200})',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // VS divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'vs',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),

              // Black player info
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        '$blackName (${match.blackPlayer?.rating ?? 1200})',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey, width: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: outcomeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  outcomeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: outcomeColor,
                  ),
                ),
              ),
              Text(
                'replay.movesCount'.tr(args: ['${_match!.totalMoves}']),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoardCard(bool isDark) {
    if (_states.isEmpty) return const SizedBox();

    final currentEngine = _activeEngine;
    final boardTheme = _getBoardTheme(isDark);

    // Highlight the move executed to reach current state
    Set<KitaPos> lastMoveHighlights = {};
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

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isSandboxMode
              ? AppColors.ratingGold.withValues(alpha: 0.65)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: _isSandboxMode ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _isSandboxMode
                ? AppColors.ratingGold.withValues(alpha: isDark ? 0.22 : 0.12)
                : Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Toolbar above board
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_isSandboxMode)
                Row(
                  children: [
                    Container(
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
                          Text(
                            _forkStep == 0
                                ? 'replay.sandboxInitialActive'.tr()
                                : 'replay.sandboxActive'.tr(args: ['$_forkStep']),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ratingGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Text(
                  _currentStep == 0
                      ? 'replay.initialPosition'.tr()
                      : 'replay.plyIndicator'.tr(args: ['$_currentStep', '${_states.length - 1}']),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'game.flipBoard'.tr(),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.swap_vert_rounded, size: 18),
                    onPressed: () => setState(() => _flipBoard = !_flipBoard),
                  ),
                  IconButton(
                    tooltip: _isHorizontal ? 'game.orientationHorizontal'.tr() : 'game.orientationVertical'.tr(),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      _isHorizontal ? Icons.stay_current_landscape_rounded : Icons.stay_current_portrait_rounded,
                      size: 18,
                      color: AppColors.primaryGreen,
                    ),
                    onPressed: () => setState(() => _isHorizontal = !_isHorizontal),
                  ),
                  IconButton(
                    tooltip: 'game.heatmapTheme'.tr(args: ['']),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.palette_outlined, size: 18),
                    onPressed: () => setState(() => _themeIndex = (_themeIndex + 1) % 5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Board Widget
          AspectRatio(
            aspectRatio: _isHorizontal ? (7 / 4) : (4 / 7),
            child: KitaBoardWidget(
              pieces: currentEngine.activePositions,
              selectedPos: _selectedPos,
              validMoves: _selectedPieceId != null ? _validMoves : lastMoveHighlights,
              onTileTap: _onTileTap,
              isHorizontal: _isHorizontal,
              flipBoard: _flipBoard,
              theme: boardTheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(bool isDark) {
    if (_isSandboxMode) {
      return _buildSandboxControls(isDark);
    }

    return KitaCard(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        children: [
          // Scrub Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: AppColors.primaryGreen,
              thumbColor: AppColors.primaryGreen,
            ),
            child: Slider(
              value: _currentStep.toDouble(),
              min: 0.0,
              max: (_states.length > 1 ? (_states.length - 1).toDouble() : 1.0),
              divisions: _states.length > 1 ? _states.length - 1 : 1,
              onChanged: (val) => _jumpToStep(val.toInt()),
            ),
          ),

          // Step Buttons & Auto-play
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Jump to Start
              IconButton(
                tooltip: 'replay.jumpStart'.tr(),
                icon: const Icon(Icons.skip_previous_rounded, size: 22),
                onPressed: _currentStep > 0 ? () => _jumpToStep(0) : null,
              ),

              // Previous Move
              IconButton(
                tooltip: 'replay.prevMove'.tr(),
                icon: const Icon(Icons.fast_rewind_rounded, size: 24),
                onPressed: _currentStep > 0 ? _prevStep : null,
              ),

              // Play / Pause
              FloatingActionButton.small(
                elevation: 2,
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                onPressed: _togglePlayPause,
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 26,
                ),
              ),

              // Next Move
              IconButton(
                tooltip: 'replay.nextMove'.tr(),
                icon: const Icon(Icons.fast_forward_rounded, size: 24),
                onPressed: _currentStep < _states.length - 1 ? _nextStep : null,
              ),

              // Jump to End
              IconButton(
                tooltip: 'replay.jumpEnd'.tr(),
                icon: const Icon(Icons.skip_next_rounded, size: 22),
                onPressed: _currentStep < _states.length - 1
                    ? () => _jumpToStep(_states.length - 1)
                    : null,
              ),

              // Speed selector button
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Sandbox hint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 13,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'replay.sandboxHint'.tr(),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSandboxControls(bool isDark) {
    final currentEngine = _activeEngine;
    final turnColor = currentEngine.turn == PieceTeam.white ? Colors.white : Colors.black;
    final turnTeamName = currentEngine.turn == PieceTeam.white ? 'replay.whiteTeam'.tr() : 'replay.blackTeam'.tr();

    String statusText;
    if (currentEngine.isGameOver) {
      String outcome;
      if (currentEngine.getStatus() == GameStatus.whiteWins) {
        outcome = 'game.whiteWins'.tr();
      } else if (currentEngine.getStatus() == GameStatus.blackWins) {
        outcome = 'game.blackWins'.tr();
      } else {
        outcome = 'game.draw'.tr();
      }
      statusText = 'replay.gameOverTitle'.tr(args: [outcome]);
    } else {
      final steps = currentEngine.currentStepCount;
      statusText = 'replay.sandboxTurn'.tr(args: [turnTeamName, '$steps', steps > 1 ? 's' : '']);
    }

    return KitaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      child: Column(
        children: [
          // Status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: turnColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              if (_sandboxMoves.isNotEmpty)
                Text(
                  '$_sandboxStep / ${_sandboxMoves.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Action buttons row: Undo, Reset, AI Move, Return to Replay
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Undo
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.undo_rounded, size: 16),
                label: Text('replay.undo'.tr(), style: const TextStyle(fontSize: 11.5)),
                onPressed: _sandboxStep > 0 ? _undoSandboxMove : null,
              ),

              // Reset to Fork
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: Text('replay.resetFork'.tr(), style: const TextStyle(fontSize: 11.5)),
                onPressed: _sandboxMoves.isNotEmpty ? _resetToFork : null,
              ),

              // AI Move
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: _isAiThinking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.smart_toy_outlined, size: 16),
                label: Text(
                  _isAiThinking ? 'replay.aiThinking'.tr() : 'replay.aiMove'.tr(),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                onPressed: (!currentEngine.isGameOver && !_isAiThinking && !_isAutoRetaliating)
                    ? _playAiSandboxMove
                    : null,
              ),

              // Return to Replay
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ratingGold,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: Text(
                  'replay.returnToReplay'.tr(),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _exitSandbox(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSandboxBranchPanel(bool isDark) {
    return KitaCard(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.alt_route_rounded, size: 18, color: AppColors.ratingGold),
                  const SizedBox(width: 6),
                  Text(
                    'replay.alternateBranch'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _exitSandbox(),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.replay_rounded, size: 14, color: AppColors.primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        'replay.returnToReplay'.tr(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          if (_sandboxMoves.isEmpty)
            Container(
              height: 120,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 28,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'replay.noSandboxMoves'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.builder(
                itemCount: _sandboxMoves.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isForkActive = _sandboxStep == 0;
                    return InkWell(
                      onTap: () => _jumpToSandboxStep(0),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isForkActive
                              ? AppColors.ratingGold.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isForkActive
                                ? AppColors.ratingGold
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.fork_left_rounded, size: 15, color: AppColors.ratingGold),
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
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
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
                  final sandboxEval = (_sandboxEvaluations.length > moveIndex) ? _sandboxEvaluations[moveIndex] : null;

                  return InkWell(
                    onTap: () => _jumpToSandboxStep(index),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                          SizedBox(
                            width: 28,
                            child: Text(
                              '$turnNumber.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? Colors.white70
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                            ),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isWhite ? Colors.white : Colors.black,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isActive ? Colors.white : Colors.grey,
                                width: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${move.pieceId} $fromStr→$toStr',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                                color: isActive
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                              ),
                            ),
                          ),
                          if (sandboxEval != null) ...[
                            const SizedBox(width: 6),
                            _buildEvalBadge(sandboxEval, isActive, isDark),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoveHistoryPanel(bool isDark) {
    if (_isSandboxMode) {
      return _buildSandboxBranchPanel(isDark);
    }
    if (_match == null || _match!.moves.isEmpty) {
      return const SizedBox();
    }

    final moves = _match!.moves;
    final int turnPairsCount = ((moves.length + 1) / 2).floor();

    return KitaCard(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'replay.moveHistory'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'replay.evalHint'.tr(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'replay.evalLegend'.tr(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'replay.tapMoveToJump'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // Move items list
          SizedBox(
            height: 180,
            child: ListView.builder(
              controller: _movesScrollController,
              itemCount: turnPairsCount,
              itemBuilder: (context, turnIndex) {
                final whitePlyIndex = turnIndex * 2 + 1; // 1-based ply
                final blackPlyIndex = turnIndex * 2 + 2;

                final whiteMove = whitePlyIndex <= moves.length ? moves[whitePlyIndex - 1] : null;
                final blackMove = blackPlyIndex <= moves.length ? moves[blackPlyIndex - 1] : null;

                final isWhiteActive = _currentStep == whitePlyIndex;
                final isBlackActive = _currentStep == blackPlyIndex;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isWhiteActive || isBlackActive)
                        ? AppColors.primaryGreen.withValues(alpha: 0.12)
                        : (turnIndex % 2 == 0
                            ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02))
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      // Turn number
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${turnIndex + 1}.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
                      const SizedBox(width: 8),

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
          ),
        ],
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
    final timeStr = move.timeMs > 0 ? '${(move.timeMs / 1000).toStringAsFixed(1)}s' : '';
    final eval = (_evaluations.length >= plyIndex) ? _evaluations[plyIndex - 1] : null;

    return InkWell(
      onTap: () => _jumpToStep(plyIndex),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
            // Team icon
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isWhite ? Colors.white : Colors.black,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? Colors.white : Colors.grey,
                  width: 1,
                ),
              ),
            ),
            const SizedBox(width: 5),

            // Piece and Move notation
            Expanded(
              child: Text(
                move.notation,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Move evaluation delta badge (like +0.1, -0.3)
            if (eval != null) ...[
              const SizedBox(width: 4),
              _buildEvalBadge(eval, isActive, isDark),
            ],

            // Think time
            if (timeStr.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 9.0,
                  color: isActive
                      ? Colors.white70
                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ),
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
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            color: textColor,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
