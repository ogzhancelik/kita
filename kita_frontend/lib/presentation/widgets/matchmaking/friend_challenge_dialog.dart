import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/friend_models.dart';
import '../../../data/models/ws_message_models.dart';
import '../../providers/online_game_provider.dart';

class FriendChallengeDialog extends StatefulWidget {
  final FriendItemModel friend;
  final OnlineGameProvider onlineProv;

  const FriendChallengeDialog({
    super.key,
    required this.friend,
    required this.onlineProv,
  });

  static Future<void> show({
    required BuildContext context,
    required FriendItemModel friend,
    required OnlineGameProvider onlineProv,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => FriendChallengeDialog(
        friend: friend,
        onlineProv: onlineProv,
      ),
    );
  }

  @override
  State<FriendChallengeDialog> createState() => _FriendChallengeDialogState();
}

class _FriendChallengeDialogState extends State<FriendChallengeDialog> {
  String _selectedColor = 'random';
  int _selectedTimeControl = TimeControlPreset.threeMin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: AppColors.getCard(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryGreen.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              size: 32,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'online.sendInvite'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Opponent info badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.getSurface(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.getBorder(isDark)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.2),
                  child: Text(
                    widget.friend.username.isNotEmpty
                        ? widget.friend.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.friend.username,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.ratingGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '★ ${widget.friend.rating}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.ratingGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Choose Side
          Text(
            'online.chooseSide'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildChoiceChip(
                label: 'online.colorRandom'.tr(),
                icon: Icons.shuffle_rounded,
                isSelected: _selectedColor == 'random',
                isDark: isDark,
                onSelected: () => setState(() => _selectedColor = 'random'),
              ),
              _buildChoiceChip(
                label: 'online.colorWhite'.tr(),
                icon: Icons.circle,
                iconColor: AppColors.darkTextPrimary,
                isSelected: _selectedColor == 'white',
                isDark: isDark,
                onSelected: () => setState(() => _selectedColor = 'white'),
              ),
              _buildChoiceChip(
                label: 'online.colorBlack'.tr(),
                icon: Icons.circle_outlined,
                isSelected: _selectedColor == 'black',
                isDark: isDark,
                onSelected: () => setState(() => _selectedColor = 'black'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Time Control
          Text(
            'online.selectTimeControl'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildTimeChip('online.timeBullet'.tr(), TimeControlPreset.oneMin, isDark),
              _buildTimeChip('online.timeBlitz'.tr(), TimeControlPreset.threeMin, isDark),
              _buildTimeChip('online.timeRapid'.tr(), TimeControlPreset.fiveMin, isDark),
              _buildTimeChip('online.timeUnlimited'.tr(), TimeControlPreset.unlimited, isDark),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'online.cancel'.tr(),
            style: TextStyle(color: AppColors.getTextSecondary(isDark)),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onlineProv.inviteToMatch(
              widget.friend.userId,
              friendName: widget.friend.username,
              friendRating: widget.friend.rating,
              timeControl: _selectedTimeControl,
              colorPreference: _selectedColor,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('online.inviteSent'.tr()),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.darkTextPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text('online.sendInvite'.tr()),
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required IconData icon,
    Color? iconColor,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected
            ? AppColors.darkTextPrimary
            : (iconColor ?? AppColors.getTextPrimary(isDark)),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.darkTextPrimary : AppColors.getTextPrimary(isDark),
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen,
      backgroundColor: AppColors.getSurface(isDark),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildTimeChip(String label, int value, bool isDark) {
    final isSelected = _selectedTimeControl == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.darkTextPrimary : AppColors.getTextPrimary(isDark),
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen,
      backgroundColor: AppColors.getSurface(isDark),
      onSelected: (_) => setState(() => _selectedTimeControl = value),
    );
  }
}
