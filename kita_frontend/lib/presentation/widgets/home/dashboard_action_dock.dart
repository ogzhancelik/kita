import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class DashboardActionDock extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback? onHome;

  const DashboardActionDock({
    super.key,
    required this.onPlay,
    this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth < 500 ? screenWidth - 32 : 360.0;

    return SafeArea(
      child: Container(
        width: buttonWidth,
        height: 54,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.4 : 0.25),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: AppColors.primaryGreen.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          onPressed: onPlay,
          icon: const Icon(
            Icons.sports_esports_rounded,
            size: 26,
            color: Colors.white,
          ),
          label: Text(
            'dashboard.playAction'.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
