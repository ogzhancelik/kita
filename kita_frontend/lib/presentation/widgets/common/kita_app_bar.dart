import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class KitaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showAuthActions;
  final bool showBack;
  final VoidCallback? onBack;

  const KitaAppBar({
    super.key,
    this.title,
    this.showAuthActions = true,
    this.showBack = false,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProv = context.watch<ThemeProvider>();
    final authProv = context.watch<AuthProvider>();
    final currentLocale = context.locale.languageCode;

    return AppBar(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: showBack ? 0 : NavigationToolbar.kMiddleSpacing,
      leading: showBack
          ? IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                size: 20,
              ),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.primaryGreenDark,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.grid_4x4_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title ?? 'appTitle'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Language Toggle (TR / EN)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              final newLocale = currentLocale == 'en' ? const Locale('tr') : const Locale('en');
              context.setLocale(newLocale);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 15, color: AppColors.primaryGreen),
                  const SizedBox(width: 3),
                  Text(
                    currentLocale.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Theme Toggle (Dark / Light)
        IconButton(
          tooltip: 'settings.theme'.tr(),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            themeProv.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: isDark ? AppColors.ratingGold : AppColors.darkSurfaceElevated,
            size: 20,
          ),
          onPressed: () => themeProv.toggleTheme(),
        ),

        // Logout action if authenticated/guest and requested
        if (showAuthActions && (authProv.isAuthenticated || authProv.isGuest))
          IconButton(
            tooltip: 'auth.logout'.tr(),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.logout_rounded,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              size: 20,
            ),
            onPressed: () => authProv.logout(),
          ),

        const SizedBox(width: 4),
      ],
    );
  }
}
