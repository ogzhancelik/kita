import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/game_settings_provider.dart';
import 'settings_dialog.dart';

/// Bottom sheet dialog for match runtime preferences:
/// - Board Orientation (Horizontal vs Vertical segmented toggle)
/// - Piece Rotation / Angle (Fixed 0° vs Auto segmented toggle)
/// - Flip Viewpoint (Auto, White, Black uniform height buttons)
/// - 2P Local Co-op (Auto Rotate Pieces on turn switch)
class MatchSettingsDialog extends StatelessWidget {
  final void Function(BuildContext context)? onBack;

  const MatchSettingsDialog({super.key, this.onBack});

  static Future<void> show(BuildContext context, {void Function(BuildContext context)? onBack}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MatchSettingsDialog(onBack: onBack),
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
                    // Section 1: Board and Piece Orientation
                    _buildSectionHeader(
                      context: context,
                      isDark: isDark,
                      title: 'settings.boardAndPieceOrientation'.tr(),
                      icon: Icons.screen_rotation_rounded,
                    ),
                    const SizedBox(height: 12),

                    // Board Orientation Toggle (Horizontal on Left, Vertical on Right)
                    Text(
                      'settings.boardOrientation'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildSegmentedToggle(
                      isDark: isDark,
                      leftLabel: 'common.orientationHorizontalShort'.tr(),
                      leftIcon: Icons.stay_current_landscape_rounded,
                      isLeftSelected:
                          gameSettings.defaultBoardOrientation == 'horizontal',
                      onSelectLeft: () =>
                          gameSettings.setBoardOrientation('horizontal'),
                      rightLabel: 'common.orientationVerticalShort'.tr(),
                      rightIcon: Icons.stay_current_portrait_rounded,
                      isRightSelected:
                          gameSettings.defaultBoardOrientation == 'vertical',
                      onSelectRight: () =>
                          gameSettings.setBoardOrientation('vertical'),
                    ),
                    const SizedBox(height: 16),

                    // Piece Rotation / Angle Toggle (Fixed 0° on Left, Auto on Right)
                    Text(
                      'settings.pieceAngleLabel'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildSegmentedToggle(
                      isDark: isDark,
                      leftLabel: 'settings.angleFixed0'.tr(),
                      leftIcon: Icons.lock_outline_rounded,
                      isLeftSelected:
                          gameSettings.pieceAngleMode == 'fixed',
                      onSelectLeft: () =>
                          gameSettings.setPieceAngleMode('fixed'),
                      rightLabel: 'settings.angleAuto'.tr(),
                      rightIcon: Icons.rotate_right_rounded,
                      isRightSelected:
                          gameSettings.pieceAngleMode == 'auto',
                      onSelectRight: () =>
                          gameSettings.setPieceAngleMode('auto'),
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Flip Direction / Viewpoint
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
                    const SizedBox(height: 24),

                    // Section 3: 2P Local Co-op
                    _buildSectionHeader(
                      context: context,
                      isDark: isDark,
                      title: 'settings.localCoopSection'.tr(),
                      icon: Icons.people_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildToggleTile(
                      isDark: isDark,
                      icon: Icons.screen_rotation_alt_rounded,
                      iconColor: AppColors.primaryAmber,
                      title: 'settings.localCoopAutoRotate'.tr(),
                      subtitle: 'settings.localCoopAutoRotateDesc'.tr(),
                      value: gameSettings.localCoopAutoRotate,
                      onChanged: (val) =>
                          gameSettings.setLocalCoopAutoRotate(val),
                    ),
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

  Widget _buildSegmentedToggle({
    required bool isDark,
    required String leftLabel,
    required IconData leftIcon,
    required bool isLeftSelected,
    required VoidCallback onSelectLeft,
    required String rightLabel,
    required IconData rightIcon,
    required bool isRightSelected,
    required VoidCallback onSelectRight,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
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
          Expanded(
            child: _buildSegmentOption(
              isDark: isDark,
              label: leftLabel,
              icon: leftIcon,
              isSelected: isLeftSelected,
              onTap: onSelectLeft,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSegmentOption(
              isDark: isDark,
              label: rightLabel,
              icon: rightIcon,
              isSelected: isRightSelected,
              onTap: onSelectRight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentOption({
    required bool isDark,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryAmber
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryAmber.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 6,
                    ),
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
                      mainAxisAlignment: MainAxisAlignment.center,
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
                            fontSize: 11,
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
      ),
    );
  }
}
