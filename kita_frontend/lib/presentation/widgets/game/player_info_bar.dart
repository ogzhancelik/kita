import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Player/Opponent info bar with chess clock display.
///
/// This widget is fully independent and modular — it can be placed
/// anywhere in the widget tree without breaking other components.
class PlayerInfoBar extends StatelessWidget {
  final bool isOpponent;
  final String name;
  final int rating;
  final String team; // "white" or "black"
  final ValueNotifier<int> remainingMs;
  final ValueNotifier<String> isActiveTurn;
  final int timeControl;

  const PlayerInfoBar({
    super.key,
    required this.isOpponent,
    required this.name,
    required this.rating,
    required this.team,
    required this.remainingMs,
    required this.isActiveTurn,
    required this.timeControl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWhite = team == 'white';
    final teamColor = isWhite ? Colors.white : const Color(0xFF333333);
    final teamIcon = isWhite
        ? Icons.circle_outlined
        : Icons.circle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: Border(
          bottom: isOpponent
              ? BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.5,
                )
              : BorderSide.none,
          top: !isOpponent
              ? BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.5,
                )
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          // Team color indicator
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: teamColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.5,
              ),
            ),
            child: Icon(
              teamIcon,
              size: 16,
              color: isWhite ? Colors.black54 : Colors.white70,
            ),
          ),
          const SizedBox(width: 10),

          // Name & rating
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$rating',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ratingGold,
                  ),
                ),
              ],
            ),
          ),

          // Chess clock or Unlimited badge
          if (timeControl > 0)
            _ChessClock(
              remainingMs: remainingMs,
              isActiveTurn: isActiveTurn,
              playerTeam: team,
            )
          else
            _UnlimitedClockBadge(
              isActiveTurn: isActiveTurn,
              playerTeam: team,
            ),
        ],
      ),
    );
  }
}

/// Chess clock widget with smooth countdown and color transitions.
class _ChessClock extends StatelessWidget {
  final ValueNotifier<int> remainingMs;
  final ValueNotifier<String> isActiveTurn;
  final String playerTeam;

  const _ChessClock({
    required this.remainingMs,
    required this.isActiveTurn,
    required this.playerTeam,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: isActiveTurn,
      builder: (ctx, turn, _) {
        final isActive = turn == playerTeam;
        return ValueListenableBuilder<int>(
          valueListenable: remainingMs,
          builder: (c, ms, _) {
            final totalSeconds = (ms / 1000).ceil();
            final minutes = totalSeconds ~/ 60;
            final seconds = totalSeconds % 60;
            final isLow = ms < 30000; // Less than 30 seconds
            final isCritical = ms < 10000; // Less than 10 seconds

            Color bgColor;
            Color textColor;

            if (isCritical) {
              bgColor = AppColors.lossRed;
              textColor = AppColors.darkTextPrimary;
            } else if (isLow) {
              bgColor = AppColors.warning.withValues(alpha: 0.9);
              textColor = AppColors.darkTextPrimary;
            } else if (isActive) {
              bgColor = AppColors.primaryGreen;
              textColor = AppColors.darkTextPrimary;
            } else {
              bgColor = Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface;
              textColor = Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary;
            }

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: textColor,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Badge displayed when the match has no time limit (unlimited).
class _UnlimitedClockBadge extends StatelessWidget {
  final ValueNotifier<String> isActiveTurn;
  final String playerTeam;

  const _UnlimitedClockBadge({
    required this.isActiveTurn,
    required this.playerTeam,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<String>(
      valueListenable: isActiveTurn,
      builder: (ctx, turn, _) {
        final isActive = turn == playerTeam;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryGreen.withValues(alpha: 0.15)
                : AppColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AppColors.primaryGreen
                  : AppColors.getBorder(isDark),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.all_inclusive_rounded,
            size: 18,
            color: isActive
                ? AppColors.primaryGreen
                : AppColors.getTextMuted(isDark),
          ),
        );
      },
    );
  }
}

