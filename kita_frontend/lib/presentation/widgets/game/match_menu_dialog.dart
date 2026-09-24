import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/feedback/toast_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/online_game_provider.dart';
import '../home/settings_dialog.dart';
import '../../screens/game/match_replay_screen.dart';
import 'game_over_dialog.dart';

/// Modal bottom sheet for match actions: Resign, Offer Draw, Report Opponent.
class MatchMenuDialog extends StatelessWidget {
  const MatchMenuDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MatchMenuDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnlineGameProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth: 520,
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: AppColors.getBorder(isDark),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'online.matchMenu'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (provider.isOffline && provider.gameOverData.value == null) ...[
              // Offline: New Game option
              _MenuTile(
                icon: Icons.replay_rounded,
                iconColor: AppColors.primaryGreen,
                title: 'game.newGame'.tr(),
                textColor: AppColors.getTextPrimary(isDark),
                onTap: () {
                  Navigator.of(context).pop();
                  provider.requestRematch();
                },
              ),

            ],

            // Return to Main Menu (leave game running in background)
            _MenuTile(
              icon: Icons.home_rounded,
              iconColor: AppColors.accentGold,
              title: 'online.returnToMenu'.tr(),
              subtitle: 'online.returnToMenuDesc'.tr(),
              textColor: AppColors.getTextPrimary(isDark),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),

            if (provider.gameOverData.value != null) ...[
              // Match is over: Show Results
              _MenuTile(
                icon: Icons.analytics_outlined,
                iconColor: AppColors.accentGold,
                title: 'online.showResults'.tr(),
                textColor: AppColors.getTextPrimary(isDark),
                onTap: () {
                  Navigator.of(context).pop();
                  final data = provider.gameOverData.value;
                  if (data != null) {
                    GameOverDialog.show(
                      context: context,
                      gameOverData: data,
                      myUserId: provider.myUserId ?? '',
                      onRematch: () => provider.requestRematch(),
                      onBackToMenu: () {
                        provider.resetToIdle();
                        context.read<AuthProvider>().refreshProfile();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      onReviewMatch: (provider.isOffline && provider.offlinePlayMode == PlayMode.vsAi)
                          ? () {
                              final matchRecord = provider.lastOfflineMatchRecord ??
                                  provider.buildCurrentOfflineMatchRecord(data);
                              if (matchRecord != null) {
                                Navigator.of(context, rootNavigator: true).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MatchReplayScreen(match: matchRecord),
                                  ),
                                );
                              }
                            }
                          : null,
                    );
                  }
                },
              ),
              if (!provider.isRematchRequested.value)
                _MenuTile(
                  icon: Icons.replay_rounded,
                  iconColor: AppColors.primaryGreen,
                  title: 'online.rematch'.tr(),
                  textColor: AppColors.getTextPrimary(isDark),
                  onTap: () {
                    Navigator.of(context).pop();
                    provider.requestRematch();
                  },
                ),
            ] else ...[
              // Resign option
              _MenuTile(
                icon: Icons.flag_outlined,
                iconColor: AppColors.lossRed,
                title: 'online.resign'.tr(),
                textColor: AppColors.lossRed,
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmResign(context, provider);
                },
              ),

              if (!provider.isOffline) ...[
                // Online: Offer Draw option
                _MenuTile(
                  icon: Icons.handshake_outlined,
                  iconColor: AppColors.primaryGreen,
                  title: 'online.drawOffer'.tr(),
                  textColor: AppColors.getTextPrimary(isDark),
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmDrawOffer(context, provider);
                  },
                ),
              ],
            ],

            if (!provider.isOffline) ...[
              // Online: Report Opponent option
              _MenuTile(
                icon: Icons.report_problem_outlined,
                iconColor: AppColors.warning,
                title: 'online.reportOpponent'.tr(),
                textColor: AppColors.getTextPrimary(isDark),
                onTap: () {
                  Navigator.of(context).pop();
                  _showReportDialog(context);
                },
              ),
            ],

            // Rotate Board option
            Builder(
              builder: (context) {
                final gameSettings = context.watch<GameSettingsProvider>();
                final isHorizontal = gameSettings.isHorizontal;
                return _MenuTile(
                  icon: Icons.rotate_90_degrees_cw_rounded,
                  iconColor: AppColors.primaryGreen,
                  title: 'online.rotateBoard'.tr(),
                  subtitle: isHorizontal
                      ? 'game.orientationHorizontal'.tr()
                      : 'game.orientationVertical'.tr(),
                  textColor: AppColors.getTextPrimary(isDark),
                  onTap: () {
                    gameSettings.toggleOrientation();
                  },
                );
              },
            ),

            // Settings option
            _MenuTile(
              icon: Icons.settings_rounded,
              iconColor: AppColors.primaryGreen,
              title: 'settings.title'.tr(),
              subtitle: 'settings.matchSettingsDesc'.tr(),
              textColor: AppColors.getTextPrimary(isDark),
              onTap: () {
                Navigator.of(context).pop();
                SettingsDialog.show(context);
              },
            ),

            const SizedBox(height: 8),
            // Cancel button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.getTextSecondary(isDark),
                  side: BorderSide(color: AppColors.getBorder(isDark)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('online.cancel'.tr()),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _confirmResign(BuildContext context, OnlineGameProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'online.resignTitle'.tr(),
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'online.resignConfirm'.tr(),
          style: TextStyle(color: AppColors.getTextSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'online.cancel'.tr(),
              style: TextStyle(color: AppColors.getTextSecondary(isDark)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.resign();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lossRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('online.resign'.tr()),
          ),
        ],
      ),
    );
  }

  void _confirmDrawOffer(BuildContext context, OnlineGameProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'online.drawOffer'.tr(),
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'online.drawOfferConfirm'.tr(),
          style: TextStyle(color: AppColors.getTextSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'online.cancel'.tr(),
              style: TextStyle(color: AppColors.getTextSecondary(isDark)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.sendDrawOffer();
              KitaToast.info('online.drawOfferSent'.tr());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('online.drawOffer'.tr()),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedReason = 'online.reportHarassment'.tr();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final reasons = [
            'online.reportHarassment'.tr(),
            'online.reportCheating'.tr(),
            'online.reportStalling'.tr(),
          ];

          return AlertDialog(
            backgroundColor: AppColors.getCard(isDark),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(
                  Icons.report_problem_rounded,
                  color: AppColors.warning,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'online.reportTitle'.tr(),
                  style: TextStyle(
                    color: AppColors.getTextPrimary(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'online.reportReason'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 12),
                ...reasons.map((reason) {
                  final isSelected = selectedReason == reason;
                  return InkWell(
                    onTap: () => setState(() => selectedReason = reason),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 18,
                            color: isSelected
                                ? AppColors.primaryGreen
                                : AppColors.getTextMuted(isDark),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? AppColors.getTextPrimary(isDark)
                                    : AppColors.getTextSecondary(isDark),
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'online.cancel'.tr(),
                  style: TextStyle(color: AppColors.getTextSecondary(isDark)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  KitaToast.success('online.reportSubmitted'.tr());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lossRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('online.submit'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }

}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color textColor;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.getTextMuted(isDark),
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.getTextMuted(isDark),
        ),
        onTap: onTap,
      ),
    );
  }
}
