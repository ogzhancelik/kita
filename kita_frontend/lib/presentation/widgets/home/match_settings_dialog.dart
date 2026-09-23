import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/game_settings_provider.dart';
import '../game/kita_board_theme.dart';
import 'settings_dialog.dart';

/// Bottom sheet dialog for in-game presentation & match preferences:
/// - Board Theme (emerald, amber_sunset, ocean_azure, cyber_purple, slate_monochrome, minecraft)
/// - Board Orientation (horizontal, vertical)
/// - Flip Direction (auto, white, black)
class MatchSettingsDialog extends StatelessWidget {
  const MatchSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MatchSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gameSettings = context.watch<GameSettingsProvider>();

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

            // Header with Back button, Title & Close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
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
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'settings.matchSettings'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
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
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Settings Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Board Theme
                    _buildSectionHeader(
                      context: context,
                      isDark: isDark,
                      title: 'settings.boardTheme'.tr(),
                      icon: Icons.palette_outlined,
                    ),
                    const SizedBox(height: 10),
                    _buildThemeGrid(context, gameSettings, isDark),
                    const SizedBox(height: 20),

                    // Section 2: Board Orientation
                    _buildSectionHeader(
                      context: context,
                      isDark: isDark,
                      title: 'settings.boardOrientation'.tr(),
                      icon: Icons.screen_rotation_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildOrientationSelector(context, gameSettings, isDark),
                    const SizedBox(height: 20),

                    // Section 3: Flip Direction
                    _buildSectionHeader(
                      context: context,
                      isDark: isDark,
                      title: 'settings.flipDirection'.tr(),
                      icon: Icons.swap_vertical_circle_outlined,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'settings.flipDirectionDesc'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFlipSelector(context, gameSettings, isDark),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required bool isDark,
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.primaryGreen,
        ),
        const SizedBox(width: 8),
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
      ],
    );
  }

  Widget _buildThemeGrid(
    BuildContext context,
    GameSettingsProvider gameSettings,
    bool isDark,
  ) {
    final themes = [
      {'key': 'emerald', 'nameKey': 'settings.boardThemeEmerald'},
      {'key': 'amber_sunset', 'nameKey': 'settings.boardThemeAmber'},
      {'key': 'ocean_azure', 'nameKey': 'settings.boardThemeOcean'},
      {'key': 'cyber_purple', 'nameKey': 'settings.boardThemePurple'},
      {'key': 'slate_monochrome', 'nameKey': 'settings.boardThemeSlate'},
      {'key': 'minecraft', 'nameKey': 'settings.boardThemeMinecraft'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: themes.length,
      itemBuilder: (context, index) {
        final t = themes[index];
        final key = t['key']!;
        final name = t['nameKey']!.tr();
        final isSelected = gameSettings.boardTheme == key;
        final previewTheme = _getPreviewTheme(key, isDark);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => gameSettings.setBoardTheme(key),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : AppColors.lightBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Palette mini preview (3 tiles for 1, 2, 3 values)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          _buildMiniTile(previewTheme.getColorForValue(1)),
                          const SizedBox(width: 3),
                          _buildMiniTile(previewTheme.getColorForValue(2)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      _buildMiniTile(previewTheme.getColorForValue(3), width: 31),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniTile(Color color, {double width = 14}) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
    );
  }

  KitaBoardTheme _getPreviewTheme(String key, bool isDark) {
    switch (key) {
      case 'amber_sunset':
      case 'amberSunset':
        return KitaBoardTheme.amberSunset();
      case 'ocean_azure':
      case 'oceanAzure':
        return KitaBoardTheme.oceanAzure();
      case 'cyber_purple':
      case 'cyberPurple':
        return KitaBoardTheme.cyberPurple();
      case 'slate_monochrome':
      case 'slateMonochrome':
        return KitaBoardTheme.slateMonochrome();
      case 'minecraft':
        return KitaBoardTheme.minecraft();
      case 'emerald':
      default:
        return KitaBoardTheme.emerald(isDark);
    }
  }

  Widget _buildOrientationSelector(
    BuildContext context,
    GameSettingsProvider gameSettings,
    bool isDark,
  ) {
    final options = [
      {
        'key': 'horizontal',
        'title': 'settings.orientationHorizontal'.tr(),
        'icon': Icons.stay_current_landscape_rounded,
      },
      {
        'key': 'vertical',
        'title': 'settings.orientationVertical'.tr(),
        'icon': Icons.stay_current_portrait_rounded,
      },
    ];

    return Row(
      children: options.map((opt) {
        final key = opt['key'] as String;
        final title = opt['title'] as String;
        final icon = opt['icon'] as IconData;
        final isSelected = gameSettings.boardOrientation == key;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => gameSettings.setBoardOrientation(key),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: isSelected
                            ? AppColors.primaryGreen
                            : (isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFlipSelector(
    BuildContext context,
    GameSettingsProvider gameSettings,
    bool isDark,
  ) {
    final options = [
      {
        'key': 'auto',
        'title': 'settings.flipAuto'.tr(),
        'icon': Icons.auto_mode_rounded,
      },
      {
        'key': 'white',
        'title': 'settings.flipWhite'.tr(),
        'icon': Icons.arrow_downward_rounded,
      },
      {
        'key': 'black',
        'title': 'settings.flipBlack'.tr(),
        'icon': Icons.arrow_upward_rounded,
      },
    ];

    return Row(
      children: options.map((opt) {
        final key = opt['key'] as String;
        final title = opt['title'] as String;
        final icon = opt['icon'] as IconData;
        final isSelected = gameSettings.flipDirection == key;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => gameSettings.setFlipDirection(key),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: isSelected
                            ? AppColors.primaryGreen
                            : (isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
