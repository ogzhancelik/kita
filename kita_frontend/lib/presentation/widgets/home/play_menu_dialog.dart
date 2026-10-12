import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/feedback/toast_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/offline_game_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../screens/friends/friends_screen.dart';
import '../../screens/game/offline_match_screen.dart';
import '../game/vs_ai_config_dialog.dart';
import '../matchmaking/activity_conflict_dialog.dart';
import '../matchmaking/matchmaking_sheet.dart';
import '../room/room_dialog.dart';

class PlayMenuDialog extends StatelessWidget {
  const PlayMenuDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PlayMenuDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onlineProv = context.watch<OnlineGameProvider>();
    final offlineProv = context.watch<OfflineGameProvider>();
    final authProv = context.watch<AuthProvider>();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
        maxWidth: 520,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(
                      'dashboard.playMenu'.tr(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Offline / Server Down Notice Banner
                    if (authProv.isOnlineUnavailable) ...[
                      _buildUnavailableBanner(authProv),
                      const SizedBox(height: 12),
                    ],

                    // Mode 1: Rooms (Create & Join) - Default way to play
                    _wrapUnavailable(
                      isUnavailable: authProv.isOnlineUnavailable,
                      child: _buildRoomsActionRow(context, onlineProv, authProv, isDark),
                    ),
                    const SizedBox(height: 12),

                    // Mode 2: VS Computer AI
                    _buildActionCard(
                      context: context,
                      title: 'dashboard.playAI'.tr(),
                      icon: Icons.smart_toy_rounded,
                      iconBg: AppColors.primaryGreen,
                      badge: 'dashboard.badgeOffline'.tr(),
                      badgeColor: AppColors.primaryGreen,
                      isDark: isDark,
                      onTap: () {
                        Navigator.of(context).pop();
                        VsAiConfigDialog.show(context);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Mode 3: Local Pass & Play (Co-op)
                    _buildActionCard(
                      context: context,
                      title: 'game.localCoopTitle'.tr(),
                      icon: Icons.people_outline_rounded,
                      iconBg: AppColors.accent,
                      badge: 'dashboard.badgeOffline'.tr(),
                      badgeColor: AppColors.accent,
                      isDark: isDark,
                      onTap: () async {
                        if (offlineProv.hasActiveMatch) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              backgroundColor: AppColors.getCard(isDark),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text(
                                'online.conflictDialogTitle'.tr(),
                                style: TextStyle(
                                  color: AppColors.getTextPrimary(isDark),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: Text(
                                'online.conflictAbandonOfflineDesc'.tr(),
                                style: TextStyle(
                                  color: AppColors.getTextSecondary(isDark),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                                  child: Text(
                                    'common.cancel'.tr(),
                                    style: TextStyle(color: AppColors.getTextSecondary(isDark)),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                                  child: Text('online.abandonAndProceed'.tr()),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          offlineProv.resignAndClear();
                        }

                        offlineProv.startOfflineMatch(
                          mode: PlayMode.localCoop,
                          playerId: authProv.currentUser?.id,
                          playerName: authProv.currentUser?.username ??
                              authProv.guestProfile?.nickname ??
                              'Guest',
                          playerAvatarIndex: authProv.currentUser?.avatarIndex ??
                              authProv.guestProfile?.avatarIndex ??
                              0,
                          isGuest: authProv.isGuest || authProv.currentUser == null,
                        );

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const OfflineMatchScreen(),
                              settings: const RouteSettings(name: '/offline_match'),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Mode 4: Matchmaking (Find Match - just above Friends)
                    _wrapUnavailable(
                      isUnavailable: authProv.isOnlineUnavailable,
                      child: _buildMatchmakingCard(context, onlineProv, authProv, isDark),
                    ),
                    const SizedBox(height: 12),

                    // Mode 5: Friends & Challenges
                    _wrapUnavailable(
                      isUnavailable: authProv.isOnlineUnavailable,
                      child: _buildActionCard(
                        context: context,
                        title: 'dashboard.friends'.tr(),
                        icon: Icons.person_search_rounded,
                        iconBg: AppColors.accentGold,
                        isDark: isDark,
                        onTap: () {
                          if (authProv.isOnlineUnavailable) {
                            KitaToast.warning(authProv.isOffline
                                ? 'dashboard.offlineNotice'.tr()
                                : 'dashboard.serverDownNotice'.tr());
                            return;
                          }
                          authProv.guardAction(context, () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FriendsScreen(),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapUnavailable({
    required bool isUnavailable,
    required Widget child,
  }) {
    if (!isUnavailable) return child;
    return Opacity(
      opacity: 0.45,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: child,
      ),
    );
  }

  Widget _buildMatchmakingCard(
    BuildContext context,
    OnlineGameProvider onlineProv,
    AuthProvider authProv,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (authProv.isOnlineUnavailable) {
            KitaToast.warning(authProv.isOffline
                ? 'dashboard.offlineNotice'.tr()
                : 'dashboard.serverDownNotice'.tr());
            return;
          }
          final canProceed = await ActivityConflictHelper.checkAndConfirm(
            context: context,
            provider: onlineProv,
          );
          if (!canProceed) {
            if (context.mounted) Navigator.of(context).pop();
            return;
          }

          if (context.mounted) {
            Navigator.of(context).pop();
            MatchmakingSheet.show(context);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.guestOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.guestOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'dashboard.findMatch'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder(
                      valueListenable: onlineProv.onlineCount,
                      builder: (ctx, count, _) {
                        final total = count?.totalOnline ?? 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.guestOrange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$total ${'dashboard.badgeOnline'.tr()}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.guestOrange,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomsActionRow(
    BuildContext context,
    OnlineGameProvider onlineProv,
    AuthProvider authProv,
    bool isDark,
  ) {
    return Row(
      children: [
        // Create Room
        Expanded(
          child: _buildSquareRoomCard(
            context: context,
            title: 'dashboard.createRoom'.tr(),
            icon: Icons.meeting_room_rounded,
            accentColor: AppColors.ratingGold,
            isDark: isDark,
            onTap: () async {
              if (authProv.isOnlineUnavailable) {
                KitaToast.warning(authProv.isOffline
                    ? 'dashboard.offlineNotice'.tr()
                    : 'dashboard.serverDownNotice'.tr());
                return;
              }
              final canProceed = await ActivityConflictHelper.checkAndConfirm(
                context: context,
                provider: onlineProv,
              );
              if (!canProceed) {
                if (context.mounted) Navigator.of(context).pop();
                return;
              }

              if (context.mounted) {
                Navigator.of(context).pop();
                CreateRoomDialog.show(context);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        // Join with Code
        Expanded(
          child: _buildSquareRoomCard(
            context: context,
            title: 'online.joinRoom'.tr(),
            icon: Icons.vpn_key_rounded,
            accentColor: isDark ? AppColors.accent : AppColors.accentSecondary,
            isDark: isDark,
            onTap: () async {
              if (authProv.isOnlineUnavailable) {
                KitaToast.warning(authProv.isOffline
                    ? 'dashboard.offlineNotice'.tr()
                    : 'dashboard.serverDownNotice'.tr());
                return;
              }
              final canProceed = await ActivityConflictHelper.checkAndConfirm(
                context: context,
                provider: onlineProv,
              );
              if (!canProceed) {
                if (context.mounted) Navigator.of(context).pop();
                return;
              }

              if (context.mounted) {
                Navigator.of(context).pop();
                JoinRoomDialog.show(context);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSquareRoomCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : AppColors.lightBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.4 : 0.45),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconBg,
    String? badge,
    Color? badgeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : AppColors.lightBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconBg, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.primaryGreen).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: badgeColor ?? AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailableBanner(AuthProvider authProv) {
    final isServerDown = !authProv.isOffline && authProv.isServerDown;
    final color = isServerDown ? AppColors.error : AppColors.warning;
    final icon = isServerDown ? Icons.cloud_off_rounded : Icons.wifi_off_rounded;
    final text = isServerDown
        ? 'dashboard.serverDownNotice'.tr()
        : 'dashboard.offlineNotice'.tr();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
