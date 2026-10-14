import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/offline_game_provider.dart';
import '../../screens/game/offline_match_screen.dart';

/// Pre-game configuration dialog for "Local Pass & Play" (2P Co-op).
/// Allows players to select Time Control (Unlimited, 1m, 3m, 5m, 10m).
class LocalCoopConfigDialog extends StatefulWidget {
  const LocalCoopConfigDialog({super.key});

  static const String prefTimeControlKey = 'kita_local_coop_time_control';

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const LocalCoopConfigDialog(),
    );
  }

  @override
  State<LocalCoopConfigDialog> createState() => _LocalCoopConfigDialogState();
}

class _LocalCoopConfigDialogState extends State<LocalCoopConfigDialog> {
  static int _cachedTimeControl = TimeControlPreset.unlimited;

  int _selectedTimeControl = _cachedTimeControl;

  static const List<int> _availablePresets = [
    TimeControlPreset.oneMin,
    TimeControlPreset.threeMin,
    TimeControlPreset.fiveMin,
    TimeControlPreset.unlimited,
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(LocalCoopConfigDialog.prefTimeControlKey);
      if (saved != null && _availablePresets.contains(saved)) {
        _cachedTimeControl = saved;
        if (mounted) {
          setState(() {
            _selectedTimeControl = saved;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _persistPreference(int timeControl) async {
    _cachedTimeControl = timeControl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(LocalCoopConfigDialog.prefTimeControlKey, timeControl);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: AppColors.getCard(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 32,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'game.localCoopTitle'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time control section header
            Text(
              'online.selectTimeControl'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextSecondary(isDark),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            // Time control options 2x2 grid
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeOption(_availablePresets[0], isDark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTimeOption(_availablePresets[1], isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeOption(_availablePresets[2], isDark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTimeOption(_availablePresets[3], isDark),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: AppColors.getBorder(isDark)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'common.cancel'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  'game.startMatch'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAmber,
                  foregroundColor: AppColors.darkTextPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _startGame() async {
    final offlineProv = context.read<OfflineGameProvider>();
    final authProv = context.read<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check for active match conflict
    if (offlineProv.hasActiveMatch) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: AppColors.getCard(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'online.conflictDialogTitle'.tr(),
            style: TextStyle(
              color: AppColors.getTextPrimary(isDark),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'online.conflictAbandonOfflineDesc'.tr(),
            style: TextStyle(color: AppColors.getTextSecondary(isDark)),
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
                backgroundColor: AppColors.primaryAmber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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

    final isGuest = authProv.isGuest || authProv.currentUser == null;
    final playerId = authProv.currentUser?.id;
    final playerName =
        authProv.currentUser?.username ??
        authProv.guestProfile?.nickname ??
        'Guest';
    final playerAvatarIndex =
        authProv.currentUser?.avatarIndex ??
        authProv.guestProfile?.avatarIndex ??
        0;

    if (!mounted) return;
    Navigator.of(context).pop();

    final gameSettings = context.read<GameSettingsProvider>();
    offlineProv.startOfflineMatch(
      mode: PlayMode.localCoop,
      playerId: playerId,
      playerName: playerName,
      playerAvatarIndex: playerAvatarIndex,
      isGuest: isGuest,
      timeControl: _selectedTimeControl,
      initialIsHorizontal: gameSettings.isLocalCoopBoardHorizontal,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OfflineMatchScreen(),
        settings: const RouteSettings(name: '/offline_match'),
      ),
    );
  }

  Widget _buildTimeOption(int preset, bool isDark) {
    final isSelected = _selectedTimeControl == preset;
    final label = preset <= 0
        ? 'online.timeUnlimited'.tr()
        : 'online.timeMinutes'.tr(args: ['${(preset / 60000).round()}']);

    final icon = preset <= 0
        ? Icons.all_inclusive_rounded
        : Icons.timer_outlined;

    return InkWell(
      onTap: () {
        setState(() => _selectedTimeControl = preset);
        _persistPreference(preset);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : AppColors.getBorder(isDark),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.accent
                  : AppColors.getTextMuted(isDark),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.getTextPrimary(isDark)
                      : AppColors.getTextSecondary(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
