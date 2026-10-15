import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../common/kita_card.dart';
import '../dialogs/report_dialog.dart';
import '../../screens/tutorial/tutorial_screen.dart';
import 'account_settings_dialog.dart';
import 'board_settings_dialog.dart';
import 'match_settings_dialog.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProv = context.watch<ThemeProvider>();
    final authProv = context.watch<AuthProvider>();
    final gameSettings = context.watch<GameSettingsProvider>();
    final currentLocale = context.locale.languageCode;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'settings.title'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
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
                    // --- Quick Controls Row (Theme, Sound, Vibration) ---
                    _buildQuickControlsRow(
                      context: context,
                      isDark: isDark,
                      themeProv: themeProv,
                      gameSettings: gameSettings,
                    ),
                    const SizedBox(height: 10),

                    // --- Language Setting ---
                    _buildSettingsTile(
                      isDark: isDark,
                      icon: Icons.language_rounded,
                      iconColor: AppColors.primaryAmber,
                      title: 'settings.language'.tr(),
                      subtitle: currentLocale == 'tr'
                          ? 'settings.languageTr'.tr()
                          : 'settings.languageEn'.tr(),
                      trailing: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: isDark
                              ? AppColors.darkBg
                              : AppColors.lightBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                        ),
                        onPressed: () {
                          final newLocale = currentLocale == 'en'
                              ? const Locale('tr')
                              : const Locale('en');
                          context.setLocale(newLocale);
                        },
                        child: Text(
                          currentLocale == 'en' ? 'TR' : 'EN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Board Settings (Theme, tile colors & last move indicator) ---
                    _buildSettingsTile(
                      isDark: isDark,
                      icon: Icons.palette_outlined,
                      iconColor: AppColors.primaryAmber,
                      title: 'settings.boardSettings'.tr(),
                      subtitle: 'settings.boardSettingsDesc'.tr(),
                      onTap: () {
                        Navigator.of(context).pop();
                        BoardSettingsDialog.show(context);
                      },
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Match Settings (Orientation, piece angle & flip viewpoint) ---
                    _buildSettingsTile(
                      isDark: isDark,
                      icon: Icons.sports_esports_rounded,
                      iconColor: AppColors.accentSecondary,
                      title: 'settings.matchSettings'.tr(),
                      subtitle: 'settings.matchSettingsDesc'.tr(),
                      onTap: () {
                        Navigator.of(context).pop();
                        MatchSettingsDialog.show(context);
                      },
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Dedicated Account Settings Action (Right Above How to Play) ---
                    _buildSettingsTile(
                      isDark: isDark,
                      icon: Icons.manage_accounts_rounded,
                      iconColor: AppColors.accentGold,
                      title: 'account.title'.tr(),
                      subtitle: authProv.displayName,
                      onTap: () {
                        Navigator.of(context).pop();
                        AccountSettingsDialog.show(context);
                      },
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Game Guide / How to Play ---
                    _buildSettingsTile(
                      isDark: isDark,
                      icon: Icons.menu_book_rounded,
                      iconColor: AppColors.accentGold,
                      title: 'settings.rulesGuide'.tr(),
                      onTap: () {
                        Navigator.of(context).pop();
                        TutorialScreen.launch(context);
                      },
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Moderation & Support / Report ---
                    _buildSettingsTile(
                      isDark: isDark,
                      icon: Icons.flag_outlined,
                      iconColor: AppColors.lossRed,
                      title: 'moderation.reportTitle'.tr(),
                      subtitle: 'moderation.reportSubtitle'.tr(),
                      onTap: () {
                        Navigator.of(context).pop();
                        ReportDialog.show(context);
                      },
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),

                    // --- Logout Action ---
                    if (authProv.isAuthenticated || authProv.isGuest) ...[
                      const SizedBox(height: 16),
                      KitaCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            _showLogoutConfirmation(context, authProv, isDark);
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.logout_rounded,
                                color: AppColors.lossRed,
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'auth.logout'.tr(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.lossRed,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.lossRed,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickControlsRow({
    required BuildContext context,
    required bool isDark,
    required ThemeProvider themeProv,
    required GameSettingsProvider gameSettings,
  }) {
    return Row(
      children: [
        // 1. Theme Setting
        Expanded(
          child: _buildQuickActionTile(
            isDark: isDark,
            icon: themeProv.isDarkMode
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            activeColor: AppColors.ratingGold,
            title: 'settings.quickTheme'.tr(),
            isActive: true,
            tooltip: 'settings.quickTheme'.tr(),
            onTap: () => themeProv.toggleTheme(),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Sound Effects Setting
        Expanded(
          child: _buildQuickActionTile(
            isDark: isDark,
            icon: gameSettings.soundEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            activeColor: AppColors.accentGold,
            title: 'settings.sound'.tr(),
            isActive: gameSettings.soundEnabled,
            tooltip: 'settings.sound'.tr(),
            onTap: () =>
                gameSettings.setSoundEnabled(!gameSettings.soundEnabled),
          ),
        ),
        const SizedBox(width: 8),

        // 3. Vibration / Haptics Setting
        Expanded(
          child: _buildQuickActionTile(
            isDark: isDark,
            icon: gameSettings.hapticsEnabled
                ? Icons.vibration_rounded
                : Icons.smartphone_rounded,
            activeColor: AppColors.accentSecondary,
            title: 'settings.vibration'.tr(),
            isActive: gameSettings.hapticsEnabled,
            tooltip: 'settings.vibration'.tr(),
            onTap: () =>
                gameSettings.setHapticsEnabled(!gameSettings.hapticsEnabled),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionTile({
    required bool isDark,
    required IconData icon,
    required Color activeColor,
    required String title,
    required bool isActive,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark
                        ? activeColor.withValues(alpha: 0.12)
                        : activeColor.withValues(alpha: 0.08))
                  : (isDark ? AppColors.darkBg : AppColors.lightBg),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? activeColor.withValues(alpha: 0.45)
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? activeColor.withValues(alpha: 0.20)
                        : (isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.lightSurfaceElevated),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isActive
                        ? activeColor
                        : (isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final tileContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : AppColors.lightBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: tileContent,
        ),
      );
    }
    return tileContent;
  }

  void _showLogoutConfirmation(
    BuildContext context,
    AuthProvider authProv,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        title: Text(
          'settings.logoutConfirmTitle'.tr(),
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'settings.logoutConfirmDesc'.tr(),
          style: TextStyle(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'common.cancel'.tr(),
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.lossRed),
            onPressed: () {
              Navigator.of(ctx).pop();
              authProv.logout();
            },
            child: Text(
              'common.confirm'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
