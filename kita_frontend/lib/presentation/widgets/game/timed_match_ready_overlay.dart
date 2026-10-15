import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/online_game_provider.dart';

/// Overlay displayed over the board for timed custom matches, requiring mutual
/// "Ready" confirmation before starting the countdown chess clock.
class TimedMatchReadyOverlay extends StatelessWidget {
  final OnlineGameProvider provider;

  const TimedMatchReadyOverlay({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<bool>(
      valueListenable: provider.isClockStarted,
      builder: (context, clockStarted, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: provider.isReadyConfirmationRequired,
          builder: (context, requiresReady, _) {
            // Dismiss overlay once clock has started
            if (!requiresReady || clockStarted) {
              return const SizedBox.shrink();
            }

            return ValueListenableBuilder<bool>(
              valueListenable: provider.myReadyState,
              builder: (context, myReady, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: provider.opponentReadyState,
                  builder: (context, opponentReady, _) {
                    return ValueListenableBuilder<int>(
                      valueListenable: provider.readyCountdownSeconds,
                      builder: (context, countdown, _) {
                        final bothReady = myReady && opponentReady;

                        return Container(
                          color: (isDark ? AppColors.darkBg : AppColors.lightBg)
                              .withValues(alpha: 0.82),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 340),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.getCard(isDark),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.primaryAmber.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryAmber.withValues(alpha: 0.12),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. Header Icon
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primaryAmber.withValues(alpha: 0.15),
                                        border: Border.all(
                                          color: AppColors.primaryAmber.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.hourglass_top_rounded,
                                        color: AppColors.primaryAmber,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // 2. Title & Description
                                    Text(
                                      bothReady
                                          ? 'online.matchStartingGo'.tr()
                                          : 'online.readyConfirmationTitle'.tr(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.getTextPrimary(isDark),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      bothReady
                                          ? 'online.matchStartingCountdown'.tr(args: ['1'])
                                          : 'online.readyConfirmationDesc'.tr(),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.getTextSecondary(isDark),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 18),

                                    // 3. Status Badges Row
                                    Row(
                                      children: [
                                        // Local Player Readiness
                                        Expanded(
                                          child: _buildPlayerReadyBox(
                                            isLocal: true,
                                            isReady: myReady,
                                            isDark: isDark,
                                            onConfirm: () => provider.confirmReady(),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Opponent Readiness
                                        Expanded(
                                          child: _buildPlayerReadyBox(
                                            isLocal: false,
                                            isReady: opponentReady,
                                            isDark: isDark,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    // 4. Auto-start Fallback Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.getSurface(isDark),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.getBorder(isDark),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.av_timer_rounded,
                                            size: 13,
                                            color: AppColors.primaryAmber,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'online.autoStartingIn'.tr(args: ['$countdown']),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.getTextSecondary(isDark),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPlayerReadyBox({
    required bool isLocal,
    required bool isReady,
    required bool isDark,
    VoidCallback? onConfirm,
  }) {
    if (isReady) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.winGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.winGreen.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.winGreen,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'online.readyConfirmed'.tr(),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: AppColors.winGreen,
              ),
            ),
          ],
        ),
      );
    }

    if (isLocal && onConfirm != null) {
      return SizedBox(
        height: 40,
        child: ElevatedButton.icon(
          onPressed: onConfirm,
          icon: const Icon(Icons.touch_app_rounded, size: 16),
          label: Text('online.imReady'.tr()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryAmber,
            foregroundColor: AppColors.darkTextPrimary,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // Opponent not ready yet
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.getBorder(isDark),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryAmber,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'online.waitingForOpponentReady'.tr(),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.getTextMuted(isDark),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
