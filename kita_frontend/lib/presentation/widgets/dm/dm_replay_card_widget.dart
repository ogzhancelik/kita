import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dm_models.dart';
import '../../screens/game/match_replay_screen.dart';

/// An interactive, beautifully styled match replay card displayed in DM chat.
///
/// Features:
/// - Replay header badge & outcome label
/// - Opponent matchup display (White vs Black)
/// - One-tap 'Watch Replay' action navigating directly to [MatchReplayScreen].
class DmReplayCardWidget extends StatelessWidget {
  final DmReplayPayload payload;
  final bool isMe;
  final bool isDark;
  final DateTime timestamp;

  const DmReplayCardWidget({
    super.key,
    required this.payload,
    required this.isMe,
    required this.isDark,
    required this.timestamp,
  });

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _openReplay(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchReplayScreen(
          matchId: payload.matchId,
          isWatchedReplay: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final whiteName = (payload.whiteUsername != null && payload.whiteUsername!.isNotEmpty)
        ? payload.whiteUsername!
        : 'common.white'.tr();
    final blackName = (payload.blackUsername != null && payload.blackUsername!.isNotEmpty)
        ? payload.blackUsername!
        : 'common.black'.tr();

    final resultText = _buildResultText();
    final resultColor = _buildResultColor();

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        border: Border.all(
          color: AppColors.primaryAmber.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          onTap: () => _openReplay(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Header: Icon + Title + Result Badge ─────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAmber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.movie_filter_rounded,
                        color: AppColors.primaryAmber,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'replay.matchReplay'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getTextPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (resultText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: resultColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: resultColor.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          resultText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: resultColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // ─── Matchup Details (White vs Black) ───────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.getBorder(isDark),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // White player
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                whiteName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade600,
                                  width: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'vs',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextMuted(isDark),
                          ),
                        ),
                      ),
                      // Black player
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                blackName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.getTextPrimary(isDark),
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
                ),
                const SizedBox(height: 10),

                // ─── Timestamp & Code ─────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (payload.shareCode != null && payload.shareCode!.isNotEmpty)
                      Text(
                        '#${payload.shareCode}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextMuted(isDark),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        fontSize: 9.5,
                        color: AppColors.getTextMuted(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _buildResultText() {
    if (payload.result == null || payload.result!.isEmpty) return null;
    final res = payload.result!.toLowerCase();
    if (res == 'white') {
      return 'replay.whiteWon'.tr();
    }
    if (res == 'black') {
      return 'replay.blackWon'.tr();
    }
    if (res == 'draw') {
      return 'replay.drawOutcome'.tr();
    }
    return null;
  }

  Color _buildResultColor() {
    if (payload.result == null) return AppColors.primaryAmber;
    final res = payload.result!.toLowerCase();
    if (res == 'white' || res == 'black') {
      return AppColors.winGreen;
    }
    if (res == 'draw') {
      return AppColors.drawYellow;
    }
    return AppColors.primaryAmber;
  }
}
