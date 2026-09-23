import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../common/avatar_picker.dart';
import '../common/kita_card.dart';
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
                    // --- Theme Setting ---
                    _buildSettingsTile(
                      isDark: isDark,
                      icon: themeProv.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      iconColor: AppColors.ratingGold,
                      title: 'settings.theme'.tr(),
                      subtitle: themeProv.isDarkMode ? 'settings.themeDark'.tr() : 'settings.themeLight'.tr(),
                      trailing: Switch(
                        value: themeProv.isDarkMode,
                        activeThumbImage: null,
                        activeThumbColor: AppColors.ratingGold,
                        onChanged: (_) => themeProv.toggleTheme(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Language Setting ---
                    _buildSettingsTile(
                      isDark: isDark,
                      icon: Icons.language_rounded,
                      iconColor: AppColors.primaryGreen,
                      title: 'settings.language'.tr(),
                      subtitle: currentLocale == 'tr' ? 'settings.languageTr'.tr() : 'settings.languageEn'.tr(),
                      trailing: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                        ),
                        onPressed: () {
                          final newLocale = currentLocale == 'en' ? const Locale('tr') : const Locale('en');
                          context.setLocale(newLocale);
                        },
                        child: Text(
                          currentLocale == 'en' ? 'TR' : 'EN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Match Settings (Board theme, orientation & flip) ---
                    _buildSettingsTile(
                      isDark: isDark,
                      icon: Icons.sports_esports_rounded,
                      iconColor: AppColors.primaryGreen,
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

                    // --- Avatar / Profile Quick Action ---
                    _buildSettingsTile(
                      isDark: isDark,
                      icon: Icons.face_rounded,
                      iconColor: AppColors.accentGold,
                      title: 'profile.title'.tr(),
                      subtitle: authProv.displayName,
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          AvatarPicker.show(context);
                        },
                        child: Text(
                          'profile.changeAvatar'.tr(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- About / Version ---
                    _buildSettingsTile(
                      isDark: isDark,
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.winBlue,
                      title: 'settings.about'.tr(),
                      subtitle: 'settings.version'.tr(),
                    ),
                    const SizedBox(height: 16),

                    // --- Logout Action ---
                    if (authProv.isAuthenticated || authProv.isGuest)
                      KitaCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
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
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
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

  void _showLogoutConfirmation(BuildContext context, AuthProvider authProv, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text(
          'settings.logoutConfirmTitle'.tr(),
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
              'settings.cancel'.tr(),
              style: TextStyle(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lossRed,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              authProv.logout();
            },
            child: Text(
              'settings.confirm'.tr(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
