import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../providers/online_game_provider.dart';

/// Chess.com-style move history panel — horizontal scrollable ribbon.
///
/// Features:
/// - Moves grouped by turn pairs (1. WhiteMove  BlackMove)
/// - Tap a move to scrub the board to that state (read-only)
/// - "Live" button to return to current game state
/// - Auto-scrolls to latest move
/// - Only rebuilds when moveHistory or viewingMoveIndex changes
class MoveHistoryPanel extends StatefulWidget {
  final ValueNotifier<List<OnlineMoveRecord>>? moveHistory;
  final ValueNotifier<int>? viewingMoveIndex;
  final void Function(int index)? onSelectMove;
  final VoidCallback? onLive;

  const MoveHistoryPanel({
    super.key,
    this.moveHistory,
    this.viewingMoveIndex,
    this.onSelectMove,
    this.onLive,
  });

  @override
  State<MoveHistoryPanel> createState() => _MoveHistoryPanelState();
}

class _MoveHistoryPanelState extends State<MoveHistoryPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onlineProv = widget.moveHistory == null ? context.read<OnlineGameProvider>() : null;
    final moveHistoryListenable = widget.moveHistory ?? onlineProv!.moveHistory;
    final viewingMoveIndexListenable = widget.viewingMoveIndex ?? onlineProv!.viewingMoveIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: ValueListenableBuilder<List<OnlineMoveRecord>>(
        valueListenable: moveHistoryListenable,
        builder: (ctx, moves, _) {
          if (moves.isEmpty) {
            return Center(
              child: Text(
                'online.noMoves'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
            );
          }

          final isViewing = viewingMoveIndexListenable.value >= 0;

          // Auto-scroll to end when new moves arrive
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients && !isViewing) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });

          return ValueListenableBuilder<int>(
            valueListenable: viewingMoveIndexListenable,
            builder: (c1, viewIdx, _) {
              final onLiveTap = widget.onLive ?? (onlineProv != null ? onlineProv.goLive : null);

              return Row(
                children: [
                  // Live button (when viewing history)
                  if (viewIdx >= 0 && onLiveTap != null)
                    _LiveButton(onTap: onLiveTap),

                  // Move chips
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      itemCount: moves.length,
                      itemBuilder: (_, index) {
                        final move = moves[index];
                        final isViewingThis = viewIdx == index + 1; // +1 because index 0 is initial state
                        final isWhiteMove = move.playerTeam == 'white';
                        final piece = KitaPiece.allPieces[move.pieceId];

                        // Show turn number at the start of each white move
                        final turnNum = (index ~/ 2) + 1;
                        final showTurnNum = index % 2 == 0;

                        return GestureDetector(
                          onTap: () {
                            if (isViewingThis) {
                              if (widget.onLive != null) {
                                widget.onLive!();
                              } else if (onlineProv != null) {
                                onlineProv.goLive();
                              }
                            } else {
                              if (widget.onSelectMove != null) {
                                widget.onSelectMove!(index + 1);
                              } else if (onlineProv != null) {
                                onlineProv.viewMoveAt(index + 1);
                              }
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 6,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isViewingThis
                                  ? AppColors.primaryGreen.withValues(alpha: 0.3)
                                  : isDark
                                      ? AppColors.darkCard
                                      : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isViewingThis
                                    ? AppColors.primaryGreen
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showTurnNum) ...[
                                  Text(
                                    '$turnNum.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.lightTextMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                // Piece icon (King symbol for kings only)
                                if (piece?.isKing == true) ...[
                                  Text(
                                    '♚',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isWhiteMove
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                ],
                                // Move notation: A2C3 format
                                Text(
                                  '${KitaMove.formatPos(KitaPos(move.fromCol, move.fromRow))}${KitaMove.formatPos(KitaPos(move.toCol, move.toRow))}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// "LIVE" button to return to current game state.
class _LiveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LiveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'LIVE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
