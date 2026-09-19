import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/kita_ai.dart';
import '../../../data/models/match_model.dart';
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
      if (mounted) setState(() => _aiReady = true);
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
  }

  void _jumpToStep(int step) {
    if (_states.isEmpty) return;
    final target = step.clamp(0, _states.length - 1);
    setState(() => _currentStep = target);
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
        return KitaBoardTheme.amberSunset();
      case 2:
        return KitaBoardTheme.oceanAzure();
      case 3:
        return KitaBoardTheme.cyberPurple();
      case 4:
        return KitaBoardTheme.slateMonochrome();
      case 0:
      default:
        return KitaBoardTheme.emerald(isDark);
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
                              engine: _states[_currentStep],
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

    final currentEngine = _states[_currentStep];
    final boardTheme = _getBoardTheme(isDark);

    // Highlight the move executed to reach current state
    Set<KitaPos> lastMoveHighlights = {};
    if (_currentStep > 0 && _currentStep <= _match!.moves.length) {
      final lastMove = _match!.moves[_currentStep - 1];
      lastMoveHighlights.add(KitaPos(lastMove.fromCol, lastMove.fromRow));
      lastMoveHighlights.add(KitaPos(lastMove.toCol, lastMove.toRow));
    }

    return Container(
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
      child: Column(
        children: [
          // Toolbar above board (Orientation, Flip, Theme)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
              validMoves: lastMoveHighlights,
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
        ],
      ),
    );
  }

  Widget _buildMoveHistoryPanel(bool isDark) {
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
              Text(
                'replay.moveHistory'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
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
    final fromStr = _formatCoord(move.fromCol, move.fromRow);
    final toStr = _formatCoord(move.toCol, move.toRow);
    final timeStr = move.timeMs > 0 ? '${(move.timeMs / 1000).toStringAsFixed(1)}s' : '';

    return InkWell(
      onTap: () => _jumpToStep(plyIndex),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            const SizedBox(width: 6),

            // Piece and Move notation
            Expanded(
              child: Text(
                '${move.piece} $fromStr→$toStr',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Think time
            if (timeStr.isNotEmpty)
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isActive
                      ? Colors.white70
                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
