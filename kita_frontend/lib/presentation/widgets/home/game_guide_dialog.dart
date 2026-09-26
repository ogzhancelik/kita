import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../common/kita_button.dart';
import '../common/kita_card.dart';
import 'settings_dialog.dart';

class GameGuideDialog extends StatelessWidget {
  final bool fromSettings;

  const GameGuideDialog({
    super.key,
    this.fromSettings = false,
  });

  static Future<void> show(BuildContext context, {bool fromSettings = false}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameGuideDialog(fromSettings: fromSettings),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
        maxWidth: 540,
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

            // Header with optional Back, Title & Close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  if (fromSettings)
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      tooltip: 'common.back'.tr(),
                      onPressed: () {
                        Navigator.of(context).pop();
                        SettingsDialog.show(context);
                      },
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(left: 6, right: 6),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.accentGold,
                        size: 22,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      'game.howToPlay'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    tooltip: 'common.close'.tr(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),

            // Rules Content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                children: [
                  // Quick Summary Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: AppColors.accentGold,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'game.rulesSummary'.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1. Movement & Distance Rule (Key differentiator)
                  _buildRuleCard(
                    isDark: isDark,
                    icon: Icons.directions_run_rounded,
                    iconColor: AppColors.primaryGreen,
                    title: 'game.rulesMovementTitle'.tr(),
                    description: 'game.rulesMovementDesc'.tr(),
                  ),
                  const SizedBox(height: 10),

                  // 2. Goal & Win Condition
                  _buildRuleCard(
                    isDark: isDark,
                    icon: Icons.emoji_events_rounded,
                    iconColor: AppColors.accentGold,
                    title: 'game.rulesGoalTitle'.tr(),
                    description: '${'game.rulesGoalDesc'.tr()}\n${'game.rulesWinDesc'.tr()}',
                  ),
                  const SizedBox(height: 10),

                  // 3. Pieces & Invincible Pawns
                  _buildRuleCard(
                    isDark: isDark,
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.winBlue,
                    title: 'game.rulesPiecesTitle'.tr(),
                    description: '${'game.rulesPiecesDesc'.tr()}\n${'game.rulesCaptureDesc'.tr()}',
                  ),
                  const SizedBox(height: 10),

                  // 4. Board Layout
                  _buildRuleCard(
                    isDark: isDark,
                    icon: Icons.grid_view_rounded,
                    iconColor: AppColors.accentSecondary,
                    title: 'game.rulesBoardTitle'.tr(),
                    description: 'game.rulesBoardDesc'.tr(),
                  ),
                  const SizedBox(height: 10),

                  // 5. Last Stand (Retaliation)
                  _buildRuleCard(
                    isDark: isDark,
                    icon: Icons.local_fire_department_rounded,
                    iconColor: AppColors.lossRed,
                    title: 'game.rulesLastStandTitle'.tr(),
                    description: 'game.rulesLastStandDesc'.tr(),
                  ),
                  const SizedBox(height: 10),

                  // 6. Reversal Prohibition
                  _buildRuleCard(
                    isDark: isDark,
                    icon: Icons.undo_rounded,
                    iconColor: AppColors.warning,
                    title: 'game.rulesReversalTitle'.tr(),
                    description: 'game.rulesReversalDesc'.tr(),
                  ),
                  const SizedBox(height: 10),

                  // 7. Draws
                  _buildRuleCard(
                    isDark: isDark,
                    icon: Icons.balance_rounded,
                    iconColor: AppColors.silverMedal,
                    title: 'game.rulesDrawTitle'.tr(),
                    description: 'game.rulesDrawDesc'.tr(),
                  ),
                  const SizedBox(height: 20),

                  // Bottom Action Button
                  KitaButton(
                    text: 'game.gotIt'.tr(),
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return KitaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
