import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../common/avatar_picker.dart';
import '../home/user_profile_dialog.dart';

/// Player/Opponent info bar with chess clock display.
///
/// Layout in Portrait mode:
/// - Opponent: Avatar, Name & ELO on the left; Clock on the right.
/// - Player: Clock on the left; Name, ELO & Avatar on the right.
///
/// Tapping the player's info bar opens the User Profile modal sheet.
/// Spans full width with zero outer page margins and equal horizontal padding inside.
class PlayerInfoBar extends StatelessWidget {
  final bool isOpponent;
  final String name;
  final int rating;
  final String? ratingLabel;
  final String team; // "white" or "black"
  final ValueNotifier<int> remainingMs;
  final ValueNotifier<String> isActiveTurn;
  final int timeControl;
  final int? avatarIndex;
  final VoidCallback? onTap;

  const PlayerInfoBar({
    super.key,
    required this.isOpponent,
    required this.name,
    required this.rating,
    this.ratingLabel,
    required this.team,
    required this.remainingMs,
    required this.isActiveTurn,
    required this.timeControl,
    this.avatarIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWhite = team == 'white';
    final teamColor = isWhite ? Colors.white : const Color(0xFF222222);

    final authProv = context.watch<AuthProvider>();
    final int avatarIdx = avatarIndex ??
        (isOpponent
            ? (name.hashCode.abs() % AvatarPicker.avatars.length)
            : authProv.avatarIndex);
    final avatarItem = AvatarPicker.avatars[avatarIdx % AvatarPicker.avatars.length];

    final avatarWidget = Container(
      width: 34,
      height: 34,
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
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          avatarItem.icon,
          size: 18,
          color: avatarItem.accentColor,
        ),
      ),
    );

    final nameAndRatingWidget = Column(
      crossAxisAlignment:
          isOpponent ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.ratingGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            ratingLabel ?? '$rating',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.ratingGold,
            ),
          ),
        ),
      ],
    );

    final clockWidget = timeControl > 0
        ? _ChessClock(
            remainingMs: remainingMs,
            isActiveTurn: isActiveTurn,
            playerTeam: team,
          )
        : _UnlimitedClockBadge(
            isActiveTurn: isActiveTurn,
            playerTeam: team,
          );

    final content = InkWell(
      onTap: onTap ??
          (!isOpponent
              ? () => UserProfileDialog.show(context)
              : null),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: isOpponent
            ? Row(
                children: [
                  avatarWidget,
                  const SizedBox(width: 10),
                  Expanded(child: nameAndRatingWidget),
                  const SizedBox(width: 10),
                  clockWidget,
                ],
              )
            : Row(
                children: [
                  clockWidget,
                  const SizedBox(width: 10),
                  Expanded(child: nameAndRatingWidget),
                  const SizedBox(width: 10),
                  avatarWidget,
                ],
              ),
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        border: Border(
          bottom: isOpponent
              ? BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.8,
                )
              : BorderSide.none,
          top: !isOpponent
              ? BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.8,
                )
              : BorderSide.none,
        ),
      ),
      child: content,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: bgColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 16,
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
            size: 16,
            color: isActive
                ? AppColors.primaryGreen
                : AppColors.getTextMuted(isDark),
          ),
        );
      },
    );
  }
}
