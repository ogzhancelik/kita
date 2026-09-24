import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/home/dashboard_action_dock.dart';
import '../../widgets/home/dashboard_friends_ribbon.dart';
import '../../widgets/home/dashboard_leaderboard_card.dart';
import '../../widgets/home/dashboard_match_history_card.dart';
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
      if (authProv.isAuthenticated && !authProv.isGuest) {
        notifProv.loadNotifications();
      }
      final onlineProv = context.read<OnlineGameProvider>();
      onlineProv.connectAndListen(
        token: authProv.token,
        nickname: authProv.displayName,
      );
      onlineProv.requestOnlineCount();
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
                    context.read<OnlineGameProvider>().requestRoomsList(page: 1, limit: 10);
                    await Future.wait([
                      context.read<AuthProvider>().refreshProfile(),
                      Future.delayed(const Duration(milliseconds: 200)),
                    ]);
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

                        // -1. Pending / Active Game Priority Section (Rejoin active game, open room, or pending challenge)
                        const HomePendingGameCard(),

                        // 0. Notification Summary Card (Max 3 actionable notifications, priority sorted)
                        const HomeNotificationSummaryCard(),

                        // 1. Leaderboard (Friends & Global TOP 3)
                        const DashboardLeaderboardCard(),
                        const SizedBox(height: 12),

                        // 2. Açık Odalar (5 Open Rooms + "Oda Kur")
                        const DashboardOpenRoomsCard(),
                        const SizedBox(height: 12),

                        // 3. Arkadaşlar & Quick Invitation Ribbon
                        const DashboardFriendsRibbon(),
                        if (!isGuest) const SizedBox(height: 12),

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
