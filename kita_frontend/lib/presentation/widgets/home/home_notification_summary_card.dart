import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/notification_provider.dart';
import '../../screens/home/notifications_screen.dart';
import '../notifications/notification_tile.dart';

class HomeNotificationSummaryCard extends StatelessWidget {
  const HomeNotificationSummaryCard({super.key});

  void _openNotificationsScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifProv = context.watch<NotificationProvider>();
    final summaryItems = notifProv.homeSummaryNotifications;

    // If there are no pending actionable notifications, render nothing (invisible)
    if (summaryItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalPending = notifProv.pendingNotifications.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (Clicking navigates to Main Notifications Page)
          InkWell(
            onTap: () => _openNotificationsScreen(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.accentGold,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'notifications.summaryTitle'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$totalPending',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'notifications.viewAll'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.accent : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: isDark ? AppColors.accent : AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Items List (Up to 3 pending notifications)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(
              children: summaryItems.map((item) {
                return NotificationTile(
                  key: ValueKey('summary_${item.id}'),
                  notification: item,
                  compact: true,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
