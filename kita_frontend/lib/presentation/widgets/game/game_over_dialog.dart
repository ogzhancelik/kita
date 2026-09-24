import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/online_game_provider.dart';

/// Modal dialog presented when an online match concludes.
class GameOverDialog extends StatefulWidget {
  final GameOverPayload gameOverData;
  final String myUserId;
  final VoidCallback onRematch;
  final VoidCallback onBackToMenu;

  const GameOverDialog({
    super.key,
    required this.gameOverData,
    required this.myUserId,
    required this.onRematch,
    required this.onBackToMenu,
  });

  /// Presents the modal dialog with tap-to-dismiss enabled.
  static Future<void> show({
    required BuildContext context,
    required GameOverPayload gameOverData,
    required String myUserId,
    required VoidCallback onRematch,
    required VoidCallback onBackToMenu,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => GameOverDialog(
        gameOverData: gameOverData,
        myUserId: myUserId,
        onRematch: onRematch,
        onBackToMenu: onBackToMenu,
      ),
    );
  }

  @override
  State<GameOverDialog> createState() => _GameOverDialogState();
}

class _GameOverDialogState extends State<GameOverDialog> {
  OnlineGameProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = context.read<OnlineGameProvider>();
    if (_provider != prov) {
      _provider = prov;
      prov.isGameOverDialogActive.value = true;
    }
  }

  @override
  void dispose() {
    _provider?.isGameOverDialogActive.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isDraw = widget.gameOverData.isDraw;
    final isWinner = !isDraw &&
        ((widget.gameOverData.winnerId != null &&
                widget.gameOverData.winnerId == widget.myUserId) ||
            (provider.myTeam != null &&
                provider.myTeam == widget.gameOverData.winner));

    final Color statusColor = isDraw
        ? AppColors.drawGray
        : (isWinner ? AppColors.victory : AppColors.lossRed);

    final String titleKey = isDraw
        ? 'online.resultDraw'
        : (isWinner ? 'online.resultVictory' : 'online.resultDefeat');

    return AlertDialog(
      backgroundColor: AppColors.getCard(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actionsOverflowButtonSpacing: 8,
      title: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close_rounded),
              iconSize: 22,
              color: AppColors.getTextSecondary(isDark),
              tooltip: 'common.close'.tr(),
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDraw
                        ? Icons.handshake_outlined
                        : (isWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied),
                    size: 56,
                    color: statusColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    titleKey.tr(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Reason description
          Text(
            _getLocalizedReason(widget.gameOverData.reason),
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ),

          // Match stats pill: Elapsed time & Total moves
          ValueListenableBuilder<int>(
            valueListenable: provider.elapsedSeconds,
            builder: (ctx, seconds, _) {
              final mins = seconds ~/ 60;
              final secs = seconds % 60;
              final timeStr =
                  '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
              final movesCount = provider.moveHistory.value.length;
              return Container(
                margin: const EdgeInsets.only(top: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(isDark)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: AppColors.getTextMuted(isDark),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(
                        color: AppColors.getTextMuted(isDark),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.numbers_rounded,
                      size: 15,
                      color: AppColors.getTextMuted(isDark),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'replay.movesCount'.tr(args: ['$movesCount']),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Rating Changes if any
          if (widget.gameOverData.ratingChanges != null &&
              widget.gameOverData.ratingChanges!.isNotEmpty)
            _buildRatingChanges(isDark),

          // Rematch pending notification inside GameOverDialog
          ValueListenableBuilder<RematchOfferedPayload?>(
            valueListenable: provider.rematchOffer,
            builder: (ctx, offer, _) {
              if (offer == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(top: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.winBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.winBlue.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.winBlue.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.replay_rounded,
                        color: AppColors.winBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'online.rematchOfferTitle'.tr(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.winBlue,
                            ),
                          ),
                          Text(
                            '${offer.requesterName} • ${offer.timeControl <= 0 ? 'online.timeUnlimited'.tr() : 'online.minuteShort'.tr(args: ['${offer.timeControl ~/ 60000}'])}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Reddet
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.lossRed, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.lossRed.withValues(alpha: 0.12),
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(34, 34),
                      ),
                      onPressed: () {
                        provider.declineRematch();
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                      tooltip: 'online.decline'.tr(),
                    ),
                    const SizedBox(width: 6),
                    // Kabul Et
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text('online.accept'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        provider.acceptRematch();
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        ),
      ),
      actions: [
        // Review Board button (dismisses dialog to view final board and chat)
        TextButton.icon(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          icon: const Icon(Icons.grid_view_rounded, size: 16),
          label: Text('online.viewBoard'.tr()),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.getTextSecondary(isDark),
          ),
        ),

        // Back to Menu button
        TextButton(
          onPressed: widget.onBackToMenu,
          child: Text(
            'online.backToMenu'.tr(),
            style: TextStyle(color: AppColors.getTextSecondary(isDark)),
          ),
        ),

        // Request Rematch button
        ValueListenableBuilder<bool>(
          valueListenable: provider.isRematchRequested,
          builder: (ctx, isRequested, _) {
            if (isRequested) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(width: 8),
                    Text(
                      'online.waitingForRematch'.tr(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ElevatedButton.icon(
              onPressed: widget.onRematch,
              icon: const Icon(Icons.replay, size: 18),
              label: Text('online.rematch'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.darkTextPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRatingChanges(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: widget.gameOverData.ratingChanges!.entries.map((entry) {
          final isUser = entry.key == widget.myUserId;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isUser ? 'online.you'.tr() : 'online.opponent'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                Text(
                  '${entry.value}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ratingGold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getLocalizedReason(String reason) {
    switch (reason) {
      case 'resignation':
        return 'online.reasonResigned'.tr();
      case 'timeout':
        return 'online.reasonTimeout'.tr();
      case 'disconnection':
        return 'online.reasonDisconnected'.tr();
      case 'checkmate':
        return 'online.reasonCheckmate'.tr();
      case 'draw_agreement':
        return 'online.reasonDrawAgreement'.tr();
      default:
        return 'online.reasonNormal'.tr();
    }
  }
}
