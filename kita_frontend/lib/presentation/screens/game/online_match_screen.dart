import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../widgets/game/chat_panel.dart';
import '../../widgets/game/game_control_bar.dart';
import '../../widgets/game/game_over_dialog.dart';
import '../../widgets/game/kita_board_widget.dart';
import '../../widgets/game/move_history_panel.dart';
import '../../widgets/game/player_info_bar.dart';

/// Online match screen with modular, independently-rebuilding widgets.
///
/// Layout order (top to bottom):
///   1. OpponentInfoBar (with chess clock)
///   2. KitaBoardWidget (game board)
///   3. PlayerInfoBar (with chess clock)
///   4. MoveHistoryPanel (horizontal scrollable ribbon)
///   5. GameControlBar (resign, chat toggle, elapsed time)
///   6. ChatPanel (slide-out overlay)
///
/// Each child widget uses [ValueListenableBuilder] for granular rebuilds.
/// Rearranging or removing widgets will not break the others.
class OnlineMatchScreen extends StatefulWidget {
  const OnlineMatchScreen({super.key});

  @override
  State<OnlineMatchScreen> createState() => _OnlineMatchScreenState();
}

class _OnlineMatchScreenState extends State<OnlineMatchScreen> {
  OnlineGameProvider? _provider;
  bool _isGameOverDialogShowing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = context.read<OnlineGameProvider>();
    if (_provider != prov) {
      _provider?.gameOverData.removeListener(_onGameOver);
      _provider?.matchState.removeListener(_onMatchStateChanged);
      _provider = prov;
      _provider?.gameOverData.addListener(_onGameOver);
      _provider?.matchState.addListener(_onMatchStateChanged);
    }
  }

  @override
  void dispose() {
    _provider?.gameOverData.removeListener(_onGameOver);
    _provider?.matchState.removeListener(_onMatchStateChanged);
    super.dispose();
  }

  void _onMatchStateChanged() {
    if (_provider?.matchState.value == OnlineMatchState.inMatch &&
        _isGameOverDialogShowing &&
        mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _isGameOverDialogShowing = false;
    }
  }

  void _onGameOver() {
    final provider = _provider ?? context.read<OnlineGameProvider>();
    final data = provider.gameOverData.value;
    if (data == null) return;

    // Show game over dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isGameOverDialogShowing) return;
      _isGameOverDialogShowing = true;
      context.read<AuthProvider>().refreshProfile();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => GameOverDialog(
          gameOverData: data,
          myUserId: provider.myUserId ?? '',
          onRematch: () {
            provider.requestRematch();
          },
          onBackToMenu: () {
            _isGameOverDialogShowing = false;
            provider.resetToIdle();
            context.read<AuthProvider>().refreshProfile();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ).then((_) {
        _isGameOverDialogShowing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final authProv = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBlack = provider.myTeam == 'black';

    final myDisplayName = (provider.myUsername != null && provider.myUsername!.isNotEmpty)
        ? provider.myUsername!
        : authProv.displayName;

    final myRating = (authProv.isAuthenticated && authProv.currentUser?.rating != null)
        ? authProv.currentUser!.rating
        : provider.myRating;

    final canLeaveFreely = provider.matchState.value == OnlineMatchState.gameOver ||
        provider.matchState.value == OnlineMatchState.idle;

    return PopScope(
      canPop: canLeaveFreely,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showLeaveConfirmation(context);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: SafeArea(
          child: Stack(
            children: [
              // Main game layout
              Column(
                children: [
                  // 1. Opponent Info Bar (top)
                  PlayerInfoBar(
                    isOpponent: true,
                    name: provider.opponentInfo?.name ?? 'online.opponent'.tr(),
                    rating: provider.opponentInfo?.rating ?? 1200,
                    team: isBlack ? 'white' : 'black',
                    remainingMs: isBlack
                        ? provider.whiteRemainingMs
                        : provider.blackRemainingMs,
                    isActiveTurn: provider.currentTurn,
                    timeControl: provider.timeControl,
                  ),

                  // Rematch requested banner (fallback if dialog is closed)
                  ValueListenableBuilder<bool>(
                    valueListenable: provider.isRematchRequested,
                    builder: (ctx, isRequested, _) {
                      if (!isRequested) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.getCard(isDark),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryGreen),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryGreen),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'online.rematchRequestSent'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                provider.cancelRematchRequest();
                                provider.resetToIdle();
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                'online.backToMenu'.tr(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.lossRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // 2. Board
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _BoardSection(
                          provider: provider,
                          flipBoard: isBlack,
                        ),
                      ),
                    ),
                  ),

                  // 3. Player Info Bar (bottom)
                  PlayerInfoBar(
                    isOpponent: false,
                    name: myDisplayName,
                    rating: myRating,
                    team: provider.myTeam ?? 'white',
                    remainingMs: isBlack
                        ? provider.blackRemainingMs
                        : provider.whiteRemainingMs,
                    isActiveTurn: provider.currentTurn,
                    timeControl: provider.timeControl,
                  ),

                  // 4. Move History Panel
                  const MoveHistoryPanel(),

                  // 5. Game Control Bar
                  const GameControlBar(),
                ],
              ),

              // 6. Chat Panel (overlay)
              const ChatPanel(),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaveConfirmation(BuildContext context) {
    final provider = context.read<OnlineGameProvider>();
    if (provider.matchState.value == OnlineMatchState.gameOver ||
        provider.matchState.value == OnlineMatchState.idle) {
      provider.resetToIdle();
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('online.leaveTitle'.tr()),
        content: Text('online.leaveMessage'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('online.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.resign();
            },
            child: Text(
              'online.resignAndLeave'.tr(),
              style: const TextStyle(color: AppColors.lossRed),
            ),
          ),
        ],
      ),
    );
  }
}

/// Board section that uses ValueListenableBuilder for granular rebuilds.
class _BoardSection extends StatelessWidget {
  final OnlineGameProvider provider;
  final bool flipBoard;

  const _BoardSection({required this.provider, required this.flipBoard});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: provider.viewingMoveIndex,
      builder: (ctx, viewIdx, _) {
        return ValueListenableBuilder<KitaGameEngine>(
          valueListenable: provider.gameEngine,
          builder: (c1, engine, _) {
            final displayEngine = provider.displayEngine;
            final isMyTurn = provider.myTeam == displayEngine.turn.name;
            final isLive = !provider.isViewingHistory;

            return ValueListenableBuilder<List<KitaMove>>(
              valueListenable: provider.legalMoves,
              builder: (c2, legal, _) {
                return _BoardInteraction(
                  provider: provider,
                  displayEngine: displayEngine,
                  flipBoard: flipBoard,
                  isMyTurn: isMyTurn && isLive,
                  legalMoves: isLive ? legal : [],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Handles piece selection and move interaction on the board.
class _BoardInteraction extends StatefulWidget {
  final OnlineGameProvider provider;
  final KitaGameEngine displayEngine;
  final bool flipBoard;
  final bool isMyTurn;
  final List<KitaMove> legalMoves;

  const _BoardInteraction({
    required this.provider,
    required this.displayEngine,
    required this.flipBoard,
    required this.isMyTurn,
    required this.legalMoves,
  });

  @override
  State<_BoardInteraction> createState() => _BoardInteractionState();
}

class _BoardInteractionState extends State<_BoardInteraction> {
  KitaPos? _selectedPos;
  Set<KitaPos> _validMoves = {};

  @override
  Widget build(BuildContext context) {
    return KitaBoardWidget(
      pieces: widget.displayEngine.activePositions,
      selectedPos: _selectedPos,
      validMoves: _validMoves,
      flipBoard: widget.flipBoard,
      onTileTap: widget.isMyTurn ? _onTileTap : null,
    );
  }

  void _onTileTap(KitaPos pos) {
    // If tapping a valid move destination → make the move
    if (_selectedPos != null && _validMoves.contains(pos)) {
      final move = widget.legalMoves.firstWhere(
        (m) => m.fromPos == _selectedPos && m.toPos == pos,
        orElse: () => KitaMove(
          pieceId: '',
          fromPos: _selectedPos!,
          toPos: pos,
        ),
      );

      if (move.pieceId.isNotEmpty) {
        widget.provider.makeMove(move);
      }

      setState(() {
        _selectedPos = null;
        _validMoves = {};
      });
      return;
    }

    // If tapping a piece → select it and show valid moves
    final activePositions = widget.displayEngine.activePositions;
    String? tappedPieceId;
    for (final entry in activePositions.entries) {
      if (entry.value == pos) {
        tappedPieceId = entry.key;
        break;
      }
    }

    if (tappedPieceId != null) {
      // Check if it's our piece
      final piece = KitaPiece.allPieces[tappedPieceId];
      if (piece != null) {
        final isOurPiece = (widget.provider.myTeam == 'white' && piece.isWhite) ||
            (widget.provider.myTeam == 'black' && piece.isBlack);

        if (isOurPiece) {
          final movesForPiece = widget.legalMoves
              .where((m) => m.pieceId == tappedPieceId)
              .map((m) => m.toPos)
              .toSet();

          setState(() {
            _selectedPos = pos;
            _validMoves = movesForPiece;
          });
          return;
        }
      }
    }

    // Tapped empty space or opponent piece → deselect
    setState(() {
      _selectedPos = null;
      _validMoves = {};
    });
  }
}
