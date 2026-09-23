import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/notification_provider.dart';
import '../../screens/home/notifications_screen.dart';
import '../common/avatar_picker.dart';
import '../common/stat_badge.dart';
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
    final user = authProv.currentUser;
    final isGuest = authProv.isGuest;

    final avatarItem = AvatarPicker.avatars[authProv.avatarIndex % AvatarPicker.avatars.length];
    final hasUnreadNotifications = notifProv.hasUnread || friendsProv.pendingIncomingCount > 0;

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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Sağ Üst: Bildirimler & Ayarlar Butonları
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bildirim Butonu
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasUnreadNotifications
                            ? AppColors.primaryGreen
                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        width: hasUnreadNotifications ? 1.5 : 1,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        hasUnreadNotifications
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: hasUnreadNotifications
                            ? AppColors.primaryGreen
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        size: 20,
                      ),
                      tooltip: 'notifications.title'.tr(),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  if (hasUnreadNotifications)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),

              // Ayarlar Butonu
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    size: 20,
                  ),
                  tooltip: 'settings.title'.tr(),
                  onPressed: () => SettingsDialog.show(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
