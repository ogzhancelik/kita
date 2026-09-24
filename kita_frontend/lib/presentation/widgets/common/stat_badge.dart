import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class StatBadge extends StatelessWidget {
  final int rating;
  final bool isGuest;

  const StatBadge({
    super.key,
    required this.rating,
    this.isGuest = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.guestOrange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.guestOrange, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.guestOrange),
            const SizedBox(width: 4),
            Text(
              'guest.badge'.tr(),
              style: const TextStyle(
                color: AppColors.guestOrange,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.ratingGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ratingGold, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, size: 14, color: AppColors.ratingGold),
          const SizedBox(width: 4),
          Text(
            '$rating',
            style: const TextStyle(
              color: AppColors.ratingGold,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class RecordChip extends StatelessWidget {
  final int wins;
  final int draws;
  final int losses;

  const RecordChip({
    super.key,
    required this.wins,
    required this.draws,
    required this.losses,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildItem('${wins}W', AppColors.winStat),
          _buildDivider(isDark),
          _buildItem('${draws}D', AppColors.drawGray),
          _buildDivider(isDark),
          _buildItem('${losses}L', AppColors.lossRed),
        ],
      ),
    );
  }

  Widget _buildItem(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '/',
        style: TextStyle(
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          fontSize: 11,
        ),
      ),
    );
  }
}
