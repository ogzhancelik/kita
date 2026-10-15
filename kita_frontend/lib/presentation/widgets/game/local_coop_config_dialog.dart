import 'dart:math';

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
import '../common/avatar_picker.dart';
import '../common/kita_avatar.dart';

/// Pre-game configuration dialog for "Local Pass & Play" (2P Co-op).
/// Allows players to customize Player 2 name and select Time Control.
class LocalCoopConfigDialog extends StatefulWidget {
  const LocalCoopConfigDialog({super.key});

  static const String prefTimeControlKey = 'kita_local_coop_time_control';
  static const String prefP2NameKey = 'kita_local_coop_p2_name';

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
  late final TextEditingController _p2NameController;
  int _p2AvatarIndex = 0;
  String? _p2AvatarCustom;

  static const List<int> _availablePresets = [
    TimeControlPreset.oneMin,
    TimeControlPreset.threeMin,
    TimeControlPreset.fiveMin,
    TimeControlPreset.unlimited,
  ];

  @override
  void initState() {
    super.initState();
    _p2NameController = TextEditingController();
    _loadSavedPreferences();
  }

  @override
  void dispose() {
    _p2NameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTime = prefs.getInt(LocalCoopConfigDialog.prefTimeControlKey);
      if (savedTime != null && _availablePresets.contains(savedTime)) {
        _cachedTimeControl = savedTime;
        _selectedTimeControl = savedTime;
      }
      final savedP2 = prefs.getString(LocalCoopConfigDialog.prefP2NameKey);
      if (savedP2 != null && savedP2.trim().isNotEmpty) {
        _p2NameController.text = savedP2.trim();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _persistPreferences(int timeControl, String p2Name) async {
    _cachedTimeControl = timeControl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(LocalCoopConfigDialog.prefTimeControlKey, timeControl);
      if (p2Name.trim().isNotEmpty) {
        await prefs.setString(LocalCoopConfigDialog.prefP2NameKey, p2Name.trim());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = context.watch<AuthProvider>();
    final isGuest = authProv.isGuest || authProv.currentUser == null;
    final playerName =
        authProv.currentUser?.username ??
        authProv.guestProfile?.nickname ??
        'Guest';
    final playerAvatarIndex =
        authProv.currentUser?.avatarIndex ??
        authProv.guestProfile?.avatarIndex ??
        0;
    final playerCustomEmoji =
        authProv.currentUser?.avatarCustom ??
        authProv.guestProfile?.avatarCustom;

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Players
              Text(
                'game.players'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextSecondary(isDark),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),

              // Player Configuration Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.getBorder(isDark)),
                ),
                child: Column(
                  children: [
                    // Player 1 (You)
                    Row(
                      children: [
                        KitaAvatar(
                          avatarIndex: playerAvatarIndex,
                          avatarCustom: playerCustomEmoji,
                          size: 38,
                          isGuest: isGuest,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playerName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'game.you'.tr(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.getTextSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            '1P',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Divider(height: 1, color: AppColors.getBorder(isDark).withValues(alpha: 0.5)),
                    const SizedBox(height: 10),

                    // Player 2 (Friend / Local Opponent)
                    Row(
                      children: [
                        KitaAvatar(
                          avatarIndex: _p2AvatarIndex,
                          avatarCustom: _p2AvatarCustom,
                          isGuest: _p2AvatarIndex == 0 && (_p2AvatarCustom == null || _p2AvatarCustom!.isEmpty),
                          size: 38,
                          onTap: () {
                            AvatarPicker.showPicker(
                              context,
                              initialIndex: _p2AvatarIndex,
                              initialCustom: _p2AvatarCustom,
                              onSelected: (idx, custom) {
                                setState(() {
                                  _p2AvatarIndex = idx;
                                  _p2AvatarCustom = custom;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _p2NameController,
                            maxLength: 16,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              counterText: '',
                              hintText: 'game.player2Hint'.tr(),
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: AppColors.getTextMuted(isDark),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              filled: true,
                              fillColor: AppColors.getCard(isDark),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.getBorder(isDark)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.getBorder(isDark)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.accent),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryAmber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primaryAmber.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            '2P',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Section 2: Time control
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

    final p2Name = _p2NameController.text.trim();
    _persistPreferences(_selectedTimeControl, p2Name);

    if (!mounted) return;
    Navigator.of(context).pop();

    // Random side selection for the first match; swapped upon rematch
    final random = Random();
    final p1Team = random.nextBool() ? PieceTeam.white : PieceTeam.black;

    final gameSettings = context.read<GameSettingsProvider>();
    offlineProv.startOfflineMatch(
      mode: PlayMode.localCoop,
      playerTeam: p1Team,
      playerId: playerId,
      playerName: playerName,
      playerAvatarIndex: playerAvatarIndex,
      isGuest: isGuest,
      opponentName: p2Name.isNotEmpty ? p2Name : null,
      opponentAvatarIndex: _p2AvatarIndex,
      opponentAvatarCustom: _p2AvatarCustom,
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
        _persistPreferences(preset, _p2NameController.text.trim());
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
