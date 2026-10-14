import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/friends_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/notifications/notification_tile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final notifProv = context.read<NotificationProvider>();
        notifProv.loadNotifications();
        notifProv.markInformationalAsRead();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifProv = context.watch<NotificationProvider>();
    final friendsProv = context.watch<FriendsProvider>();
    final hasUnreadNotifications =
        notifProv.hasUnread || friendsProv.pendingIncomingCount > 0;

    // Main notifications page:
    // Actionable notifications that have been interacted with (accepted, declined, or ignored)
    // are removed from the active view. Informational notifications remain visible and dimmed.
    final displayList = notifProv.allNotifications.where((n) {
      if (n.isActionable) {
        return n.isPending;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: KitaAppBar(
        title: 'notifications.title'.tr(),
        leadingIcon: hasUnreadNotifications
            ? Icons.notifications_active_rounded
            : Icons.notifications_none_rounded,
        iconColor: hasUnreadNotifications ? AppColors.primaryAmber : null,
        showBack: true,
        showAuthActions: false,
        showLanguageToggle: false,
        showThemeToggle: false,
      ),
      body: ResponsiveLayout(
        padding: EdgeInsets.zero,
        child: displayList.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 40,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'notifications.empty'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'notifications.placeholderDesc'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 4.0,
                ),
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final notif = displayList[index];
                  return NotificationTile(
                    key: ValueKey('page_${notif.id}'),
                    notification: notif,
                    compact: false,
                  );
                },
              ),
      ),
    );
  }
}
