import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../widgets/common/avatar_picker.dart';
import '../../widgets/common/kita_app_bar.dart';
import '../../widgets/common/kita_card.dart';
import '../../widgets/common/responsive_layout.dart';
import '../../widgets/common/stat_badge.dart';
import '../../widgets/matchmaking/matchmaking_sheet.dart';
import '../../widgets/room/room_dialog.dart';
import '../friends/friends_screen.dart';
import '../game/offline_ai_screen.dart';
import '../room/room_browser_screen.dart';
import 'leaderboard_screen.dart';
import 'match_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProv = context.read<AuthProvider>();
      final onlineProv = context.read<OnlineGameProvider>();
      onlineProv.connectAndListen(
        token: authProv.token,
        nickname: authProv.displayName,
      );
      onlineProv.requestOnlineCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = context.watch<AuthProvider>();
    final onlineProv = context.watch<OnlineGameProvider>();
    final user = authProv.currentUser;
    final isGuest = authProv.isGuest;

    final avatarItem = AvatarPicker
        .avatars[authProv.avatarIndex % AvatarPicker.avatars.length];

    return Scaffold(
      appBar: const KitaAppBar(showAuthActions: true),
      body: ResponsiveLayout(
        child: RefreshIndicator(
          onRefresh: () => context.read<AuthProvider>().refreshProfile(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- 1. Player Profile Header Card ---
                  KitaCard(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Avatar
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: avatarItem.accentColor.withValues(
                                  alpha: 0.2,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: avatarItem.accentColor,
                                  width: 2.5,
                                ),
                              ),
                              child: Icon(
                                avatarItem.icon,
                                color: avatarItem.accentColor,
                                size: 34,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Name and Badges
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authProv.displayName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      StatBadge(
                                        rating: user?.rating ?? 1200,
                                        isGuest: isGuest,
                                      ),
                                      const SizedBox(width: 8),
                                      RecordChip(
                                        wins: user?.wins ?? 0,
                                        draws: user?.draws ?? 0,
                                        losses: user?.losses ?? 0,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (!isGuest && user != null) ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn(
                                'dashboard.totalGames'.tr(),
                                '${user.totalGames}',
                                isDark,
                              ),
                              _buildStatColumn(
                                'dashboard.winRate'.tr(),
                                '${user.winRate.toStringAsFixed(1)}%',
                                isDark,
                              ),
                              _buildStatColumn(
                                'dashboard.rating'.tr(),
                                '${user.rating}',
                                isDark,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- 2. Guest Notice Banner (if guest) ---
                  if (isGuest) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.guestOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.guestOrange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.guestOrange,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'dashboard.guestNotice'.tr(),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.guestOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // --- 3. Quick Play Header + Live Online Count ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'dashboard.quickActions'.tr(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      ValueListenableBuilder(
                        valueListenable: onlineProv.onlineCount,
                        builder: (ctx, count, _) {
                          final total = count?.totalOnline ?? 1;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$total ${'dashboard.onlinePlayers'.tr()}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Mode 1: Play vs AI (Single-player engine, always works)
                  _buildModeCard(
                    context: context,
                    title: 'dashboard.playAI'.tr(),
                    subtitle: 'game.offlineAIDesc'.tr(),
                    icon: Icons.smart_toy_rounded,
                    iconBg: AppColors.primaryGreen,
                    badgeText: 'dashboard.badgeOffline'.tr(),
                    badgeColor: AppColors.primaryGreen,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OfflineAiScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Mode 2: Find Match (Queue pool)
                  _buildModeCard(
                    context: context,
                    title: 'dashboard.findMatch'.tr(),
                    subtitle: 'dashboard.findMatchDesc'.tr(),
                    icon: Icons.bolt_rounded,
                    iconBg: AppColors.guestOrange,
                    badgeText: 'dashboard.badgeOnline'.tr(),
                    badgeColor: AppColors.guestOrange,
                    onTap: () {
                      MatchmakingSheet.show(context);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Mode 3: Create Room / Custom Match
                  _buildModeCard(
                    context: context,
                    title: 'dashboard.createRoom'.tr(),
                    subtitle: 'dashboard.createRoomDesc'.tr(),
                    icon: Icons.meeting_room_rounded,
                    iconBg: AppColors.ratingGold,
                    onTap: () {
                      CreateRoomDialog.show(context);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Mode 4: Browse Public Rooms
                  _buildModeCard(
                    context: context,
                    title: 'online.browseRooms'.tr(),
                    subtitle: 'online.browseRoomsDesc'.tr(),
                    icon: Icons.travel_explore_rounded,
                    iconBg: AppColors.winBlue,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RoomBrowserScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Mode 5: Friends & Direct Challenges (GATED FOR GUEST!)
                  _buildModeCard(
                    context: context,
                    title: 'dashboard.friends'.tr(),
                    subtitle: 'dashboard.friendsDesc'.tr(),
                    icon: Icons.people_alt_rounded,
                    iconBg: AppColors.accentGold,
                    isGated: isGuest,
                    onTap: () {
                      authProv.guardAction(context, () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FriendsScreen(),
                          ),
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Mode 6: Join with Code
                  _buildModeCard(
                    context: context,
                    title: 'online.joinRoom'.tr(),
                    subtitle: 'online.privateRoomDesc'.tr(),
                    icon: Icons.vpn_key_rounded,
                    iconBg: AppColors.drawGray,
                    onTap: () {
                      JoinRoomDialog.show(context);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Mode 7: Leaderboard
                  _buildModeCard(
                    context: context,
                    title: 'dashboard.leaderboard'.tr(),
                    subtitle: 'dashboard.leaderboardDesc'.tr(),
                    icon: Icons.leaderboard_rounded,
                    iconBg: AppColors.ratingGold,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LeaderboardScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Mode 7: Match History & Replay
                  _buildModeCard(
                    context: context,
                    title: 'dashboard.matchHistory'.tr(),
                    subtitle: 'dashboard.matchHistoryDesc'.tr(),
                    icon: Icons.history_edu_rounded,
                    iconBg: isDark ? AppColors.primaryVibrant : AppColors.primary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MatchHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
    bool isGated = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return KitaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: iconBg.withValues(alpha: 0.4),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.darkTextPrimary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (isGated) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: AppColors.guestOrange,
                      ),
                    ],
                    if (badgeText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? AppColors.primaryGreen)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: badgeColor ?? AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            size: 22,
          ),
        ],
      ),
    );
  }
}
