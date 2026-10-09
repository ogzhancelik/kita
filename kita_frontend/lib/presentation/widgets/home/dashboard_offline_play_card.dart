import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/offline_game_provider.dart';
import '../../screens/game/offline_match_screen.dart';
import '../common/kita_card.dart';
import '../game/vs_ai_config_dialog.dart';

class DashboardOfflinePlayCard extends StatelessWidget {
  const DashboardOfflinePlayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final offlineProv = context.watch<OfflineGameProvider>();
    final authProv = context.watch<AuthProvider>();

    return KitaCard(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Offline Games with OFFLINE READY badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sports_esports_rounded,
                      color: AppColors.accentSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'dashboard.offlinePlayTitle'.tr(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'dashboard.badgeOffline'.tr(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryLight,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal mode options (Side by Side, like friends tab)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Option 1: Play vs Computer (AI Engine)
                Expanded(
                  child: _buildPlayOption(
                    context: context,
                    title: 'dashboard.playAI'.tr(),
                    icon: Icons.smart_toy_rounded,
                    iconColor: AppColors.primaryLight,
                    iconBg: AppColors.primary.withValues(alpha: 0.2),
                    isDark: isDark,
                    onTap: () {
                      VsAiConfigDialog.show(context);
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Option 2: Local 2P Co-op (Pass & Play)
                Expanded(
                  child: _buildPlayOption(
                    context: context,
                    title: 'game.localCoopTitle'.tr(),
                    icon: Icons.people_outline_rounded,
                    iconColor: AppColors.accent,
                    iconBg: AppColors.accent.withValues(alpha: 0.18),
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
                                  'online.cancel'.tr(),
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
                        isGuest: authProv.isGuest || authProv.currentUser == null,
                      );

                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OfflineMatchScreen(),
                            settings: const RouteSettings(name: '/offline_match'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(height: 8),

                // Name
                SizedBox(
                  height: 34,
                  child: Center(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Play Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: onTap,
                  child: Text(
                    'dashboard.playAction'.tr(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
