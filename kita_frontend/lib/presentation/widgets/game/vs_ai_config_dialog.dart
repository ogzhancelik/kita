import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/online_game_provider.dart';

/// Pre-game configuration dialog for "Play vs Computer" (AI).
/// Allows the player to select Bot Difficulty and Player Side.
class VsAiConfigDialog extends StatefulWidget {
  const VsAiConfigDialog({super.key});

  static const String prefDifficultyKey = 'kita_ai_difficulty';
  static const String prefSideKey = 'kita_ai_side';

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const VsAiConfigDialog(),
    );
  }

  @override
  State<VsAiConfigDialog> createState() => _VsAiConfigDialogState();
}

class _VsAiConfigDialogState extends State<VsAiConfigDialog> {
  static int _cachedDifficulty = 1;
  static String _cachedSide = 'random';

  int _selectedDifficulty = _cachedDifficulty; // 0: Easy, 1: Medium, 2: Hard
  String _selectedSide = _cachedSide; // 'white', 'random', 'black'

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDiff = prefs.getInt(VsAiConfigDialog.prefDifficultyKey);
      final savedSide = prefs.getString(VsAiConfigDialog.prefSideKey);

      bool changed = false;
      if (savedDiff != null && savedDiff >= 0 && savedDiff <= 2) {
        _cachedDifficulty = savedDiff;
        _selectedDifficulty = savedDiff;
        changed = true;
      }
      if (savedSide != null &&
          (savedSide == 'white' || savedSide == 'random' || savedSide == 'black')) {
        _cachedSide = savedSide;
        _selectedSide = savedSide;
        changed = true;
      }

      if (changed && mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _persistPreferences(int diff, String side) async {
    _cachedDifficulty = diff;
    _cachedSide = side;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(VsAiConfigDialog.prefDifficultyKey, diff);
      await prefs.setString(VsAiConfigDialog.prefSideKey, side);
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
              color: AppColors.primaryGreen.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 32,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'dashboard.playAI'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'game.offlineAIDesc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextMuted(isDark),
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
            // --- Section 1: Difficulty ---
            Text(
              'game.difficulty'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextSecondary(isDark),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDifficultyOption(
                    title: 'game.easy'.tr(),
                    rating: '1000',
                    value: 0,
                    icon: Icons.sentiment_satisfied_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDifficultyOption(
                    title: 'game.medium'.tr(),
                    rating: '1200',
                    value: 1,
                    icon: Icons.military_tech_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDifficultyOption(
                    title: 'game.hard'.tr(),
                    rating: '1400',
                    value: 2,
                    icon: Icons.workspace_premium_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // --- Section 2: Side Selection ---
            Text(
              'game.side'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextSecondary(isDark),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSideOption(
                    title: 'game.playWhite'.tr(),
                    sideKey: 'white',
                    icon: Icons.circle,
                    iconColor: AppColors.boardLightSquare,
                    iconBorder: true,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSideOption(
                    title: 'game.playRandom'.tr(),
                    sideKey: 'random',
                    icon: Icons.shuffle_rounded,
                    iconColor: AppColors.ratingGold,
                    iconBorder: false,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSideOption(
                    title: 'game.playBlack'.tr(),
                    sideKey: 'black',
                    icon: Icons.circle,
                    iconColor: AppColors.darkSurfaceElevated,
                    iconBorder: true,
                    isDark: isDark,
                  ),
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
                  backgroundColor: AppColors.primaryGreen,
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

  Widget _buildDifficultyOption({
    required String title,
    required String rating,
    required int value,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedDifficulty == value;
    final activeColor = AppColors.primaryGreen;

    return InkWell(
      onTap: () {
        setState(() => _selectedDifficulty = value);
        _persistPreferences(value, _selectedSide);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : AppColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.getBorder(isDark),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? activeColor : AppColors.getTextMuted(isDark),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AppColors.getTextPrimary(isDark)
                    : AppColors.getTextSecondary(isDark),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.2)
                    : AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rating,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? activeColor : AppColors.getTextMuted(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideOption({
    required String title,
    required String sideKey,
    required IconData icon,
    required Color iconColor,
    required bool iconBorder,
    required bool isDark,
  }) {
    final isSelected = _selectedSide == sideKey;
    final activeColor = AppColors.primaryGreen;

    return InkWell(
      onTap: () {
        setState(() => _selectedSide = sideKey);
        _persistPreferences(_selectedDifficulty, sideKey);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : AppColors.getSurface(isDark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.getBorder(isDark),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Container(
              decoration: iconBorder
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1.2,
                      ),
                    )
                  : null,
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AppColors.getTextPrimary(isDark)
                    : AppColors.getTextSecondary(isDark),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _startGame() {
    _persistPreferences(_selectedDifficulty, _selectedSide);
    final prov = context.read<OnlineGameProvider>();
    final authProv = context.read<AuthProvider>();

    final isGuest = authProv.isGuest || authProv.currentUser == null;
    final playerId = authProv.currentUser?.id;
    final playerName = authProv.currentUser?.username ??
        authProv.guestProfile?.nickname ??
        'Guest';
    final playerRating = authProv.currentUser?.rating ?? 1200;

    PieceTeam team;
    if (_selectedSide == 'random') {
      team = Random().nextBool() ? PieceTeam.white : PieceTeam.black;
    } else if (_selectedSide == 'black') {
      team = PieceTeam.black;
    } else {
      team = PieceTeam.white;
    }

    Navigator.of(context).pop();

    prov.startOfflineMatch(
      mode: PlayMode.vsAi,
      playerTeam: team,
      botDifficulty: _selectedDifficulty,
      playerId: playerId,
      playerName: playerName,
      playerRating: playerRating,
      isGuest: isGuest,
    );
  }
}
