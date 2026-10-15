import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/game_settings_provider.dart';
import 'settings_dialog.dart';

/// Bottom sheet dialog for board aesthetics & visual customization:
/// - Board Theme (3x2 minimalist grid: emerald, amber_sunset, ocean_azure, cyber_purple, slate_monochrome, minecraft)
/// - Swap tile colors 1 and 3 (1s lighter, 3s darker)
/// - Board Tile Style (rounded vs flat)
/// - Last Move Indicator (highlight, line, off)
class BoardSettingsDialog extends StatelessWidget {
  final void Function(BuildContext context)? onBack;

  const BoardSettingsDialog({super.key, this.onBack});

  static Future<void> show(BuildContext context, {void Function(BuildContext context)? onBack}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BoardSettingsDialog(onBack: onBack),
    );
  }

  void _handleBack(BuildContext context) {
    Navigator.of(context).pop();
    if (onBack != null) {
      onBack!(context);
    } else {
      SettingsDialog.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gameSettings = context.watch<GameSettingsProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                    onPressed: () => _handleBack(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'settings.boardSettings'.tr(),
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
                    // Section 1: Board Theme (Minimalist 3x2 Grid)
                    _buildSectionHeader(
                      context: context,
                      isDark: isDark,
                      title: 'settings.boardTheme'.tr(),
                      icon: Icons.palette_outlined,
                    ),
                    const SizedBox(height: 10),
                    _buildThemeGrid(context, gameSettings, isDark),
                    const SizedBox(height: 14),

                    // Swap 1 and 3 Tile Colors Toggle
                    _buildToggleTile(
                      isDark: isDark,
                      icon: Icons.swap_vert_circle_rounded,
                      iconColor: AppColors.accentGold,
                      title: 'settings.swapTileColors'.tr(),
                      value: gameSettings.swapTileColors,
                      onChanged: (val) => gameSettings.setSwapTileColors(val),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: Tile Style (Rounded vs Flat/Adjacent)
                    _buildSectionHeader(
                      context: context,
                      isDark: isDark,
                      title: 'settings.boardTileStyle'.tr(),
                      icon: Icons.grid_view_rounded,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'settings.boardTileStyleDesc'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildTileStyleSelector(context, gameSettings, isDark),
                    const SizedBox(height: 20),

                    // Section 3: Last Move Indicator
                    _buildSectionHeader(
                      context: context,
                      isDark: isDark,
                      title: 'settings.highlightLastMove'.tr(),
                      icon: Icons.history_rounded,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'settings.highlightLastMoveDesc'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildLastMoveSelector(context, gameSettings, isDark),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        Icon(icon, size: 18, color: AppColors.primaryAmber),
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

  Widget _buildToggleTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    fontSize: 13.5,
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
                      fontSize: 11.5,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primaryAmber,
            activeTrackColor: AppColors.primaryAmber.withValues(alpha: 0.4),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeGrid(
    BuildContext context,
    GameSettingsProvider gameSettings,
    bool isDark,
  ) {
    final themes = [
      {'key': 'amber_sunset', 'nameKey': 'settings.boardThemeAmber'},
      {'key': 'ocean_azure', 'nameKey': 'settings.boardThemeOcean'},
      {'key': 'emerald', 'nameKey': 'settings.boardThemeEmerald'},
      {'key': 'cyber_purple', 'nameKey': 'settings.boardThemePurple'},
      {'key': 'slate_monochrome', 'nameKey': 'settings.boardThemeSlate'},
      {'key': 'minecraft', 'nameKey': 'settings.boardThemeMinecraft'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      itemCount: themes.length,
      itemBuilder: (context, index) {
        final t = themes[index];
        final key = t['key']!;
        final name = t['nameKey']!.tr();
        final isSelected = gameSettings.boardTheme == key;
        final previewTheme = gameSettings.previewTheme(key, isDark);

        return Tooltip(
          message: name,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => gameSettings.setBoardTheme(key),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? AppColors.primaryAmber.withValues(alpha: 0.16)
                          : AppColors.primaryAmber.withValues(alpha: 0.10))
                      : (isDark ? AppColors.darkBg : AppColors.lightBg),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryAmber
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Palette mini preview (3 tiles for 1, 2, 3 values)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildMiniTile(previewTheme.getColorForValue(1)),
                            const SizedBox(width: 3),
                            _buildMiniTile(previewTheme.getColorForValue(2)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        _buildMiniTile(
                          previewTheme.getColorForValue(3),
                          width: 31,
                        ),
                      ],
                    ),

                    // Selected check indicator badge
                    if (isSelected)
                      const Positioned(
                        top: 0,
                        right: 0,
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: AppColors.primaryAmber,
                        ),
                      ),
                  ],
                ),
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

  Widget _buildLastMoveSelector(
    BuildContext context,
    GameSettingsProvider gameSettings,
    bool isDark,
  ) {
    final options = [
      {
        'key': 'highlight',
        'title': 'settings.lastMoveHighlight'.tr(),
        'icon': Icons.square_rounded,
      },
      {
        'key': 'line',
        'title': 'settings.lastMoveLine'.tr(),
        'icon': Icons.timeline_rounded,
      },
      {
        'key': 'off',
        'title': 'settings.lastMoveOff'.tr(),
        'icon': Icons.visibility_off_rounded,
      },
    ];

    return Row(
      children: options.map((opt) {
        final key = opt['key'] as String;
        final title = opt['title'] as String;
        final icon = opt['icon'] as IconData;
        final isSelected = gameSettings.lastMoveIndicator == key;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => gameSettings.setLastMoveIndicator(key),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryAmber
                          : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: isSelected
                            ? AppColors.primaryAmber
                            : (isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary)
                              : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted),
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

  Widget _buildTileStyleSelector(
    BuildContext context,
    GameSettingsProvider gameSettings,
    bool isDark,
  ) {
    final options = [
      {
        'key': 'rounded',
        'title': 'settings.tileStyleRounded'.tr(),
        'icon': Icons.rounded_corner_rounded,
      },
      {
        'key': 'flat',
        'title': 'settings.tileStyleFlat'.tr(),
        'icon': Icons.crop_square_rounded,
      },
    ];

    return Row(
      children: options.map((opt) {
        final key = opt['key'] as String;
        final title = opt['title'] as String;
        final icon = opt['icon'] as IconData;
        final isSelected = gameSettings.boardTileStyle == key;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => gameSettings.setBoardTileStyle(key),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBg : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryAmber
                          : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: isSelected
                            ? AppColors.primaryAmber
                            : (isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary)
                              : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted),
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
