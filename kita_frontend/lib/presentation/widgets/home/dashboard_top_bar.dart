import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dm_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/notification_provider.dart';
import '../../screens/home/notifications_screen.dart';
import '../common/avatar_picker.dart';
import '../common/stat_badge.dart';
import '../../screens/chat/chats_screen.dart';
import 'settings_dialog.dart';
import 'user_profile_dialog.dart';

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = context.watch<AuthProvider>();
    final friendsProv = context.watch<FriendsProvider>();
    final notifProv = context.watch<NotificationProvider>();
    final dmProv = Provider.of<DmProvider?>(context);
    final user = authProv.currentUser;
    final isGuest = authProv.isGuest;

    final avatarItem = AvatarPicker.avatars[authProv.avatarIndex % AvatarPicker.avatars.length];
    final hasUnreadChats = (dmProv?.totalUnread ?? 0) > 0;
    final hasUnreadNotifications = notifProv.hasUnread ||
        friendsProv.pendingIncomingCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sol Üst: Profil Fotoğrafı, İsim, ELO Container'ı
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => UserProfileDialog.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: avatarItem.accentColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: avatarItem.accentColor,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        avatarItem.icon,
                        color: avatarItem.accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // İsim & ELO
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            authProv.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          StatBadge(
                            rating: user?.rating ?? 1200,
                            isGuest: isGuest,
                            isProvisional: user?.isProvisional ?? true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Sağ Üst: Bildirimler, Sohbet & Ayarlar Sembolleri
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bildirim Sembolü
              _buildActionIcon(
                icon: hasUnreadNotifications
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: hasUnreadNotifications
                    ? AppColors.primaryGreen
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                tooltip: 'notifications.title'.tr(),
                hasBadge: hasUnreadNotifications,
                isDark: isDark,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),

              // Sohbet Sembolü
              _buildActionIcon(
                icon: hasUnreadChats
                    ? Icons.chat_bubble_rounded
                    : Icons.chat_bubble_outline_rounded,
                color: hasUnreadChats
                    ? AppColors.primaryGreen
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                tooltip: 'chats.title'.tr(),
                hasBadge: hasUnreadChats,
                isDark: isDark,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChatsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),

              // Ayarlar Sembolü
              _buildActionIcon(
                icon: Icons.settings_outlined,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                tooltip: 'settings.title'.tr(),
                hasBadge: false,
                isDark: isDark,
                onTap: () => SettingsDialog.show(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    required bool hasBadge,
    required bool isDark,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: tooltip,
          child: InkResponse(
            onTap: onTap,
            radius: 18,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
          ),
        ),
        if (hasBadge)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
