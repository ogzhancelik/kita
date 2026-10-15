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

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final notifProv = context.read<NotificationProvider>();
        notifProv.loadNotifications();
        notifProv.markInformationalAsRead();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh(NotificationProvider notifProv) async {
    await Future.wait([
      notifProv.loadNotifications(),
      context.read<FriendsProvider>().loadAll(),
    ]);
  }

  Widget _buildFilterSelector(bool isDark, int pendingCount) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: AnimatedBuilder(
        animation: _tabController.animation ?? _tabController,
        builder: (context, _) {
          final animValue =
              _tabController.animation?.value ?? _tabController.index.toDouble();
          final t = animValue.clamp(0.0, 1.0);

          return LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / 2;

              return Stack(
                children: [
                  // Smooth sliding indicator pill
                  Positioned(
                    left: t * tabWidth,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryAmber,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primaryAmber.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab interactive labels on top
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterTabItem(
                          label: 'notifications.filterAll'.tr(),
                          icon: Icons.notifications_rounded,
                          activeProgress: 1.0 - t,
                          onTap: () => _tabController.animateTo(0),
                          isDark: isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildFilterTabItem(
                          label: 'notifications.filterRequests'.tr(),
                          icon: Icons.mail_outline_rounded,
                          activeProgress: t,
                          badgeCount: pendingCount,
                          onTap: () => _tabController.animateTo(1),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterTabItem({
    required String label,
    required IconData icon,
    required double activeProgress,
    required VoidCallback onTap,
    required bool isDark,
    int badgeCount = 0,
  }) {
    final activeColor = AppColors.darkTextPrimary;
    final inactiveColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final color = Color.lerp(inactiveColor, activeColor, activeProgress)!;
    final badgeBg =
        Color.lerp(AppColors.lossRed, Colors.white, activeProgress)!;
    final badgeFg =
        Color.lerp(Colors.white, AppColors.primaryAmberDark, activeProgress)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppColors.primaryAmber.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: activeProgress > 0.5
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 10,
                      color: badgeFg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifProv = context.watch<NotificationProvider>();
    final friendsProv = context.watch<FriendsProvider>();

    final pendingNotifications = notifProv.pendingNotifications;
    final totalPendingRequests = pendingNotifications.isNotEmpty
        ? pendingNotifications.length
        : friendsProv.pendingIncomingCount;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: KitaAppBar(
        title: 'notifications.title'.tr(),
        iconColor: AppColors.accentGold,
        leadingIcon: Icons.notifications_rounded,
        showBack: true,
        showAuthActions: false,
        showLanguageToggle: false,
        showThemeToggle: false,
      ),
      body: ResponsiveLayout(
        maxWidth: 640,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildFilterSelector(isDark, totalPendingRequests),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllTab(context, notifProv, isDark),
                  _buildRequestsTab(context, notifProv, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTab(
    BuildContext context,
    NotificationProvider notifProv,
    bool isDark,
  ) {
    final displayList = notifProv.allNotifications.where((n) {
      if (n.isActionable) {
        return n.isPending;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      color: AppColors.primaryAmber,
      onRefresh: () => _handleRefresh(notifProv),
      child: displayList.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primaryAmber.withValues(
                                alpha: 0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              size: 40,
                              color: AppColors.accentGold,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'notifications.empty'.tr(),
                            style: TextStyle(
                              fontSize: 17,
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
                              fontSize: 14,
                              color: AppColors.getTextSecondary(isDark),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
    );
  }

  Widget _buildRequestsTab(
    BuildContext context,
    NotificationProvider notifProv,
    bool isDark,
  ) {
    final pendingList = notifProv.pendingNotifications;

    return RefreshIndicator(
      color: AppColors.primaryAmber,
      onRefresh: () => _handleRefresh(notifProv),
      child: pendingList.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primaryAmber.withValues(
                                alpha: 0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mail_outline_rounded,
                              size: 40,
                              color: AppColors.accentGold,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'notifications.noRequests'.tr(),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'notifications.noRequestsDesc'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.getTextSecondary(isDark),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: pendingList.length,
              itemBuilder: (context, index) {
                final notif = pendingList[index];
                return NotificationTile(
                  key: ValueKey('page_req_${notif.id}'),
                  notification: notif,
                  compact: false,
                );
              },
            ),
    );
  }
}
