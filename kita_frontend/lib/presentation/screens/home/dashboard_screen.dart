import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/local_match_history_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/home/dashboard_action_dock.dart';
import '../../widgets/home/dashboard_friends_ribbon.dart';
import '../../widgets/home/dashboard_leaderboard_card.dart';
import '../../widgets/home/dashboard_match_history_card.dart';
import '../../widgets/home/dashboard_offline_play_card.dart';
import '../../widgets/home/dashboard_open_rooms_card.dart';
import '../../widgets/home/dashboard_top_bar.dart';
import '../../widgets/home/home_notification_summary_card.dart';
import '../../widgets/home/home_pending_game_card.dart';
import '../../widgets/home/play_menu_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProv = context.read<AuthProvider>();
      final notifProv = context.read<NotificationProvider>();
      notifProv.setDashboardActive(true);
      if (authProv.isAuthenticated && !authProv.isGuest && !authProv.isOffline) {
        notifProv.loadNotifications();
      }
      if (!authProv.isOffline) {
        final onlineProv = context.read<OnlineGameProvider>();
        onlineProv.connectAndListen(
          token: authProv.token,
          nickname: authProv.displayName,
          avatarIndex: authProv.avatarIndex,
        );
        onlineProv.requestOnlineCount();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openPlayMenu() {
    PlayMenuDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = context.watch<AuthProvider>();
    final isGuest = authProv.isGuest;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: ResponsiveLayout(
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: Column(
            children: [
              // --- 1. Top Panel (Profile + Notifications + Settings) ---
              const DashboardTopBar(),

              // --- 2. Scrollable Middle Panel ---
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    final currentAuth = context.read<AuthProvider>();
                    if (currentAuth.isOffline) {
                      await currentAuth.retryConnection();
                    }
                    if (!currentAuth.isOffline) {
                      context.read<OnlineGameProvider>().requestRoomsList(page: 1, limit: 10);
                      await currentAuth.refreshProfile();
                    }
                    LocalMatchHistoryService.instance.notifyMatchesChanged();
                    await Future.delayed(const Duration(milliseconds: 200));
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 4.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Guest Notice Banner (if guest)
                        if (isGuest) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.guestOrange.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.guestOrange.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.guestOrange,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'dashboard.guestNotice'.tr(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.guestOrange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Offline Notice Banner (if offline)
                        if (authProv.isOffline) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.warning.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.wifi_off_rounded,
                                  color: AppColors.warning,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'dashboard.offlineNotice'.tr(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: authProv.isRetryingConnection
                                      ? null
                                      : () async {
                                          final success = await authProv.retryConnection();
                                          if (success && context.mounted) {
                                            final onlineProv = context.read<OnlineGameProvider>();
                                            onlineProv.connectAndListen(
                                              token: authProv.token,
                                              nickname: authProv.displayName,
                                              avatarIndex: authProv.avatarIndex,
                                            );
                                            onlineProv.requestOnlineCount();
                                            if (authProv.isAuthenticated && !authProv.isGuest) {
                                              context.read<NotificationProvider>().loadNotifications();
                                              context.read<FriendsProvider>().loadAll();
                                            }
                                          }
                                        },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.warning.withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (authProv.isRetryingConnection) ...[
                                          const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                AppColors.warning,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                        ] else ...[
                                          const Icon(
                                            Icons.refresh_rounded,
                                            size: 14,
                                            color: AppColors.warning,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          authProv.isRetryingConnection
                                              ? 'dashboard.retrying'.tr()
                                              : 'dashboard.retry'.tr(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.warning,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // -1. Pending / Active Game Priority Section (Rejoin active game, open room, or pending challenge)
                        const HomePendingGameCard(),

                        // 0. Notification Summary Card (Max 3 actionable notifications, priority sorted)
                        if (!authProv.isOffline)
                          const HomeNotificationSummaryCard(),

                        // 1. Leaderboard (Friends & Global TOP 3) - Only when online
                        if (!authProv.isOffline) ...[
                          const DashboardLeaderboardCard(),
                          const SizedBox(height: 12),
                        ],

                        // 2. Open Rooms & Friends when online, or Play vs Computer / Offline Games when offline
                        if (!authProv.isOffline) ...[
                          const DashboardOpenRoomsCard(),
                          const SizedBox(height: 12),
                          const DashboardFriendsRibbon(),
                          if (!isGuest) const SizedBox(height: 12),
                        ] else ...[
                          const DashboardOfflinePlayCard(),
                          const SizedBox(height: 12),
                        ],

                        // 4. Maç Geçmişi Listesi & Replay Viewer
                        const DashboardMatchHistoryCard(),

                        // Bottom Spacing for Floating/Docked Action Buttons
                        const SizedBox(height: 85),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      floatingActionButton: DashboardActionDock(
        onHome: _scrollToTop,
        onPlay: _openPlayMenu,
      ),
    );
  }
}
